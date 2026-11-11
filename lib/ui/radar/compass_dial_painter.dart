import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/peer_model.dart';

/// Custom 60/120 FPS canvas painter for Sampan's Material 3 Expressive
/// Compass Homing Dial (`#6755EF` Electric Violet & `#F4FF90` Acid Lime).
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
    final double radius = math.min(size.width, size.height) / 2 - 4;

    // 1. Sculptural Outer Ring & Deep Violet Dial Surface
    final Paint bezelPaint = Paint()
      ..color = isHighContrast ? Colors.black : const Color(0xFF1B1145)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bezelPaint);

    final Paint innerSurfacePaint = Paint()
      ..color = isHighContrast
          ? const Color(0xFF0B0719)
          : const Color(0xFF241759)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, innerSurfacePaint);

    // 2. Minimal Concentric Range Rings
    final Paint ringPaint = Paint()
      ..color = isHighContrast
          ? Colors.white.withAlpha(150)
          : const Color(0xFFB9AEFF).withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighContrast ? 1.6 : 1.2;

    for (final double factor in <double>[0.36, 0.68, 0.92]) {
      canvas.drawCircle(center, (radius - 10) * factor, ringPaint);
    }

    // Subtle Crosshairs
    canvas.drawLine(
      Offset(center.dx - (radius - 22), center.dy),
      Offset(center.dx + (radius - 22), center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - (radius - 22)),
      Offset(center.dx, center.dy + (radius - 22)),
      ringPaint,
    );

    // 3. Rotating Compass Rose
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-GeoMath.degToRad(deviceHeadingDegrees));

    final Paint tickPaint = Paint()
      ..color = Colors.white.withAlpha(170)
      ..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg += 15) {
      final double angleRad = GeoMath.degToRad(deg.toDouble()) - (math.pi / 2);
      final bool isCardinal = deg % 90 == 0;
      final double outerR = radius - 12;
      final double innerR = outerR - (isCardinal ? 11 : 5);
      canvas.drawLine(
        Offset(math.cos(angleRad) * innerR, math.sin(angleRad) * innerR),
        Offset(math.cos(angleRad) * outerR, math.sin(angleRad) * outerR),
        tickPaint..strokeWidth = isCardinal ? 2.4 : 1.2,
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
      final double labelR = radius - 33;
      final Offset pos = Offset(
        math.cos(angleRad) * labelR,
        math.sin(angleRad) * labelR,
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: label == 'N'
                ? SampanTheme.brandLime
                : Colors.white.withAlpha(220),
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

      final double normDist = (distMeters / 200.0).clamp(0.20, 0.76);
      final double blipR = (radius - 16) * normDist;
      final double rad = GeoMath.degToRad(relAngle) - (math.pi / 2);
      final Offset blipCenter = Offset(
        center.dx + math.cos(rad) * blipR,
        center.dy + math.sin(rad) * blipR,
      );

      final bool isSelected = peer.id == selectedPeerId;
      final Color blipColor = peer.isLeashFrozen
          ? const Color(0xFFFF5449)
          : (isSelected ? SampanTheme.brandLime : const Color(0xFFC8B9FF));

      if (isSelected) {
        canvas.drawCircle(
          blipCenter,
          14,
          Paint()..color = blipColor.withAlpha(75),
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
          ..color = const Color(0xFF1B1145)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // 5. Homing Needle pointing to Selected Companion
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(GeoMath.degToRad(targetNeedleDegrees));

    final Color needleColor = isAlignedWithTarget
        ? SampanTheme.brandLime
        : const Color(0xFFDCE868);

    final Path needlePath = Path()
      ..moveTo(0, -(radius - 38))
      ..lineTo(11, -8)
      ..lineTo(0, -18)
      ..lineTo(-11, -8)
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
      13,
      Paint()..color = SampanTheme.brandViolet,
    );
    canvas.drawCircle(
      center,
      5.5,
      Paint()..color = SampanTheme.brandLime,
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
