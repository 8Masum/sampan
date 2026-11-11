import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/radar/compass_dial_painter.dart';

/// Module 1: Minimalist Material Design 3 Expressive Compass Radar & Safety Leash.
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
    final String formattedBearing =
        (bearingDeg.round() % 360).toString().padLeft(3, '0');
    final bool isDrifted = target?.isLeashFrozen ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        // 1. Companion Pill Selector Strip
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
                    '${peer.displayName.split(' ').first}'
                    '${peer.isGuide ? ' · Guide' : ''}'
                    '${peer.isLeashFrozen ? ' ⚠️' : ''}',
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 2. M3 Expressive Hero Radar Card (Electric Violet #6755EF + Acid Lime #F4FF90)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            color: SampanTheme.brandViolet,
            borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
          ),
          child: Column(
            children: <Widget>[
              // Top Companion Pill Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        target?.avatarIcon ?? '⛵',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        target?.displayName ?? 'Companion',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isAligned
                          ? SampanTheme.brandLime
                          : Colors.white.withAlpha(32),
                      borderRadius:
                          BorderRadius.circular(SampanTheme.radiusPill),
                    ),
                    child: Text(
                      isAligned ? 'ON TARGET' : '$formattedBearing° $cardinal',
                      style: textTheme.labelSmall?.copyWith(
                        color: isAligned
                            ? SampanTheme.violet900
                            : SampanTheme.brandLime,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3D-Styled Compass Homing Dial with Spring Physics
              Center(
                child: SizedBox(
                  width: 248,
                  height: 248,
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
              const SizedBox(height: 18),

              // Expressive Pill Guidance Bar (inspired by M3 Hero Section PLAY pill)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isAligned
                      ? SampanTheme.brandLime
                      : Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      isAligned
                          ? Icons.north_rounded
                          : Icons.explore_rounded,
                      size: 20,
                      color: isAligned
                          ? SampanTheme.violet900
                          : SampanTheme.brandLime,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isAligned
                            ? 'Straight ahead · ${GeoMath.formatDistance(distanceMeters)}'
                            : 'Point toward $cardinal · ${GeoMath.formatDistance(distanceMeters)} away',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isAligned
                              ? SampanTheme.violet900
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Sculptural 2-Column Stat Cards (inspired by M3 Hero "07:30 AM" tiles)
        Row(
          children: <Widget>[
            Expanded(
              child: _SculpturalMetricCard(
                label: 'DIRECTION',
                value: '$formattedBearing°',
                subtitle: '$cardinal · Heading ${state.compassHeadingDegrees.round()}°',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SculpturalMetricCard(
                label: 'DISTANCE',
                value: GeoMath.formatDistance(distanceMeters),
                subtitle: (target?.rssiDbm ?? -60) >= -85
                    ? 'Strong signal'
                    : 'Weak signal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Minimal Compass & Safety Leash Controls
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDrifted
                ? scheme.errorContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Compass angle (${state.compassHeadingDegrees.round()}°)',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.refreshHardwareSensors,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text(
                      'Sync',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
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
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    isDrifted
                        ? Icons.warning_amber_rounded
                        : Icons.shield_outlined,
                    size: 20,
                    color: isDrifted ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDrifted
                          ? '${target?.displayName} drifted out of range'
                          : 'Safety Leash active',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDrifted
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isDrifted
                    ? 'Last spot pinned at $formattedBearing° $cardinal.'
                    : 'Alerts you if ${target?.displayName.split(' ').first ?? 'a friend'} steps too far away.',
                style: textTheme.bodySmall?.copyWith(
                  color: isDrifted
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('simulate-leash-drop-btn'),
                    onPressed:
                        controller.simulateVirtualLeashDropOnSelectedPeer,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Test Drift'),
                  ),
                  if (isDrifted)
                    FilledButton.tonalIcon(
                      key: const ValueKey<String>('restore-leash-signal-btn'),
                      onPressed: controller.restoreSelectedPeerSignal,
                      icon: const Icon(Icons.bluetooth_connected, size: 18),
                      label: const Text('Reconnect'),
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

class _SculpturalMetricCard extends StatelessWidget {
  const _SculpturalMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: scheme.onPrimaryContainer.withAlpha(190),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onPrimaryContainer,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
