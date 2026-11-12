import 'package:flutter/material.dart';
import 'package:sampan/core/constants/protocol_constants.dart';

/// The official Sampan logo, shown whole (never cropped) as a rounded tile
/// that matches the app's soft Material 3 Expressive corners.
class SampanLogo extends StatelessWidget {
  const SampanLogo({
    super.key,
    required this.size,
    this.cornerRadiusFactor = 0.26,
  });

  final double size;

  /// Corner radius as a fraction of [size] (0.26 ≈ app-icon squircle).
  final double cornerRadiusFactor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * cornerRadiusFactor),
      child: Image.asset(
        SampanConstants.logoAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text('⛵', style: TextStyle(fontSize: size * 0.5)),
            ),
          );
        },
      ),
    );
  }
}
