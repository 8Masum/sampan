import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/landmarks.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/chat/caravan_chat_tab.dart';
import 'package:sampan/ui/hub/softap_hub_tab.dart';
import 'package:sampan/ui/radar/compass_radar_tab.dart';

/// Minimalist Material Design 3 Expressive Home Shell for Sampan.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  void _openCaravanRosterSheet(BuildContext context, SampanAppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.56,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              children: <Widget>[
                Text(
                  'People Nearby (${state.peers.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap anyone to point your compass toward them.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ...state.peers.map((PeerModel peer) {
                  final double dist = (peer.lastLatitude != null &&
                          peer.lastLongitude != null)
                      ? GeoMath.calculateHaversineDistanceMeters(
                          startLat: state.userLatitude,
                          startLon: state.userLongitude,
                          endLat: peer.lastLatitude!,
                          endLon: peer.lastLongitude!,
                        )
                      : 0.0;
                  final double bearing = (peer.lastLatitude != null &&
                          peer.lastLongitude != null)
                      ? GeoMath.calculateBearingDegrees(
                          startLat: state.userLatitude,
                          startLon: state.userLongitude,
                          endLat: peer.lastLatitude!,
                          endLon: peer.lastLongitude!,
                        )
                      : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(peer.colorHex),
                        child: Text(
                          peer.avatarIcon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(
                        peer.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${peer.isGuide ? 'Guide' : 'Traveler'} · '
                        '${GeoMath.formatDistance(dist)} · '
                        '${GeoMath.cardinalDirectionFromBearing(bearing)}',
                      ),
                      trailing: IconButton.filledTonal(
                        tooltip: 'Message',
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        onPressed: () {
                          ref
                              .read(sampanControllerProvider.notifier)
                              .setActiveDmPeer(peer.id);
                          Navigator.of(ctx).pop();
                          setState(() => _selectedIndex = 1);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(sampanControllerProvider.notifier)
                            .selectTargetPeer(peer.id);
                        Navigator.of(ctx).pop();
                        setState(() => _selectedIndex = 0);
                      },
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  void _openSpatioTemporalNoticeboardSheet(
    BuildContext context,
    SampanAppState state,
  ) {
    final List<MessageModel> notices = state.messages
        .where((MessageModel m) => m.isSos || m.isGpsPing || !m.isDirectMessage)
        .toList()
        .reversed
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.60,
          minChildSize: 0.38,
          maxChildSize: 0.90,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              children: <Widget>[
                Text(
                  'Group Pins & Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share a meeting spot with one tap.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OfflineLandmarks.coxsBazarAndCoastal
                      .map((OfflineLandmark landmark) {
                    return ActionChip(
                      avatar: Text(landmark.icon),
                      label: Text(
                        landmark.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(sampanControllerProvider.notifier)
                            .sendLandmarkPing(landmark);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ...notices.map((MessageModel item) {
                  final String hh =
                      item.timestamp.hour.toString().padLeft(2, '0');
                  final String mm =
                      item.timestamp.minute.toString().padLeft(2, '0');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: item.isSos
                          ? scheme.errorContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item.isSos
                            ? Icons.warning_amber_rounded
                            : (item.isGpsPing
                                ? Icons.place_rounded
                                : Icons.push_pin_rounded),
                        color: item.isSos ? scheme.error : scheme.primary,
                      ),
                      title: Text(
                        '${item.senderName} · $hh:$mm',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(item.content),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  void _openGpsAndProtocolInspectorSheet(
    BuildContext context,
    SampanAppState state,
  ) {
    final IdentityProfile? id = state.identity;
    final TelemetryPacket samplePacket = TelemetryPacket(
      isGuide: id?.isGuide ?? true,
      latitude: state.userLatitude,
      longitude: state.userLongitude,
      speedMetersPerSecond: 1.1,
      truncatedKeyHex: id?.truncated14ByteHex ?? '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
    );
    final String hexWire = SampanWireProtocol.bytesToHex(
      SampanWireProtocol.encodeTelemetryPacket(samplePacket),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'My Offline Signal',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your phone is broadcasting an offline beacon to nearby friends.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      id?.fingerprintUri ?? 'sampan:ed25519:uninitialized',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'GPS: ${state.userLatitude.toStringAsFixed(5)}°N, '
                      '${state.userLongitude.toStringAsFixed(5)}°E',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      hexWire,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAppUpdateSheet(BuildContext context) {
    final SampanAppState current = ref.read(sampanControllerProvider);
    if (current.availableUpdate == null && !current.isCheckingForUpdate) {
      ref.read(sampanControllerProvider.notifier).checkForAppUpdate();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Consumer(
          builder: (BuildContext ctx, WidgetRef sheetRef, Widget? _) {
            final SampanAppState liveState =
                sheetRef.watch(sampanControllerProvider);
            final SampanController notifier =
                sheetRef.read(sampanControllerProvider.notifier);
            final ColorScheme scheme = Theme.of(ctx).colorScheme;
            final ReleaseUpdateInfo? release = liveState.availableUpdate;
            final bool hasUpdate = liveState.hasAvailableUpdate;
            final int pct =
                (liveState.updateDownloadProgress * 100).round().clamp(0, 100);

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          hasUpdate
                              ? Icons.system_update_rounded
                              : Icons.verified_rounded,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'GitHub Release Auto-Update',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Installed: v${liveState.installedVersion}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            release != null
                                ? 'Latest: ${release.tagName} (${release.formattedSize})'
                                : '${SampanConstants.githubOwner}/${SampanConstants.githubRepo}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          if (liveState.updateStatusMessage != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              liveState.updateStatusMessage!,
                              key: const ValueKey<String>(
                                'update-status-message-text',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (release != null &&
                        release.releaseNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        release.releaseTitle,
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 110),
                        child: SingleChildScrollView(
                          child: Text(
                            release.releaseNotes,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                    if (liveState.isDownloadingUpdate) ...<Widget>[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: liveState.updateDownloadProgress > 0
                            ? liveState.updateDownloadProgress
                            : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Downloading... $pct%',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey<String>('check-for-update-btn'),
                            onPressed: (liveState.isCheckingForUpdate ||
                                    liveState.isDownloadingUpdate)
                                ? null
                                : () => notifier.checkForAppUpdate(
                                      silent: false,
                                    ),
                            icon: liveState.isCheckingForUpdate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              liveState.isCheckingForUpdate
                                  ? 'Checking...'
                                  : 'Check',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey<String>(
                              'download-install-update-btn',
                            ),
                            onPressed: liveState.isDownloadingUpdate
                                ? null
                                : notifier.downloadAndInstallAppUpdate,
                            icon: const Icon(
                              Icons.download_for_offline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              hasUpdate
                                  ? 'Update (${release!.tagName})'
                                  : 'Reinstall',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MessageModel? sosAlert = state.activeSosAlert;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                SampanConstants.logoAssetPath,
                width: 34,
                height: 34,
                filterQuality: FilterQuality.high,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return Text(
                    state.identity?.avatarIcon ?? '⛵',
                    style: const TextStyle(fontSize: 20),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Sampan',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('toggle-sunlight-mode-btn'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Outdoor Contrast',
            onPressed: controller.toggleSunlightHighContrast,
            icon: Icon(
              state.isSunlightMode
                  ? Icons.wb_sunny_rounded
                  : Icons.wb_sunny_outlined,
              size: 20,
            ),
          ),
          IconButton(
            key: const ValueKey<String>('toggle-dark-mode-btn'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Theme',
            onPressed: () {
              final SampanVisualMode next =
                  state.visualMode == SampanVisualMode.dark
                      ? SampanVisualMode.light
                      : SampanVisualMode.dark;
              controller.setVisualMode(next);
            },
            icon: Icon(
              state.visualMode == SampanVisualMode.dark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_outlined,
              size: 20,
            ),
          ),
          IconButton(
            key: const ValueKey<String>('open-noticeboard-btn'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Group Pins',
            onPressed: () =>
                _openSpatioTemporalNoticeboardSheet(context, state),
            icon: const Icon(Icons.push_pin_outlined, size: 20),
          ),
          IconButton(
            key: const ValueKey<String>('open-protocol-inspector-btn'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Signal Info',
            onPressed: () => _openGpsAndProtocolInspectorSheet(context, state),
            icon: const Icon(Icons.sensors_rounded, size: 20),
          ),
          IconButton(
            key: const ValueKey<String>('open-update-sheet-btn'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Updates',
            onPressed: () => _openAppUpdateSheet(context),
            icon: Badge(
              isLabelVisible: state.hasAvailableUpdate,
              backgroundColor: SampanTheme.brandViolet,
              child: const Icon(Icons.system_update_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Minimal Status Pills Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-ble-peers'),
                    label: '${state.peers.length} nearby',
                    isHighlighted: true,
                    onTap: () => _openCaravanRosterSheet(context, state),
                  ),
                  const SizedBox(width: 8),
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-hotspot-status'),
                    label: state.isSoftApRunning
                        ? 'Hub live · ${state.softApClientsCount}'
                        : 'Host hub',
                    isHighlighted: state.isSoftApRunning,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  const SizedBox(width: 8),
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-compass-status'),
                    label: state.isCompassCalibrated
                        ? 'Compass ready'
                        : 'Calibrate',
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ],
              ),
            ),
          ),

          // Update Available Pill Banner
          if (state.hasAvailableUpdate && !state.isUpdateBannerDismissed)
            Container(
              key: const ValueKey<String>('update-available-banner'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SampanTheme.brandLime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: SampanTheme.violet900,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sampan ${state.availableUpdate!.tagName} is ready',
                      style: const TextStyle(
                        color: SampanTheme.violet900,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey<String>('banner-install-update-btn'),
                    onPressed: () {
                      _openAppUpdateSheet(context);
                      controller.downloadAndInstallAppUpdate();
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        color: SampanTheme.violet900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('dismiss-update-banner-btn'),
                    onPressed: controller.dismissUpdateBanner,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: SampanTheme.violet900,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Active SOS Emergency Banner
          if (sosAlert != null)
            Container(
              key: const ValueKey<String>('active-sos-alert-banner'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: scheme.onError),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sosAlert.content,
                      style: TextStyle(
                        color: scheme.onError,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('dismiss-sos-alert-btn'),
                    onPressed: controller.dismissActiveSosAlert,
                    icon: Icon(Icons.close_rounded, color: scheme.onError),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Active Tab Body
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const <Widget>[
                CompassRadarTab(),
                CaravanChatTab(),
                SoftApHubTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            key: ValueKey<String>('nav-radar'),
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Radar',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-chat'),
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-hub'),
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering_rounded),
            label: 'Hub',
          ),
        ],
      ),
    );
  }
}

class _FloatingStatusPill extends StatelessWidget {
  const _FloatingStatusPill({
    super.key,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isHighlighted
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isHighlighted) ...<Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isHighlighted
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
