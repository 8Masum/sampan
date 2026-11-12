import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/core/math/geo_math.dart';

void main() {
  group('GeoMath — Bearing, Compass Needle, Haversine & Virtual Leash', () {
    test('calculateBearingDegrees returns accurate cardinal bearings', () {
      // Due North
      expect(
        GeoMath.calculateBearingDegrees(
          startLat: 21.0,
          startLon: 91.0,
          endLat: 22.0,
          endLon: 91.0,
        ),
        closeTo(0.0, 0.01),
      );

      // Due East
      expect(
        GeoMath.calculateBearingDegrees(
          startLat: 0.0,
          startLon: 90.0,
          endLat: 0.0,
          endLon: 91.0,
        ),
        closeTo(90.0, 0.01),
      );

      // Due South
      expect(
        GeoMath.calculateBearingDegrees(
          startLat: 22.0,
          startLon: 91.0,
          endLat: 21.0,
          endLon: 91.0,
        ),
        closeTo(180.0, 0.01),
      );

      // Identical coordinates return 0.0 without NaN
      expect(
        GeoMath.calculateBearingDegrees(
          startLat: 21.4272,
          startLon: 91.9702,
          endLat: 21.4272,
          endLon: 91.9702,
        ),
        equals(0.0),
      );
    });

    test('calculateRelativeNeedleAngle normalizes (beta - alpha) mod 360', () {
      expect(
        GeoMath.calculateRelativeNeedleAngle(
          targetBearingDeg: 45.0,
          deviceHeadingDeg: 15.0,
        ),
        closeTo(30.0, 0.001),
      );

      // Wrap-around when device heading > target bearing
      expect(
        GeoMath.calculateRelativeNeedleAngle(
          targetBearingDeg: 10.0,
          deviceHeadingDeg: 350.0,
        ),
        closeTo(20.0, 0.001),
      );
    });

    test('isAlignedWithTarget checks +/-10 degree haptic tolerance across 0/360', () {
      expect(
        GeoMath.isAlignedWithTarget(
          targetBearingDeg: 45.0,
          deviceHeadingDeg: 35.0,
        ),
        isTrue,
      );
      expect(
        GeoMath.isAlignedWithTarget(
          targetBearingDeg: 45.0,
          deviceHeadingDeg: 34.5,
        ),
        isFalse,
      );
      // Wrap-around across 360/0 degrees
      expect(
        GeoMath.isAlignedWithTarget(
          targetBearingDeg: 356.0,
          deviceHeadingDeg: 3.0,
        ),
        isTrue,
      );
    });

    test('calculateHaversineDistanceMeters computes Laboni to Sugandha distance', () {
      final double meters = GeoMath.calculateHaversineDistanceMeters(
        startLat: 21.4272,
        startLon: 91.9702,
        endLat: 21.4195,
        endLon: 91.9756,
      );
      expect(meters, inInclusiveRange(950.0, 1100.0));
      expect(GeoMath.formatDistance(85.2), equals('85m'));
      expect(GeoMath.formatDistance(1420.0), equals('1.4km'));
    });

    test('evaluateVirtualLeash trips only when RSSI < -85 dBm for > 45s', () {
      final DateTime t0 = DateTime.utc(2026, 11, 11, 12, 0, 0);

      // Healthy signal (-85 dBm is at threshold, not below)
      final VirtualLeashEvaluation healthy = GeoMath.evaluateVirtualLeash(
        currentRssiDbm: -85,
        weakSignalSince: null,
        now: t0,
      );
      expect(healthy.isWeakSignal, isFalse);
      expect(healthy.isTripped, isFalse);

      // Drops to -88 dBm at t0
      final VirtualLeashEvaluation weakStart = GeoMath.evaluateVirtualLeash(
        currentRssiDbm: -88,
        weakSignalSince: null,
        now: t0,
      );
      expect(weakStart.isWeakSignal, isTrue);
      expect(weakStart.isTripped, isFalse);
      expect(weakStart.weakSignalSince, equals(t0));

      // Still at -88 dBm at exactly +45s (not > 45s yet)
      final VirtualLeashEvaluation at45s = GeoMath.evaluateVirtualLeash(
        currentRssiDbm: -88,
        weakSignalSince: weakStart.weakSignalSince,
        now: t0.add(const Duration(seconds: 45)),
      );
      expect(at45s.isWeakSignal, isTrue);
      expect(at45s.isTripped, isFalse);

      // Still at -88 dBm at +46s (> 45s -> TRIPPED!)
      final VirtualLeashEvaluation at46s = GeoMath.evaluateVirtualLeash(
        currentRssiDbm: -88,
        weakSignalSince: weakStart.weakSignalSince,
        now: t0.add(const Duration(seconds: 46)),
      );
      expect(at46s.isWeakSignal, isTrue);
      expect(at46s.isTripped, isTrue);
      expect(at46s.weakDurationSeconds, equals(46));
    });
    test('formatCoordinates labels every hemisphere correctly', () {
      expect(
        GeoMath.formatCoordinates(23.81036, 90.41252),
        equals('23.8104°N, 90.4125°E'),
      );
      expect(
        GeoMath.formatCoordinates(-33.8688, 151.2093),
        equals('33.8688°S, 151.2093°E'),
      );
      expect(
        GeoMath.formatCoordinates(40.7128, -74.006),
        equals('40.7128°N, 74.0060°W'),
      );
      expect(
        GeoMath.formatCoordinates(-22.9068, -43.1729, fractionDigits: 2),
        equals('22.91°S, 43.17°W'),
      );
    });
  });
}
