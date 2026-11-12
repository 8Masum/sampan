import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/landmarks.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/data/services/ble_mesh_service.dart';
import 'package:sampan/data/services/native_bridge.dart';
import 'package:sampan/data/services/softap_hub_service.dart';

/// Immutable application state managed by Riverpod 2.x.
@immutable
class SampanAppState {
  const SampanAppState({
    required this.isInitialized,
    required this.visualMode,
    required this.userLatitude,
    required this.userLongitude,
    required this.compassHeadingDegrees,
    required this.isCompassCalibrated,
    required this.peers,
    required this.messages,
    required this.isSoftApRunning,
    required this.softApPort,
    required this.softApIps,
    required this.softApClientsCount,
    required this.softApApkDownloads,
    required this.isBleBeaconing,
    this.installedVersion = SampanConstants.appVersion,
    this.availableUpdate,
    this.isCheckingForUpdate = false,
    this.isDownloadingUpdate = false,
    this.updateDownloadProgress = 0.0,
    this.updateStatusMessage,
    this.isUpdateBannerDismissed = false,
    this.identity,
    this.selectedTargetPeerId,
    this.activeDmPeerId,
    this.activeSosAlert,
  });

  factory SampanAppState.initial() {
    return const SampanAppState(
      isInitialized: false,
      visualMode: SampanVisualMode.light,
      userLatitude: 21.4272, // Laboni Point, Cox's Bazar
      userLongitude: 91.9702,
      compassHeadingDegrees: 18.0,
      isCompassCalibrated: true,
      peers: <PeerModel>[],
      messages: <MessageModel>[],
      isSoftApRunning: false,
      softApPort: SampanConstants.softApDefaultPort,
      softApIps: <String>['192.168.43.1'],
      softApClientsCount: 0,
      softApApkDownloads: 0,
      isBleBeaconing: true,
    );
  }

  final bool isInitialized;
  final SampanVisualMode visualMode;
  final IdentityProfile? identity;
  final double userLatitude;
  final double userLongitude;
  final double compassHeadingDegrees;
  final bool isCompassCalibrated;
  final List<PeerModel> peers;
  final List<MessageModel> messages;
  final String? selectedTargetPeerId;
  final String? activeDmPeerId;
  final MessageModel? activeSosAlert;
  final bool isSoftApRunning;
  final int softApPort;
  final List<String> softApIps;
  final int softApClientsCount;
  final int softApApkDownloads;
  final bool isBleBeaconing;
  final String installedVersion;
  final ReleaseUpdateInfo? availableUpdate;
  final bool isCheckingForUpdate;
  final bool isDownloadingUpdate;
  final double updateDownloadProgress;
  final String? updateStatusMessage;
  final bool isUpdateBannerDismissed;

  bool get isSunlightMode =>
      visualMode == SampanVisualMode.sunlightHighContrast;

  bool get hasAvailableUpdate =>
      availableUpdate != null && availableUpdate!.isUpdateAvailable;

  PeerModel? get selectedTargetPeer {
    if (peers.isEmpty) return null;
    if (selectedTargetPeerId != null) {
      for (final PeerModel p in peers) {
        if (p.id == selectedTargetPeerId) return p;
      }
    }
    return peers.first;
  }

  PeerModel? get activeDmPeer {
    if (activeDmPeerId == null) return null;
    for (final PeerModel p in peers) {
      if (p.id == activeDmPeerId) return p;
    }
    return null;
  }

  List<PeerModel> get trippedLeashPeers =>
      peers.where((PeerModel p) => p.isLeashFrozen).toList(growable: false);

  SampanAppState copyWith({
    bool? isInitialized,
    SampanVisualMode? visualMode,
    IdentityProfile? identity,
    bool clearIdentity = false,
    double? userLatitude,
    double? userLongitude,
    double? compassHeadingDegrees,
    bool? isCompassCalibrated,
    List<PeerModel>? peers,
    List<MessageModel>? messages,
    String? selectedTargetPeerId,
    String? activeDmPeerId,
    bool clearActiveDmPeer = false,
    MessageModel? activeSosAlert,
    bool clearActiveSosAlert = false,
    bool? isSoftApRunning,
    int? softApPort,
    List<String>? softApIps,
    int? softApClientsCount,
    int? softApApkDownloads,
    bool? isBleBeaconing,
    String? installedVersion,
    ReleaseUpdateInfo? availableUpdate,
    bool clearAvailableUpdate = false,
    bool? isCheckingForUpdate,
    bool? isDownloadingUpdate,
    double? updateDownloadProgress,
    String? updateStatusMessage,
    bool clearUpdateStatusMessage = false,
    bool? isUpdateBannerDismissed,
  }) {
    return SampanAppState(
      isInitialized: isInitialized ?? this.isInitialized,
      visualMode: visualMode ?? this.visualMode,
      identity: clearIdentity ? null : (identity ?? this.identity),
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      compassHeadingDegrees:
          compassHeadingDegrees ?? this.compassHeadingDegrees,
      isCompassCalibrated: isCompassCalibrated ?? this.isCompassCalibrated,
      peers: peers ?? this.peers,
      messages: messages ?? this.messages,
      selectedTargetPeerId: selectedTargetPeerId ?? this.selectedTargetPeerId,
      activeDmPeerId:
          clearActiveDmPeer ? null : (activeDmPeerId ?? this.activeDmPeerId),
      activeSosAlert:
          clearActiveSosAlert ? null : (activeSosAlert ?? this.activeSosAlert),
      isSoftApRunning: isSoftApRunning ?? this.isSoftApRunning,
      softApPort: softApPort ?? this.softApPort,
      softApIps: softApIps ?? this.softApIps,
      softApClientsCount: softApClientsCount ?? this.softApClientsCount,
      softApApkDownloads: softApApkDownloads ?? this.softApApkDownloads,
      isBleBeaconing: isBleBeaconing ?? this.isBleBeaconing,
      installedVersion: installedVersion ?? this.installedVersion,
      availableUpdate:
          clearAvailableUpdate ? null : (availableUpdate ?? this.availableUpdate),
      isCheckingForUpdate: isCheckingForUpdate ?? this.isCheckingForUpdate,
      isDownloadingUpdate: isDownloadingUpdate ?? this.isDownloadingUpdate,
      updateDownloadProgress:
          updateDownloadProgress ?? this.updateDownloadProgress,
      updateStatusMessage: clearUpdateStatusMessage
          ? null
          : (updateStatusMessage ?? this.updateStatusMessage),
      isUpdateBannerDismissed:
          isUpdateBannerDismissed ?? this.isUpdateBannerDismissed,
    );
  }
}

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
  StreamSubscription<void>? _hubStatsSub;
  Timer? _hardwareSyncTimer;
  String? _lastTriggeredSosId;
  bool _wasAlignedWithTarget = false;

  Future<void> _init() async {
    await _database.initialize();
    await _database.seedDemoCaravanIfEmpty();

    if (!mounted) return;
    final List<PeerModel> initialPeers = _database.currentPeers;
    final IdentityProfile? savedIdentity = _database.identity;
    state = state.copyWith(
      isInitialized: true,
      identity: savedIdentity,
      peers: initialPeers,
      messages: _database.currentMessages,
      selectedTargetPeerId: state.selectedTargetPeerId ??
          (initialPeers.isNotEmpty ? initialPeers.first.id : null),
    );

    if (savedIdentity != null) {
      await _nativeBridge.requestRuntimePermissions();
      await _bleMeshService.broadcastOwnTelemetry(
        identity: savedIdentity,
        latitude: state.userLatitude,
        longitude: state.userLongitude,
        speedMetersPerSecond: 0.9,
      );
    }

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
    await _bleMeshService.broadcastOwnTelemetry(
      identity: profile,
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      speedMetersPerSecond: 0.9,
    );

    if (mounted) {
      state = state.copyWith(identity: profile);
    }
    return profile;
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
    state = state.copyWith(selectedTargetPeerId: peerId);
    _wasAlignedWithTarget = false;
    HapticFeedback.selectionClick();
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
    final PeerModel? target = state.selectedTargetPeer;
    if (target != null &&
        target.lastLatitude != null &&
        target.lastLongitude != null) {
      final double bearing = GeoMath.calculateBearingDegrees(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: target.lastLatitude!,
        endLon: target.lastLongitude!,
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
      state = state.copyWith(
        userLatitude: snapshot.latitude,
        userLongitude: snapshot.longitude,
        isCompassCalibrated: snapshot.isCompassCalibrated,
      );
      if (state.identity != null) {
        await _bleMeshService.broadcastOwnTelemetry(
          identity: state.identity!,
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
          speedMetersPerSecond: snapshot.speedMetersPerSecond,
        );
      }
    }
    await _bleMeshService.pollAndIngestScannedFrames();
  }

  /// Simulates a Virtual Leash breach (`RSSI < -85 dBm` for `> 45s`) on the
  /// selected companion so users can verify the audible/haptic leash alarm
  /// and frozen last-known GPS coordinates (Section 4, Module 1).
  Future<void> simulateVirtualLeashDropOnSelectedPeer() async {
    final PeerModel? target = state.selectedTargetPeer;
    if (target == null) return;

    final DateTime now = DateTime.now();
    final DateTime weakStart = now.subtract(const Duration(seconds: 50));
    final PeerModel seeded = target.copyWith(
      weakSignalSince: weakStart,
      rssiDbm: -92,
    );
    await _database.upsertPeer(seeded);

    // Encode a 28-byte BLE telemetry frame for the target companion with
    // drifted coordinates while RSSI is -92 dBm (> 45s below -85 dBm):
    // ingestRawTelemetryFrame detects the leash trip and freezes the
    // companion's last-known GPS coordinates on the radar.
    final Uint8List targetPacket = SampanWireProtocol.encodeTelemetryPacket(
      TelemetryPacket(
        isGuide: target.isGuide,
        latitude: (target.lastLatitude ?? 21.4278) + 0.0040,
        longitude: (target.lastLongitude ?? 91.9708) + 0.0040,
        speedMetersPerSecond: 1.5,
        truncatedKeyHex: target.id.length >= 28
            ? target.id.substring(0, 28)
            : target.id.padRight(28, '0'),
      ),
    );

    await _bleMeshService.ingestRawTelemetryFrame(
      rawBytes: targetPacket,
      rssiDbm: -92,
      receivedAt: now,
    );

    if (mounted) {
      state = state.copyWith(peers: _database.currentPeers);
    }
    HapticFeedback.heavyImpact();
  }

  /// Restores strong BLE signal (`-58 dBm`) for the selected peer and clears
  /// the Virtual Leash alarm.
  Future<void> restoreSelectedPeerSignal() async {
    final PeerModel? target = state.selectedTargetPeer;
    if (target == null) return;
    final PeerModel restored = target.copyWith(
      rssiDbm: -58,
      clearWeakSignalSince: true,
      isLeashFrozen: false,
      lastSeen: DateTime.now(),
    );
    await _database.upsertPeer(restored);
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

  /// Broadcasts a one-tap Offline Landmark Ping (Section 4, Module 2).
  Future<void> sendLandmarkPing(OfflineLandmark landmark) async {
    final IdentityProfile? sender = state.identity;
    final DateTime now = DateTime.now();
    final String coords =
        '${landmark.latitude.toStringAsFixed(4)}, ${landmark.longitude.toStringAsFixed(4)}';
    final MessageModel ping = MessageModel(
      id: 'ping-${now.microsecondsSinceEpoch}',
      senderId: sender?.publicKeyHex ?? kFallbackLocalPublicKeyHex,
      senderName: sender?.displayName ?? 'Local Traveler',
      senderRole: sender?.role ?? 'traveler',
      recipientId: state.activeDmPeerId,
      content: '${landmark.icon} Landmark Ping: At ${landmark.name} ($coords)',
      type: 'gps_ping',
      latitude: landmark.latitude,
      longitude: landmark.longitude,
      landmarkName: landmark.name,
      timestamp: now,
      isDelivered: true,
      isEncrypted: true,
    );

    if (sender != null) {
      await _bleMeshService.broadcastOwnTelemetry(
        identity: sender,
        latitude: landmark.latitude,
        longitude: landmark.longitude,
        speedMetersPerSecond: 0.8,
      );
      await _bleMeshService.buildOutgoingMessageFrame(
        sender: sender,
        content: ping.content,
        isSos: false,
        recipientPublicKeyHex: state.activeDmPeerId,
      );
    }

    _softApHubService.updateHostLocation(
      latitude: landmark.latitude,
      longitude: landmark.longitude,
      landmark: landmark.name,
    );
    await _database.insertMessage(ping);
    if (mounted) {
      state = state.copyWith(
        userLatitude: landmark.latitude,
        userLongitude: landmark.longitude,
        messages: _database.currentMessages,
      );
    }
    HapticFeedback.mediumImpact();
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
          displayName: 'Rahim',
          avatarIcon: '🛟',
          colorHex: 0xFFBA1A1A,
          role: 'traveler',
          createdAt: DateTime.now(),
        );

    final PeerModel? guide = state.selectedTargetPeer;
    String telemetrySuffix = '';
    if (guide != null &&
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
      landmarkName: landmarkName ?? 'Laboni Point',
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
      _softApHubService.updateHostLocation(
        latitude: state.userLatitude,
        longitude: state.userLongitude,
      );
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
