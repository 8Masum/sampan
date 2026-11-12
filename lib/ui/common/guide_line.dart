import 'package:flutter/material.dart';
import 'package:sampan/core/theme/sampan_theme.dart';

/// One-line tip with an icon — the building block of Sampan's minimal,
/// in-context guides (empty states, first-time hints).
class GuideLine extends StatelessWidget {
  const GuideLine({
    super.key,
    required this.icon,
    required this.text,
    this.foreground = SampanTheme.violet900,
  });

  final IconData icon;
  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
