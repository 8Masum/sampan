import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/data/models/peer_model.dart';

/// Custom 60/120 FPS canvas painter for Sampan's 3D-styled Compass Homing Dial
/// (Section 2.2 & Section 4, Module 1 of `SAMPAN_BLUEPRINT.md`).
class CompassDialPainter extends CustomPainter {
  CompassDialPainter({
    required this.deviceHeadingDegrees,
    required this.targetNeedleDegrees,
    required this.isAlignedWithTarget,
    required this.userLatitude,
    required this.userLongitude,
    required this.peers,
    required this.selectedPeerId,
    required this.isHighContrast,
  });

  final double deviceHeadingDegrees;
  final double targetNeedleDegrees;
  final bool isAlignedWithTarget;
  final double userLatitude;
  final double userLongitude;
  final List<PeerModel> peers;
  final String? selectedPeerId;
  final bool isHighContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 8;

    // 1. 3D Outer Bezel & Maritime Dial Surface
    final Paint bezelPaint = Paint()
      ..color = isHighContrast
          ? Colors.black
          : const Color(0xFF002D34)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bezelPaint);

    final Paint innerSurfacePaint = Paint()
      ..color = isHighContrast
          ? const Color(0xFF0A1417)
          : const Color(0xFF003B46)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, innerSurfacePaint);

    // 2. Concentric Radar Range Rings (35%, 65%, 92% radius)
    final Paint ringPaint = Paint()
      ..color = isHighContrast
          ? Colors.white.withAlpha(160)
          : const Color(0xFFA1EFFF).withAlpha(65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighContrast ? 1.8 : 1.2;

    for (final double factor in <double>[0.33, 0.63, 0.90]) {
      canvas.drawCircle(center, (radius - 10) * factor, ringPaint);
    }

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - (radius - 18), center.dy),
      Offset(center.dx + (radius - 18), center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - (radius - 18)),
      Offset(center.dx, center.dy + (radius - 18)),
      ringPaint,
    );

    // 3. Rotating Compass Rose (rotates opposite to deviceHeadingDegrees)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-GeoMath.degToRad(deviceHeadingDegrees));

    final Paint tickPaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 1.5;

    for (int deg = 0; deg < 360; deg += 15) {
      final double angleRad = GeoMath.degToRad(deg.toDouble()) - (math.pi / 2);
      final bool isCardinal = deg % 90 == 0;
      final double outerR = radius - 12;
      final double innerR = outerR - (isCardinal ? 12 : 6);
      canvas.drawLine(
        Offset(math.cos(angleRad) * innerR, math.sin(angleRad) * innerR),
        Offset(math.cos(angleRad) * outerR, math.sin(angleRad) * outerR),
        tickPaint..strokeWidth = isCardinal ? 2.5 : 1.2,
      );
    }

    // Cardinal Labels (N, E, S, W)
    const Map<String, double> cardinals = <String, double>{
      'N': -math.pi / 2,
      'E': 0.0,
      'S': math.pi / 2,
      'W': math.pi,
    };
    cardinals.forEach((String label, double angleRad) {
      final double labelR = radius - 34;
      final Offset pos = Offset(
        math.cos(angleRad) * labelR,
        math.sin(angleRad) * labelR,
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: label == 'N'
                ? const Color(0xFFF4A261)
                : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });
    canvas.restore();

    // 4. Plot Companion Blips on the Radar
    for (final PeerModel peer in peers) {
      if (peer.lastLatitude == null || peer.lastLongitude == null) continue;
      final double bearing = GeoMath.calculateBearingDegrees(
        startLat: userLatitude,
        startLon: userLongitude,
        endLat: peer.lastLatitude!,
        endLon: peer.lastLongitude!,
      );
      final double relAngle = GeoMath.calculateRelativeNeedleAngle(
        targetBearingDeg: bearing,
        deviceHeadingDeg: deviceHeadingDegrees,
      );
      final double distMeters = GeoMath.calculateHaversineDistanceMeters(
        startLat: userLatitude,
        startLon: userLongitude,
        endLat: peer.lastLatitude!,
        endLon: peer.lastLongitude!,
      );

      // Normalize distance onto radar radius (0..200m mapped to 22%..78% radius)
      final double normDist = (distMeters / 200.0).clamp(0.18, 0.78);
      final double blipR = (radius - 16) * normDist;
      final double rad = GeoMath.degToRad(relAngle) - (math.pi / 2);
      final Offset blipCenter = Offset(
        center.dx + math.cos(rad) * blipR,
        center.dy + math.sin(rad) * blipR,
      );

      final bool isSelected = peer.id == selectedPeerId;
      final Color blipColor = peer.isLeashFrozen
          ? const Color(0xFFFF5449)
          : (peer.isGuide
              ? const Color(0xFFF4A261)
              : const Color(0xFF2A9D8F));

      if (isSelected) {
        canvas.drawCircle(
          blipCenter,
          13,
          Paint()..color = blipColor.withAlpha(85),
        );
      }
      canvas.drawCircle(
        blipCenter,
        isSelected ? 7.5 : 5.5,
        Paint()..color = blipColor,
      );
      canvas.drawCircle(
        blipCenter,
        isSelected ? 7.5 : 5.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // 5. Homing Needle pointing to Selected Companion (Relative Needle Angle)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(GeoMath.degToRad(targetNeedleDegrees));

    final Color needleColor = isAlignedWithTarget
        ? const Color(0xFF2A9D8F)
        : const Color(0xFFF4A261);

    final Path needlePath = Path()
      ..moveTo(0, -(radius - 38))
      ..lineTo(10, -8)
      ..lineTo(0, -18)
      ..lineTo(-10, -8)
      ..close();

    canvas.drawPath(
      needlePath,
      Paint()
        ..color = needleColor
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    // 6. Center Hub Cap
    canvas.drawCircle(
      center,
      12,
      Paint()..color = const Color(0xFFA1EFFF),
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = const Color(0xFF002D34),
    );
  }

  @override
  bool shouldRepaint(covariant CompassDialPainter oldDelegate) {
    return oldDelegate.deviceHeadingDegrees != deviceHeadingDegrees ||
        oldDelegate.targetNeedleDegrees != targetNeedleDegrees ||
        oldDelegate.isAlignedWithTarget != isAlignedWithTarget ||
        oldDelegate.selectedPeerId != selectedPeerId ||
        oldDelegate.peers != peers ||
        oldDelegate.isHighContrast != isHighContrast;
  }
}
