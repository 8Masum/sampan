import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/radar/compass_dial_painter.dart';

/// Module 1: Directional Compass Radar & "Virtual Leash"
/// (Section 4, Module 1 of `SAMPAN_BLUEPRINT.md`).
class CompassRadarTab extends ConsumerWidget {
  const CompassRadarTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final PeerModel? target = state.selectedTargetPeer;
    final double targetLat = target?.lastLatitude ?? 21.4278;
    final double targetLon = target?.lastLongitude ?? 91.9708;

    final double bearingDeg = GeoMath.calculateBearingDegrees(
      startLat: state.userLatitude,
      startLon: state.userLongitude,
      endLat: targetLat,
      endLon: targetLon,
    );
    final double relativeNeedleDeg = GeoMath.calculateRelativeNeedleAngle(
      targetBearingDeg: bearingDeg,
      deviceHeadingDeg: state.compassHeadingDegrees,
    );
    final double distanceMeters = GeoMath.calculateHaversineDistanceMeters(
      startLat: state.userLatitude,
      startLon: state.userLongitude,
      endLat: targetLat,
      endLon: targetLon,
    );
    final bool isAligned = GeoMath.isAlignedWithTarget(
      targetBearingDeg: bearingDeg,
      deviceHeadingDeg: state.compassHeadingDegrees,
    );
    final String cardinal = GeoMath.cardinalDirectionFromBearing(bearingDeg);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        // Companion Selector Strip
        Text(
          'Homing Target (Caravan Peers)',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.peers.map((PeerModel peer) {
              final bool selected = peer.id == target?.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey<String>('target-chip-${peer.id}'),
                  selected: selected,
                  onSelected: (_) => controller.selectTargetPeer(peer.id),
                  avatar: Text(peer.avatarIcon),
                  label: Text(
                    '${peer.displayName}${peer.isGuide ? ' (Guide)' : ''}'
                    '${peer.isLeashFrozen ? ' ⚠️' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // 3D-Styled Compass Homing Dial with Spring Physics (Curves.elasticOut)
        Center(
          child: SizedBox(
            width: 268,
            height: 268,
            child: _SpringCompassDial(
              deviceHeadingDegrees: state.compassHeadingDegrees,
              relativeNeedleDegrees: relativeNeedleDeg,
              isAlignedWithTarget: isAligned,
              userLatitude: state.userLatitude,
              userLongitude: state.userLongitude,
              peers: state.peers,
              selectedPeerId: target?.id,
              isHighContrast: state.isSunlightMode,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Alignment Banner (±10° Haptic Lock)
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isAligned
                ? scheme.tertiaryContainer
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                isAligned
                    ? Icons.my_location_rounded
                    : Icons.compass_calibration_rounded,
                size: 20,
                color: isAligned
                    ? scheme.onTertiaryContainer
                    : scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isAligned
                      ? 'LOCKED ON TARGET (±10°): Walk straight ahead (${GeoMath.formatDistance(distanceMeters)})'
                      : 'Target: ${target?.displayName ?? 'None'} • Bearing ${bearingDeg.round().toString().padLeft(3, '0')}° ($cardinal) • ${GeoMath.formatDistance(distanceMeters)}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isAligned
                        ? scheme.onTertiaryContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Telemetry Metrics Grid
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: 'BEARING (β)',
                value:
                    '${bearingDeg.round().toString().padLeft(3, '0')}° ($cardinal)',
                subtitle:
                    'Heading α: ${state.compassHeadingDegrees.round().toString().padLeft(3, '0')}°',
                icon: Icons.explore_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'GREAT-CIRCLE DIST',
                value: GeoMath.formatDistance(distanceMeters),
                subtitle:
                    'RSSI: ${target?.rssiDbm ?? -60} dBm (${(target?.rssiDbm ?? -60) >= -85 ? 'Healthy' : 'Weak'})',
                icon: Icons.straighten_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Compass Heading Calibration & Sensor Fusion Control
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline.withAlpha(110)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Magnetometer Heading (α): ${state.compassHeadingDegrees.round()}°',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.refreshHardwareSensors,
                    icon: const Icon(Icons.sensors, size: 18),
                    label: const Text('Sync GNSS/BLE'),
                  ),
                ],
              ),
              Slider(
                key: const ValueKey<String>('compass-heading-slider'),
                value: state.compassHeadingDegrees.clamp(0.0, 359.0),
                min: 0.0,
                max: 359.0,
                label: '${state.compassHeadingDegrees.round()}°',
                onChanged: controller.updateCompassHeading,
              ),
              Text(
                'My Offline GNSS: ${state.userLatitude.toStringAsFixed(5)}°N, ${state.userLongitude.toStringAsFixed(5)}°E',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Virtual Leash Safety Monitor Card (Section 4, Module 1)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (target?.isLeashFrozen ?? false)
                ? scheme.errorContainer
                : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (target?.isLeashFrozen ?? false)
                  ? scheme.error
                  : scheme.outline.withAlpha(110),
              width: (target?.isLeashFrozen ?? false) ? 2.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    (target?.isLeashFrozen ?? false)
                        ? Icons.warning_amber_rounded
                        : Icons.shield_outlined,
                    color: (target?.isLeashFrozen ?? false)
                        ? scheme.error
                        : scheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (target?.isLeashFrozen ?? false)
                          ? 'VIRTUAL LEASH ALARM: ${target?.displayName} Signal Lost!'
                          : 'Virtual Leash Active (Threshold: -85 dBm / 45s)',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: (target?.isLeashFrozen ?? false)
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                (target?.isLeashFrozen ?? false)
                    ? 'Beacon RSSI dropped below -85 dBm for > 45s. Last-known GPS coordinates (${targetLat.toStringAsFixed(4)}, ${targetLon.toStringAsFixed(4)}) and bearing (${bearingDeg.round()}°) are frozen on radar.'
                    : 'Monitors BLE beacon RSSI continuously. Fires haptic/audible alert and freezes last-known GPS bearing if companion drifts out of range.',
                style: textTheme.bodySmall?.copyWith(
                  color: (target?.isLeashFrozen ?? false)
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('simulate-leash-drop-btn'),
                    onPressed: controller.simulateVirtualLeashDropOnSelectedPeer,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Test Leash Drop (<-85 dBm)'),
                  ),
                  if (target?.isLeashFrozen ?? false)
                    FilledButton.tonalIcon(
                      key: const ValueKey<String>('restore-leash-signal-btn'),
                      onPressed: controller.restoreSelectedPeerSignal,
                      icon: const Icon(Icons.bluetooth_connected, size: 18),
                      label: const Text('Restore Companion Signal'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpringCompassDial extends StatefulWidget {
  const _SpringCompassDial({
    required this.deviceHeadingDegrees,
    required this.relativeNeedleDegrees,
    required this.isAlignedWithTarget,
    required this.userLatitude,
    required this.userLongitude,
    required this.peers,
    required this.selectedPeerId,
    required this.isHighContrast,
  });

  final double deviceHeadingDegrees;
  final double relativeNeedleDegrees;
  final bool isAlignedWithTarget;
  final double userLatitude;
  final double userLongitude;
  final List<PeerModel> peers;
  final String? selectedPeerId;
  final bool isHighContrast;

  @override
  State<_SpringCompassDial> createState() => _SpringCompassDialState();
}

class _SpringCompassDialState extends State<_SpringCompassDial> {
  late double _continuousTargetAngle;

  @override
  void initState() {
    super.initState();
    _continuousTargetAngle = widget.relativeNeedleDegrees;
  }

  @override
  void didUpdateWidget(covariant _SpringCompassDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double delta = GeoMath.shortestAngularDelta(
      _continuousTargetAngle,
      widget.relativeNeedleDegrees,
    );
    _continuousTargetAngle += delta;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _continuousTargetAngle),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (BuildContext context, double animatedNeedle, Widget? child) {
        return RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey<String>('compass-homing-dial'),
            painter: CompassDialPainter(
              deviceHeadingDegrees: widget.deviceHeadingDegrees,
              targetNeedleDegrees: GeoMath.normalizeDegrees(animatedNeedle),
              isAlignedWithTarget: widget.isAlignedWithTarget,
              userLatitude: widget.userLatitude,
              userLongitude: widget.userLongitude,
              peers: widget.peers,
              selectedPeerId: widget.selectedPeerId,
              isHighContrast: widget.isHighContrast,
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
