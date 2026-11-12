import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/home/home_tab_provider.dart';
import 'package:sampan/ui/home/sheets/spots_sheet.dart';
import 'package:sampan/ui/radar/compass_dial_painter.dart';
import 'package:sampan/ui/radar/radar_people_row.dart';

/// What the compass is pointing at: a person, a saved spot, or nothing
/// (then it behaves as a plain compass pointing north).
class _RadarTarget {
  const _RadarTarget({
    required this.emoji,
    required this.name,
    this.latitude,
    this.longitude,
    this.peer,
    this.spot,
  });

  final String emoji;
  final String name;
  final double? latitude;
  final double? longitude;
  final PeerModel? peer;
  final SpotModel? spot;

  bool get hasPosition => latitude != null && longitude != null;
}

/// Module 1: Minimalist Material Design 3 Expressive Compass Radar.
class CompassRadarTab extends ConsumerWidget {
  const CompassRadarTab({super.key});

  static _RadarTarget? _resolveTarget(SampanAppState state) {
    final SpotModel? spot = state.selectedTargetSpot;
    if (spot != null) {
      return _RadarTarget(
        emoji: spot.emoji,
        name: spot.name,
        latitude: spot.latitude,
        longitude: spot.longitude,
        spot: spot,
      );
    }
    final PeerModel? peer = state.selectedTargetPeer;
    if (peer == null) return null;
    return _RadarTarget(
      emoji: peer.avatarIcon,
      name: peer.displayName,
      latitude: peer.lastLatitude,
      longitude: peer.lastLongitude,
      peer: peer,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final _RadarTarget? target = _resolveTarget(state);
    final PeerModel? targetPeer = target?.peer;
    final double? targetLat = target?.latitude;
    final double? targetLon = target?.longitude;

    // With a measurable target the needle points at it; otherwise the dial
    // is a plain compass whose needle points to North.
    bool canMeasure = false;
    double bearingDeg = 0.0;
    double distanceMeters = 0.0;
    if (state.hasLocationFix && targetLat != null && targetLon != null) {
      canMeasure = true;
      bearingDeg = GeoMath.calculateBearingDegrees(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: targetLat,
        endLon: targetLon,
      );
      distanceMeters = GeoMath.calculateHaversineDistanceMeters(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: targetLat,
        endLon: targetLon,
      );
    }
    final bool isAligned = canMeasure &&
        GeoMath.isAlignedWithTarget(
          targetBearingDeg: bearingDeg,
          deviceHeadingDeg: state.compassHeadingDegrees,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        const RadarPeopleRow(),
        const SizedBox(height: 16),
        _HeroRadarCard(
          state: state,
          target: target,
          canMeasure: canMeasure,
          bearingDeg: bearingDeg,
          distanceMeters: distanceMeters,
          isAligned: isAligned,
        ),
        if (target != null) ...<Widget>[
          const SizedBox(height: 16),
          _MetricsRow(
            state: state,
            target: target,
            canMeasure: canMeasure,
            bearingDeg: bearingDeg,
            distanceMeters: distanceMeters,
          ),
        ],
        if (!state.isCompassCalibrated) ...<Widget>[
          const SizedBox(height: 16),
          const _HintCard(
            key: ValueKey<String>('calibrate-compass-hint'),
            icon: Icons.screen_rotation_alt_rounded,
            text: 'Compass needs a quick calibration — wave your phone in a '
                'figure 8.',
          ),
        ],
        if (targetPeer != null) ...<Widget>[
          const SizedBox(height: 16),
          _SafetyLeashCard(peer: targetPeer),
        ],
      ],
    );
  }
}

class _HeroRadarCard extends ConsumerWidget {
  const _HeroRadarCard({
    required this.state,
    required this.target,
    required this.canMeasure,
    required this.bearingDeg,
    required this.distanceMeters,
    required this.isAligned,
  });

  final SampanAppState state;
  final _RadarTarget? target;
  final bool canMeasure;
  final double bearingDeg;
  final double distanceMeters;
  final bool isAligned;

  String _guidanceText() {
    final _RadarTarget? t = target;
    if (t == null) return 'Compass · needle points North';
    if (!state.hasLocationFix) return 'Waiting for GPS — step under open sky';
    if (!t.hasPosition) {
      return 'Waiting for ${t.name.split(' ').first}’s location';
    }
    final String distance = GeoMath.formatDistance(distanceMeters);
    if (isAligned) return 'Straight ahead · $distance';
    return 'Head ${GeoMath.cardinalDirectionFromBearing(bearingDeg)} · '
        '$distance away';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _RadarTarget? t = target;
    final double relativeNeedleDeg = GeoMath.calculateRelativeNeedleAngle(
      targetBearingDeg: bearingDeg,
      deviceHeadingDeg: state.compassHeadingDegrees,
    );
    final String formattedBearing =
        (bearingDeg.round() % 360).toString().padLeft(3, '0');
    final String cardinal = GeoMath.cardinalDirectionFromBearing(bearingDeg);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: SampanTheme.brandViolet,
        borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(t?.emoji ?? '🧭', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t?.name ?? 'Your compass',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (t?.spot != null)
                IconButton(
                  key: const ValueKey<String>('clear-spot-target-btn'),
                  tooltip: 'Stop guiding',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.clearTargetSpot,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: SampanTheme.brandLime,
                    size: 20,
                  ),
                )
              else if (canMeasure)
                _Pill(
                  text: isAligned
                      ? 'ON TARGET'
                      : '$formattedBearing° $cardinal',
                  highlighted: isAligned,
                ),
            ],
          ),
          const SizedBox(height: 18),
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
                peers: state.hasLocationFix ? state.peers : const <PeerModel>[],
                selectedPeerId: t?.peer?.id,
                isHighContrast: state.isSunlightMode,
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            key: const ValueKey<String>('radar-guidance-pill'),
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                  isAligned ? Icons.north_rounded : Icons.explore_rounded,
                  size: 20,
                  color: isAligned
                      ? SampanTheme.violet900
                      : SampanTheme.brandLime,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _guidanceText(),
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isAligned ? SampanTheme.violet900 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (t == null) ...<Widget>[
            const SizedBox(height: 14),
            const _EmptyRadarActions(),
          ],
        ],
      ),
    );
  }
}

/// First-time guidance inside the hero card when there is nobody to track.
class _EmptyRadarActions extends ConsumerWidget {
  const _EmptyRadarActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Text(
          'Friends with Sampan open nearby show up here.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white.withAlpha(215),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('radar-save-spot-btn'),
                onPressed: () => showSpotEditorSheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: SampanTheme.brandLime,
                  foregroundColor: SampanTheme.violet900,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text(
                  'Save spot',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('radar-invite-btn'),
                onPressed: () {
                  ref.read(homeTabIndexProvider.notifier).state = HomeTab.hub;
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text(
                  'Invite',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.state,
    required this.target,
    required this.canMeasure,
    required this.bearingDeg,
    required this.distanceMeters,
  });

  final SampanAppState state;
  final _RadarTarget target;
  final bool canMeasure;
  final double bearingDeg;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final String cardinal = GeoMath.cardinalDirectionFromBearing(bearingDeg);
    final String formattedBearing =
        (bearingDeg.round() % 360).toString().padLeft(3, '0');
    final int facing = state.compassHeadingDegrees.round();
    final PeerModel? peer = target.peer;
    final String distanceSubtitle = !canMeasure
        ? 'Waiting for GPS'
        : (peer == null
            ? 'Saved spot'
            : (peer.rssiDbm >= -85 ? 'Strong signal' : 'Weak signal'));

    return Row(
      children: <Widget>[
        Expanded(
          child: _SculpturalMetricCard(
            label: 'DIRECTION',
            value: canMeasure ? '$formattedBearing°' : '—',
            subtitle: canMeasure ? '$cardinal · Facing $facing°' : 'Facing $facing°',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SculpturalMetricCard(
            label: 'DISTANCE',
            value: canMeasure ? GeoMath.formatDistance(distanceMeters) : '—',
            subtitle: distanceSubtitle,
          ),
        ),
      ],
    );
  }
}

class _SafetyLeashCard extends ConsumerWidget {
  const _SafetyLeashCard({required this.peer});

  final PeerModel peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String firstName = peer.displayName.split(' ').first;
    final bool isDrifted = peer.isLeashFrozen;

    return Container(
      key: const ValueKey<String>('safety-leash-card'),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color:
            isDrifted ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isDrifted ? Icons.warning_amber_rounded : Icons.shield_outlined,
            size: 22,
            color: isDrifted ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isDrifted ? '$firstName drifted away' : 'Safety Leash on',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color:
                        isDrifted ? scheme.onErrorContainer : scheme.onSurface,
                  ),
                ),
                Text(
                  isDrifted
                      ? 'Their last spot is pinned on the compass.'
                      : 'Alerts you if $firstName goes out of range.',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDrifted
                        ? scheme.onErrorContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isDrifted)
            TextButton(
              key: const ValueKey<String>('acknowledge-leash-btn'),
              onPressed: ref
                  .read(sampanControllerProvider.notifier)
                  .acknowledgeLeashAlert,
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? SampanTheme.brandLime : Colors.white.withAlpha(32),
        borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  highlighted ? SampanTheme.violet900 : SampanTheme.brandLime,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
      ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.onPrimaryContainer,
                letterSpacing: -0.8,
              ),
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
