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
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/chat/caravan_chat_tab.dart';
import 'package:sampan/ui/hub/softap_hub_tab.dart';
import 'package:sampan/ui/radar/compass_radar_tab.dart';

/// Main Material Design 3 Shell combining all three core Sampan modules,
/// Floating Status Pills, Sunlight High-Contrast toggle, and Expansive
/// Draggable Bottom Sheets (Section 2.2 & Section 4).
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
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: <Widget>[
                Text(
                  'Caravan Roster (${state.peers.length} Peers in BLE Range)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any companion to lock the 3D Compass Homing Dial onto their bearing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
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

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(peer.colorHex),
                        child: Text(peer.avatarIcon),
                      ),
                      title: Text(
                        '${peer.displayName} ${peer.isGuide ? '• Guide' : '• Traveler'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${peer.fingerprintUri}\n'
                        'Bearing: ${bearing.round()}° (${GeoMath.cardinalDirectionFromBearing(bearing)}) • '
                        '${GeoMath.formatDistance(dist)} • RSSI ${peer.rssiDbm} dBm',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Open Direct Message',
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
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
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.38,
          maxChildSize: 0.90,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: <Widget>[
                Text(
                  'Spatio-Temporal Noticeboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pinned caravan rendezvous waypoints, offline landmark pings, and emergency bulletins.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OfflineLandmarks.coxsBazarAndCoastal
                      .map((OfflineLandmark landmark) {
                    return ActionChip(
                      avatar: Text(landmark.icon),
                      label: Text(
                        'Pin ${landmark.name}',
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
                const SizedBox(height: 14),
                ...notices.map((MessageModel item) {
                  final String hh =
                      item.timestamp.hour.toString().padLeft(2, '0');
                  final String mm =
                      item.timestamp.minute.toString().padLeft(2, '0');
                  final String coords =
                      (item.latitude != null && item.longitude != null)
                          ? ' • ${item.latitude!.toStringAsFixed(4)}°N, ${item.longitude!.toStringAsFixed(4)}°E'
                          : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        item.isSos
                            ? Icons.warning_amber_rounded
                            : (item.isGpsPing
                                ? Icons.place_rounded
                                : Icons.push_pin_rounded),
                        color: item.isSos
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      title: Text(
                        '${item.senderName} • $hh:$mm$coords',
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
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'GPS Coordinate & Binary Wire Inspector',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Identity URI: ${id?.fingerprintUri ?? 'sampan:ed25519:uninitialized'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'BLE Service UUID: ${SampanConstants.bleServiceUuid}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Offline Satellite GNSS: ${state.userLatitude.toStringAsFixed(5)}°N, '
                '${state.userLongitude.toStringAsFixed(5)}°E',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '28-Byte BLE Telemetry Frame (0x53 0x50 Header):',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  hexWire,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  state.identity?.avatarIcon ?? '⛵',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Sampan (সাম্পান)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
            Text(
              state.identity?.fingerprintUri ?? 'Zero-Cloud P2P Mesh',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: <Widget>[
          // Sunlight High-Contrast Mode Toggle (>7:1 Contrast Ratio)
          IconButton(
            key: const ValueKey<String>('toggle-sunlight-mode-btn'),
            tooltip: state.isSunlightMode
                ? 'Disable Sunlight High-Contrast Mode'
                : 'Enable Sunlight High-Contrast Mode (>7:1)',
            onPressed: controller.toggleSunlightHighContrast,
            icon: Icon(
              state.isSunlightMode
                  ? Icons.wb_sunny_rounded
                  : Icons.wb_sunny_outlined,
              color: state.isSunlightMode ? scheme.secondary : null,
            ),
          ),
          // Night / Day Mode Toggle
          IconButton(
            key: const ValueKey<String>('toggle-dark-mode-btn'),
            tooltip: 'Switch Light / Dark Coastal Theme',
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
            ),
          ),
          // Spatio-Temporal Noticeboard Bottom Sheet
          IconButton(
            key: const ValueKey<String>('open-noticeboard-btn'),
            tooltip: 'Spatio-Temporal Noticeboard',
            onPressed: () =>
                _openSpatioTemporalNoticeboardSheet(context, state),
            icon: const Icon(Icons.campaign_outlined),
          ),
          // GPS & Binary Protocol Inspector Bottom Sheet
          IconButton(
            key: const ValueKey<String>('open-protocol-inspector-btn'),
            tooltip: 'GPS & Binary Wire Protocol Inspector',
            onPressed: () => _openGpsAndProtocolInspectorSheet(context, state),
            icon: const Icon(Icons.radar_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Floating Status Pills (Section 2.2)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-ble-peers'),
                    label: '🟢 ${state.peers.length} Peers in Range (BLE)',
                    onTap: () => _openCaravanRosterSheet(context, state),
                  ),
                  const SizedBox(width: 8),
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-hotspot-status'),
                    label: state.isSoftApRunning
                        ? '📡 Hotspot Active (${state.softApClientsCount} Connected)'
                        : '📡 Hotspot Standby (Tap to Host)',
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  const SizedBox(width: 8),
                  _FloatingStatusPill(
                    key: const ValueKey<String>('pill-compass-status'),
                    label: state.isCompassCalibrated
                        ? '🧭 Compass Calibrated'
                        : '🧭 Calibrate Compass',
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ],
              ),
            ),
          ),

          // Active SOS Digital Megaphone Emergency Banner (Section 4, Module 2)
          if (sosAlert != null)
            Container(
              key: const ValueKey<String>('active-sos-alert-banner'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(16),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('dismiss-sos-alert-btn'),
                    onPressed: controller.dismissActiveSosAlert,
                    icon: Icon(Icons.close, color: scheme.onError),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Active Module View
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
            label: 'Compass Radar',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-chat'),
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Caravan Chat',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-hub'),
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering_rounded),
            label: 'SoftAP Hub',
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
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.primary.withAlpha(90)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
