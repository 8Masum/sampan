import 'dart:math' as math;

import 'package:sampan/core/constants/protocol_constants.dart';

/// Immutable evaluation result for the Virtual Leash safety monitor
/// (Section 4, Module 1).
class VirtualLeashEvaluation {
  const VirtualLeashEvaluation({
    required this.isWeakSignal,
    required this.isTripped,
    required this.weakDurationSeconds,
    required this.weakSignalSince,
  });

  final bool isWeakSignal;
  final bool isTripped;
  final int weakDurationSeconds;
  final DateTime? weakSignalSince;
}

/// Geodesic, compass bearing, and virtual leash math engine for Sampan.
class GeoMath {
  const GeoMath._();

  static double degToRad(double degrees) => degrees * (math.pi / 180.0);
  static double radToDeg(double radians) => radians * (180.0 / math.pi);

  /// Normalizes any angle in degrees to `[0.0, 360.0)`.
  static double normalizeDegrees(double degrees) {
    if (degrees.isNaN || degrees.isInfinite) return 0.0;
    final double mod = degrees % 360.0;
    return mod < 0 ? mod + 360.0 : mod;
  }

  /// Calculates forward azimuth / bearing (β) in degrees `[0.0, 360.0)`
  /// from `(startLat, startLon)` to `(endLat, endLon)` using the formula
  /// specified in Section 4, Module 1:
  ///
  /// Δλ = lon2 - lon1
  /// y = sin(Δλ) * cos(lat2)
  /// x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(Δλ)
  /// β = atan2(y, x) mod 360°
  static double calculateBearingDegrees({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    if (startLat == endLat && startLon == endLon) {
      return 0.0;
    }
    final double lat1 = degToRad(startLat);
    final double lat2 = degToRad(endLat);
    final double deltaLambda = degToRad(endLon - startLon);

    final double y = math.sin(deltaLambda) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLambda);

    final double theta = math.atan2(y, x);
    return normalizeDegrees(radToDeg(theta));
  }

  /// Calculates relative compass needle angle: `(β - α) mod 360°`,
  /// where `β` is the target's true bearing and `α` is the device's
  /// magnetometer heading.
  static double calculateRelativeNeedleAngle({
    required double targetBearingDeg,
    required double deviceHeadingDeg,
  }) {
    return normalizeDegrees(targetBearingDeg - deviceHeadingDeg);
  }

  /// Returns the signed shortest angular difference in `[-180.0, 180.0]`
  /// between two angles in degrees.
  static double shortestAngularDelta(double fromDeg, double toDeg) {
    final double diff = normalizeDegrees(toDeg - fromDeg);
    return diff > 180.0 ? diff - 360.0 : diff;
  }

  /// Returns `true` when the device's heading points within `±toleranceDeg`
  /// (default `±10°`) of the target bearing (Section 2.2 Haptic Chimes).
  static bool isAlignedWithTarget({
    required double targetBearingDeg,
    required double deviceHeadingDeg,
    double toleranceDeg = SampanConstants.compassAlignmentToleranceDegrees,
  }) {
    final double delta =
        shortestAngularDelta(deviceHeadingDeg, targetBearingDeg).abs();
    return delta <= toleranceDeg;
  }

  /// Great-circle distance in meters calculated via the Haversine formula
  /// (Section 4, Module 1).
  static double calculateHaversineDistanceMeters({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    if (startLat == endLat && startLon == endLon) {
      return 0.0;
    }
    final double dLat = degToRad(endLat - startLat);
    final double dLon = degToRad(endLon - startLon);
    final double lat1 = degToRad(startLat);
    final double lat2 = degToRad(endLat);

    final double sinHalfLat = math.sin(dLat / 2.0);
    final double sinHalfLon = math.sin(dLon / 2.0);

    final double a = (sinHalfLat * sinHalfLat) +
        math.cos(lat1) * math.cos(lat2) * (sinHalfLon * sinHalfLon);
    final double clampedA = a.clamp(0.0, 1.0);
    final double c =
        2.0 * math.atan2(math.sqrt(clampedA), math.sqrt(1.0 - clampedA));
    return SampanConstants.earthRadiusMeters * c;
  }

  /// Maps a bearing `[0, 360)` to an 8-wind cardinal compass label.
  static String cardinalDirectionFromBearing(double bearingDeg) {
    const List<String> directions = <String>[
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW',
    ];
    final double normalized = normalizeDegrees(bearingDeg);
    final int index = ((normalized + 22.5) / 45.0).floor() % 8;
    return directions[index];
  }

  /// Hemisphere-aware coordinate label usable anywhere on Earth
  /// (e.g. `23.8103°N, 90.4125°E` or `33.8688°S, 151.2093°E`).
  static String formatCoordinates(
    double latitude,
    double longitude, {
    int fractionDigits = 4,
  }) {
    final String latHemisphere = latitude < 0 ? 'S' : 'N';
    final String lonHemisphere = longitude < 0 ? 'W' : 'E';
    final String lat = latitude.abs().toStringAsFixed(fractionDigits);
    final String lon = longitude.abs().toStringAsFixed(fractionDigits);
    return '$lat°$latHemisphere, $lon°$lonHemisphere';
  }

  /// Human-readable distance formatting (`85m`, `1.2km`).
  static String formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) {
      return '0m';
    }
    if (meters < 1000.0) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000.0).toStringAsFixed(1)}km';
  }

  /// Evaluates the "Virtual Leash" condition (Section 4, Module 1):
  /// If companion beacon RSSI drops below `-85 dBm` for `> 45` continuous
  /// seconds, fires the leash alarm and freezes last-known coordinates.
  static VirtualLeashEvaluation evaluateVirtualLeash({
    required int currentRssiDbm,
    required DateTime? weakSignalSince,
    required DateTime now,
    int thresholdDbm = SampanConstants.virtualLeashRssiThresholdDbm,
    int timeoutSeconds = SampanConstants.virtualLeashTimeoutSeconds,
  }) {
    if (currentRssiDbm >= thresholdDbm) {
      return const VirtualLeashEvaluation(
        isWeakSignal: false,
        isTripped: false,
        weakDurationSeconds: 0,
        weakSignalSince: null,
      );
    }

    final DateTime start = weakSignalSince ?? now;
    final int elapsedSeconds =
        math.max(0, now.difference(start).inSeconds);
    final bool tripped = elapsedSeconds > timeoutSeconds;

    return VirtualLeashEvaluation(
      isWeakSignal: true,
      isTripped: tripped,
      weakDurationSeconds: elapsedSeconds,
      weakSignalSince: start,
    );
  }
}
