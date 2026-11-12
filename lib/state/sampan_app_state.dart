import 'package:flutter/foundation.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/data/services/app_update_service.dart';

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
    this.hasLocationFix = false,
    this.spots = const <SpotModel>[],
    this.selectedTargetSpotId,
    this.hotspotSsid,
    this.hotspotPassword,
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
      userLatitude: 0.0,
      userLongitude: 0.0,
      compassHeadingDegrees: 0.0,
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

  /// True once a real GNSS/network position was received. Until then the
  /// user's coordinates are unknown and distances are not shown.
  final bool hasLocationFix;
  final List<SpotModel> spots;

  /// When set, the compass guides the user to this saved Spot instead of a
  /// person.
  final String? selectedTargetSpotId;
  final String? hotspotSsid;
  final String? hotspotPassword;
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

  SpotModel? get selectedTargetSpot {
    if (selectedTargetSpotId == null) return null;
    for (final SpotModel spot in spots) {
      if (spot.id == selectedTargetSpotId) return spot;
    }
    return null;
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
    bool? hasLocationFix,
    List<SpotModel>? spots,
    String? selectedTargetSpotId,
    bool clearSelectedTargetSpot = false,
    String? hotspotSsid,
    String? hotspotPassword,
    bool clearHotspotCredentials = false,
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
      hasLocationFix: hasLocationFix ?? this.hasLocationFix,
      spots: spots ?? this.spots,
      selectedTargetSpotId: clearSelectedTargetSpot
          ? null
          : (selectedTargetSpotId ?? this.selectedTargetSpotId),
      hotspotSsid:
          clearHotspotCredentials ? null : (hotspotSsid ?? this.hotspotSsid),
      hotspotPassword: clearHotspotCredentials
          ? null
          : (hotspotPassword ?? this.hotspotPassword),
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
