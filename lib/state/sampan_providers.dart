import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/data/services/ble_mesh_service.dart';
import 'package:sampan/data/services/native_bridge.dart';
import 'package:sampan/data/services/softap_hub_service.dart';
import 'package:sampan/state/sampan_app_state.dart';

export 'package:sampan/state/sampan_app_state.dart';

/// Core controller coordinating BLE Mesh, Sensor Fusion, Local Database,
/// SoftAP Embedded Server, and GitHub Release Auto-Updater.
class SampanController extends StateNotifier<SampanAppState> {
  SampanController({
    required LocalDatabase database,
    required IdentityCryptoService cryptoService,
    required BleMeshService bleMeshService,
    required SoftApHubService softApHubService,
    NativeBridge nativeBridge = const NativeBridge(),
    AppUpdateService? appUpdateService,
  })  : _database = database,
        _cryptoService = cryptoService,
        _bleMeshService = bleMeshService,
        _softApHubService = softApHubService,
        _nativeBridge = nativeBridge,
        _appUpdateService =
            appUpdateService ?? AppUpdateService(nativeBridge: nativeBridge),
        super(SampanAppState.initial()) {
    _init();
  }

  final LocalDatabase _database;
  final IdentityCryptoService _cryptoService;
  final BleMeshService _bleMeshService;
  final SoftApHubService _softApHubService;
  final NativeBridge _nativeBridge;
  final AppUpdateService _appUpdateService;

  static const String kFallbackLocalPublicKeyHex =
      '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';

  StreamSubscription<List<PeerModel>>? _peersSub;
  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<List<SpotModel>>? _spotsSub;
  StreamSubscription<void>? _hubStatsSub;
  Timer? _hardwareSyncTimer;
  String? _lastTriggeredSosId;
  bool _wasAlignedWithTarget = false;

  Future<void> _init() async {
    await _database.initialize();
    await _database.removeLegacyDemoData();

    if (!mounted) return;
    final List<PeerModel> initialPeers = _database.currentPeers;
    final IdentityProfile? savedIdentity = _database.identity;
    state = state.copyWith(
      isInitialized: true,
      identity: savedIdentity,
      peers: initialPeers,
      messages: _database.currentMessages,
      spots: _database.currentSpots,
      hotspotSsid: _database.hotspotSsid,
      hotspotPassword: _database.hotspotPassword,
      selectedTargetPeerId: state.selectedTargetPeerId ??
          (initialPeers.isNotEmpty ? initialPeers.first.id : null),
    );

    if (savedIdentity != null) {
      await _nativeBridge.requestRuntimePermissions();
      await _broadcastOwnTelemetryIfLocated(savedIdentity);
    }

    _spotsSub = _database.watchSpots().listen((List<SpotModel> spots) {
      if (!mounted) return;
      final bool targetStillExists = state.selectedTargetSpotId == null ||
          spots.any((SpotModel s) => s.id == state.selectedTargetSpotId);
      state = state.copyWith(
        spots: spots,
        clearSelectedTargetSpot: !targetStillExists,
      );
    });

    _peersSub = _database.watchPeers().listen((List<PeerModel> updatedPeers) {
      if (!mounted) return;
      state = state.copyWith(
        peers: updatedPeers,
        selectedTargetPeerId: state.selectedTargetPeerId ??
            (updatedPeers.isNotEmpty ? updatedPeers.first.id : null),
      );
    });

    _messagesSub =
        _database.watchMessages().listen((List<MessageModel> updatedMessages) {
      if (!mounted) return;
      MessageModel? latestSos = state.activeSosAlert;
      for (int i = updatedMessages.length - 1; i >= 0; i--) {
        if (updatedMessages[i].isSos) {
          if (updatedMessages[i].id != _lastTriggeredSosId) {
            _lastTriggeredSosId = updatedMessages[i].id;
            latestSos = updatedMessages[i];
          }
          break;
        }
      }
      state = state.copyWith(
        messages: updatedMessages,
        activeSosAlert: latestSos,
      );
    });

    _hubStatsSub = _softApHubService.onStatsChanged.listen((_) {
      refreshSoftApStats();
    });

    final List<String> localIps = await _nativeBridge.getLocalIpv4Addresses();
    final String installedVer = await _nativeBridge.getInstalledAppVersion();
    if (!mounted) return;
    state = state.copyWith(
      softApIps: localIps,
      installedVersion: installedVer,
    );

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _hardwareSyncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => refreshHardwareSensors(),
      );
      unawaited(checkForAppUpdate(silent: true));
    }
  }

  /// Creates the user's zero-cloud Ed25519 identity in `< 10s` (Section 5.1).
  Future<IdentityProfile> createOfflineIdentity({
    required String displayName,
    required String avatarIcon,
    required int colorHex,
    required String role,
  }) async {
    final GeneratedKeyIdentity keys = await _cryptoService.generateIdentity();
    final IdentityProfile profile = IdentityProfile(
      publicKeyHex: keys.publicKeyHex,
      privateSeedHex: keys.privateSeedHex,
      displayName: displayName.trim().isEmpty ? 'Traveler' : displayName.trim(),
      avatarIcon: avatarIcon,
      colorHex: colorHex,
      role: role,
      createdAt: DateTime.now(),
    );

    await _database.saveIdentity(profile);
    await _nativeBridge.requestRuntimePermissions();
    await _broadcastOwnTelemetryIfLocated(profile);

    if (mounted) {
      state = state.copyWith(identity: profile);
    }
    return profile;
  }

  /// Updates the user's name, look, and role while keeping the same
  /// cryptographic identity (so friends still recognise this phone).
  Future<IdentityProfile?> updateProfile({
    required String displayName,
    required String avatarIcon,
    required int colorHex,
    required String role,
  }) async {
    final IdentityProfile? current = state.identity;
    if (current == null) return null;
    final String trimmed = displayName.trim();
    final IdentityProfile updated = IdentityProfile(
      publicKeyHex: current.publicKeyHex,
      privateSeedHex: current.privateSeedHex,
      displayName: trimmed.isEmpty ? current.displayName : trimmed,
      avatarIcon: avatarIcon,
      colorHex: colorHex,
      role: role,
      createdAt: current.createdAt,
    );
    await _database.saveIdentity(updated);
    await _broadcastOwnTelemetryIfLocated(updated);
    if (mounted) {
      state = state.copyWith(identity: updated);
    }
    return updated;
  }

  /// Only advertise our position once it is real, so friends never see a
  /// made-up location on their radar.
  Future<void> _broadcastOwnTelemetryIfLocated(
    IdentityProfile identity, {
    double speedMetersPerSecond = 0.0,
  }) async {
    if (!state.hasLocationFix) return;
    await _bleMeshService.broadcastOwnTelemetry(
      identity: identity,
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      speedMetersPerSecond: speedMetersPerSecond,
    );
  }

  /// Toggles Sunlight High-Contrast Mode (`> 7:1` contrast ratio) or cycles
  /// visual theme (Section 2.2).
  void toggleSunlightHighContrast() {
    final SampanVisualMode next = state.isSunlightMode
        ? SampanVisualMode.light
        : SampanVisualMode.sunlightHighContrast;
    state = state.copyWith(visualMode: next);
    HapticFeedback.selectionClick();
  }

  void setVisualMode(SampanVisualMode mode) {
    state = state.copyWith(visualMode: mode);
  }

  /// Selects a caravan companion to track on the 3D Compass Homing Dial.
  void selectTargetPeer(String peerId) {
    state = state.copyWith(
      selectedTargetPeerId: peerId,
      clearSelectedTargetSpot: true,
    );
    _wasAlignedWithTarget = false;
    HapticFeedback.selectionClick();
  }

  /// Points the compass at a saved Spot (e.g. walk back to "Parking").
  void selectTargetSpot(String spotId) {
    state = state.copyWith(selectedTargetSpotId: spotId);
    _wasAlignedWithTarget = false;
    HapticFeedback.selectionClick();
  }

  void clearTargetSpot() {
    state = state.copyWith(clearSelectedTargetSpot: true);
    _wasAlignedWithTarget = false;
  }

  /// Switches chat scope between Caravan Group Ring (`null`) and 1-to-1 DM.
  void setActiveDmPeer(String? peerId) {
    if (peerId == null) {
      state = state.copyWith(clearActiveDmPeer: true);
    } else {
      state = state.copyWith(activeDmPeerId: peerId);
    }
  }

  /// Updates the magnetometer compass heading and fires a subtle haptic tick
  /// when crossing within `±10°` of the selected companion's bearing
  /// (Section 2.2).
  void updateCompassHeading(double headingDegrees) {
    final double normalized = GeoMath.normalizeDegrees(headingDegrees);
    final SpotModel? spot = state.selectedTargetSpot;
    final PeerModel? peer = spot == null ? state.selectedTargetPeer : null;
    final double? targetLat = spot?.latitude ?? peer?.lastLatitude;
    final double? targetLon = spot?.longitude ?? peer?.lastLongitude;
    if (state.hasLocationFix && targetLat != null && targetLon != null) {
      final double bearing = GeoMath.calculateBearingDegrees(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: targetLat,
        endLon: targetLon,
      );
      final bool aligned = GeoMath.isAlignedWithTarget(
        targetBearingDeg: bearing,
        deviceHeadingDeg: normalized,
      );
      if (aligned && !_wasAlignedWithTarget) {
        HapticFeedback.selectionClick();
      }
      _wasAlignedWithTarget = aligned;
    }

    state = state.copyWith(compassHeadingDegrees: normalized);
  }

  /// Polls native Android Magnetometer + Satellite GNSS GPS hardware.
  Future<void> refreshHardwareSensors() async {
    final DeviceSensorSnapshot? snapshot =
        await _nativeBridge.getHardwareSensorSnapshot();
    if (snapshot != null && mounted) {
      updateCompassHeading(snapshot.headingDegrees);
      state = state.copyWith(isCompassCalibrated: snapshot.isCompassCalibrated);
      if (snapshot.isHardwareGnss) {
        updateUserLocation(
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
        );
        final IdentityProfile? identity = state.identity;
        if (identity != null) {
          await _broadcastOwnTelemetryIfLocated(
            identity,
            speedMetersPerSecond: snapshot.speedMetersPerSecond,
          );
        }
      }
    }
    await _bleMeshService.pollAndIngestScannedFrames();
  }

  /// Applies a real position fix (from GNSS/network location).
  void updateUserLocation({
    required double latitude,
    required double longitude,
  }) {
    if (!mounted) return;
    state = state.copyWith(
      userLatitude: latitude,
      userLongitude: longitude,
      hasLocationFix: true,
    );
  }

  /// Clears a tripped Safety Leash alert for the selected person. The alarm
  /// re-arms and fires again if their signal stays weak for another 45s.
  Future<void> acknowledgeLeashAlert() async {
    final PeerModel? target = state.selectedTargetPeer;
    if (target == null) return;
    final PeerModel cleared = target.copyWith(
      clearWeakSignalSince: true,
      isLeashFrozen: false,
    );
    await _database.upsertPeer(cleared);
    if (mounted) {
      state = state.copyWith(peers: _database.currentPeers);
    }
    HapticFeedback.lightImpact();
  }

  /// Sends an encrypted Caravan Group message or 1-to-1 Direct Message.
  Future<void> sendChatMessage(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final IdentityProfile sender = state.identity ??
        IdentityProfile(
          publicKeyHex: kFallbackLocalPublicKeyHex,
          privateSeedHex: kFallbackLocalPublicKeyHex,
          displayName: 'Local Traveler',
          avatarIcon: '⛵',
          colorHex: 0xFF6755EF,
          role: 'traveler',
          createdAt: DateTime.now(),
        );

    // Build and verify binary GATT frame encryption round-trip
    await _bleMeshService.buildOutgoingMessageFrame(
      sender: sender,
      content: trimmed,
      isSos: false,
      recipientPublicKeyHex: state.activeDmPeerId,
    );

    final DateTime now = DateTime.now();
    final MessageModel msg = MessageModel(
      id: 'msg-${now.microsecondsSinceEpoch}',
      senderId: sender.publicKeyHex,
      senderName: sender.displayName,
      senderRole: sender.role,
      recipientId: state.activeDmPeerId,
      content: trimmed,
      type: 'text',
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      timestamp: now,
      isDelivered: true,
      isEncrypted: true,
    );
    await _database.insertMessage(msg);
    if (mounted) {
      state = state.copyWith(messages: _database.currentMessages);
    }
  }

  /// Saves a Spot at the user's current position. Returns `null` while
  /// there is no GPS fix yet (a spot needs a real location).
  Future<SpotModel?> createSpot({
    required String name,
    required String emoji,
  }) async {
    if (!state.hasLocationFix) return null;
    final String trimmed = name.trim();
    final String safeName = trimmed.isEmpty
        ? 'My spot'
        : (trimmed.length > SpotModel.maxNameLength
            ? trimmed.substring(0, SpotModel.maxNameLength)
            : trimmed);
    final DateTime now = DateTime.now();
    final SpotModel spot = SpotModel(
      id: 'spot-${now.microsecondsSinceEpoch}',
      name: safeName,
      emoji: emoji,
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      createdAt: now,
    );
    await _database.upsertSpot(spot);
    if (mounted) {
      state = state.copyWith(spots: _database.currentSpots);
    }
    HapticFeedback.mediumImpact();
    return spot;
  }

  Future<void> deleteSpot(String spotId) async {
    await _database.deleteSpot(spotId);
    if (!mounted) return;
    state = state.copyWith(
      spots: _database.currentSpots,
      clearSelectedTargetSpot: state.selectedTargetSpotId == spotId,
    );
  }

  /// Shares a saved Spot with the group (or the open private chat).
  Future<void> shareSpot(SpotModel spot) async {
    final IdentityProfile? sender = state.identity;
    final DateTime now = DateTime.now();
    final String coords =
        GeoMath.formatCoordinates(spot.latitude, spot.longitude);
    final MessageModel ping = MessageModel(
      id: 'ping-${now.microsecondsSinceEpoch}',
      senderId: sender?.publicKeyHex ?? kFallbackLocalPublicKeyHex,
      senderName: sender?.displayName ?? 'Traveler',
      senderRole: sender?.role ?? 'traveler',
      recipientId: state.activeDmPeerId,
      content: '${spot.emoji} ${spot.name} · $coords',
      type: 'gps_ping',
      latitude: spot.latitude,
      longitude: spot.longitude,
      landmarkName: spot.name,
      timestamp: now,
      isDelivered: true,
      isEncrypted: true,
    );

    if (sender != null) {
      await _bleMeshService.buildOutgoingMessageFrame(
        sender: sender,
        content: ping.content,
        isSos: false,
        recipientPublicKeyHex: state.activeDmPeerId,
      );
    }

    await _database.insertMessage(ping);
    if (mounted) {
      state = state.copyWith(messages: _database.currentMessages);
    }
    HapticFeedback.mediumImpact();
  }

  /// Saves the phone hotspot name & password used for the "join Wi-Fi" QR.
  Future<void> saveHotspotCredentials({
    required String ssid,
    required String password,
  }) async {
    await _database.saveHotspotCredentials(ssid: ssid, password: password);
    if (!mounted) return;
    final SampanAppState cleared =
        state.copyWith(clearHotspotCredentials: true);
    state = cleared.copyWith(
      hotspotSsid: _database.hotspotSsid,
      hotspotPassword: _database.hotspotPassword,
    );
  }

  /// Fires the Digital Megaphone (SOS) high-priority unencrypted broadcast
  /// with bearing & distance telemetry and heavy haptic impact (Section 4.2).
  Future<void> broadcastSosMegaphone({
    required String emergencyMessage,
    String? landmarkName,
  }) async {
    final IdentityProfile sender = state.identity ??
        IdentityProfile(
          publicKeyHex: kFallbackLocalPublicKeyHex,
          privateSeedHex: kFallbackLocalPublicKeyHex,
          displayName: 'Traveler',
          avatarIcon: '🛟',
          colorHex: 0xFFBA1A1A,
          role: 'traveler',
          createdAt: DateTime.now(),
        );

    final PeerModel? guide = state.selectedTargetPeer;
    String telemetrySuffix = '';
    if (state.hasLocationFix &&
        guide != null &&
        guide.lastLatitude != null &&
        guide.lastLongitude != null) {
      final double bearing = GeoMath.calculateBearingDegrees(
        startLat: guide.lastLatitude!,
        startLon: guide.lastLongitude!,
        endLat: state.userLatitude,
        endLon: state.userLongitude,
      );
      final double dist = GeoMath.calculateHaversineDistanceMeters(
        startLat: guide.lastLatitude!,
        startLon: guide.lastLongitude!,
        endLat: state.userLatitude,
        endLon: state.userLongitude,
      );
      final String bearingStr =
          (bearing.round() % 360).toString().padLeft(3, '0');
      telemetrySuffix =
          ' [Bearing: $bearingStr°, ${GeoMath.formatDistance(dist)}]';
    }

    final String fullAlert =
        '🚨 SOS Alert from ${sender.displayName}: "$emergencyMessage"$telemetrySuffix';

    await _bleMeshService.buildOutgoingMessageFrame(
      sender: sender,
      content: fullAlert,
      isSos: true,
    );

    final DateTime now = DateTime.now();
    final MessageModel sosMsg = MessageModel(
      id: 'sos-${now.microsecondsSinceEpoch}',
      senderId: sender.publicKeyHex,
      senderName: sender.displayName,
      senderRole: sender.role,
      content: fullAlert,
      type: 'sos',
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      landmarkName: landmarkName,
      timestamp: now,
      isDelivered: true,
      isEncrypted: false,
    );

    _lastTriggeredSosId = sosMsg.id;
    await _database.insertMessage(sosMsg);
    if (mounted) {
      state = state.copyWith(
        messages: _database.currentMessages,
        activeSosAlert: sosMsg,
      );
    }
    HapticFeedback.heavyImpact();
  }

  void dismissActiveSosAlert() {
    state = state.copyWith(clearActiveSosAlert: true);
  }

  /// Starts or stops the embedded Dart `shelf` SoftAP Hotspot Hub on port 8080
  /// (Section 4, Module 3).
  Future<void> toggleSoftApHub({
    int port = SampanConstants.softApDefaultPort,
  }) async {
    if (_softApHubService.isRunning) {
      await _softApHubService.stopServer();
      if (mounted) {
        state = state.copyWith(
          isSoftApRunning: false,
          softApClientsCount: 0,
        );
      }
    } else {
      if (state.hasLocationFix) {
        _softApHubService.updateHostLocation(
          latitude: state.userLatitude,
          longitude: state.userLongitude,
        );
      }
      final int boundPort = await _softApHubService.startServer(port: port);
      final List<String> ips = await _nativeBridge.getLocalIpv4Addresses();
      if (mounted) {
        state = state.copyWith(
          isSoftApRunning: true,
          softApPort: boundPort,
          softApIps: ips,
          softApClientsCount: _softApHubService.connectedClientsCount,
          softApApkDownloads: _softApHubService.apkDownloadsCount,
        );
      }
    }
  }

  void refreshSoftApStats() {
    if (!mounted) return;
    state = state.copyWith(
      isSoftApRunning: _softApHubService.isRunning,
      softApPort: _softApHubService.activePort,
      softApClientsCount: _softApHubService.connectedClientsCount,
      softApApkDownloads: _softApHubService.apkDownloadsCount,
    );
  }

  /// Checks GitHub Releases (`8Masum/sampan`) for a newer APK version.
  Future<ReleaseUpdateInfo?> checkForAppUpdate({bool silent = false}) async {
    if (!mounted) return null;
    state = state.copyWith(
      isCheckingForUpdate: true,
      updateStatusMessage: (silent || state.isDownloadingUpdate)
          ? state.updateStatusMessage
          : 'Checking GitHub Releases...',
    );

    try {
      final ReleaseUpdateInfo info = await _appUpdateService.checkForUpdate(
        currentVersionOverride: state.installedVersion,
      );
      if (!mounted) return info;

      final String statusMsg = info.isUpdateAvailable
          ? 'Update ${info.tagName} (${info.formattedSize}) is available!'
          : 'You are on the latest version (v${info.currentVersion}).';

      state = state.copyWith(
        availableUpdate: info,
        isCheckingForUpdate: false,
        isUpdateBannerDismissed:
            info.isUpdateAvailable ? false : state.isUpdateBannerDismissed,
        updateStatusMessage:
            state.isDownloadingUpdate ? state.updateStatusMessage : statusMsg,
      );
      return info;
    } on Object {
      if (mounted) {
        state = state.copyWith(
          isCheckingForUpdate: false,
          updateStatusMessage: (silent || state.isDownloadingUpdate)
              ? state.updateStatusMessage
              : 'Offline — could not reach GitHub Releases.',
        );
      }
      return null;
    }
  }

  /// Downloads `Sampan.apk` from the latest GitHub Release and launches the
  /// native Android package installer (`ApkFileProvider`).
  Future<String> downloadAndInstallAppUpdate() async {
    if (state.isDownloadingUpdate) return 'busy';

    ReleaseUpdateInfo? resolvedRelease = state.availableUpdate;
    if (resolvedRelease == null && !state.isCheckingForUpdate) {
      resolvedRelease = await checkForAppUpdate(silent: true);
      if (!mounted) return 'failed';
    }

    final ReleaseUpdateInfo targetRelease = resolvedRelease ??
        ReleaseUpdateInfo(
          currentVersion: state.installedVersion,
          latestVersion: state.installedVersion,
          tagName: 'v${state.installedVersion}',
          releaseTitle: 'Sampan Latest Release',
          releaseNotes: 'Direct APK download from GitHub Releases.',
          apkDownloadUrl: SampanConstants.githubLatestApkDownloadUrl,
          isUpdateAvailable: false,
        );

    state = state.copyWith(
      isDownloadingUpdate: true,
      updateDownloadProgress: 0.0,
      updateStatusMessage:
          'Downloading ${targetRelease.tagName} from GitHub Releases...',
    );

    try {
      final String result = await _appUpdateService.downloadAndInstallUpdate(
        releaseInfo: targetRelease,
        onProgress: (double progress) {
          if (mounted) {
            state = state.copyWith(updateDownloadProgress: progress);
          }
        },
      );
      if (!mounted) return result;

      final String message = switch (result) {
        'installer_launched' =>
          'APK downloaded. Launching Android package installer...',
        'permission_requested' =>
          'Enable "Allow from this source" in Settings, then return to Sampan to finish installing.',
        _ => 'Could not launch Android package installer.',
      };

      state = state.copyWith(
        isDownloadingUpdate: false,
        updateDownloadProgress: 1.0,
        updateStatusMessage: message,
      );
      return result;
    } on Object {
      if (mounted) {
        state = state.copyWith(
          isDownloadingUpdate: false,
          updateStatusMessage:
              'Update download failed. Check your internet connection and try again.',
        );
      }
      return 'failed';
    }
  }

  void dismissUpdateBanner() {
    state = state.copyWith(isUpdateBannerDismissed: true);
  }

  @override
  void dispose() {
    _hardwareSyncTimer?.cancel();
    _peersSub?.cancel();
    _messagesSub?.cancel();
    _spotsSub?.cancel();
    _hubStatsSub?.cancel();
    _softApHubService.stopServer();
    super.dispose();
  }
}

final Provider<LocalDatabase> localDatabaseProvider =
    Provider<LocalDatabase>((Ref ref) {
  final LocalDatabase db = LocalDatabase();
  ref.onDispose(db.dispose);
  return db;
});

final Provider<IdentityCryptoService> identityCryptoServiceProvider =
    Provider<IdentityCryptoService>((Ref ref) {
  return IdentityCryptoService();
});

final Provider<BleMeshService> bleMeshServiceProvider =
    Provider<BleMeshService>((Ref ref) {
  return BleMeshService(
    database: ref.watch(localDatabaseProvider),
    cryptoService: ref.watch(identityCryptoServiceProvider),
  );
});

final Provider<SoftApHubService> softApHubServiceProvider =
    Provider<SoftApHubService>((Ref ref) {
  final SoftApHubService hub = SoftApHubService(
    database: ref.watch(localDatabaseProvider),
  );
  ref.onDispose(hub.stopServer);
  return hub;
});

final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>((Ref ref) {
  return AppUpdateService();
});

final StateNotifierProvider<SampanController, SampanAppState>
    sampanControllerProvider =
    StateNotifierProvider<SampanController, SampanAppState>((Ref ref) {
  return SampanController(
    database: ref.watch(localDatabaseProvider),
    cryptoService: ref.watch(identityCryptoServiceProvider),
    bleMeshService: ref.watch(bleMeshServiceProvider),
    softApHubService: ref.watch(softApHubServiceProvider),
    appUpdateService: ref.watch(appUpdateServiceProvider),
  );
});
