import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A rounded XP progress track with a green -> cyan fill and an optional label.
class XpBar extends StatelessWidget {
  /// Fraction filled, 0..1.
  final double progress;

  /// Optional label shown above the bar (e.g. "120 / 250 XP").
  final String? label;

  final double height;

  const XpBar({
    super.key,
    required this.progress,
    this.label,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  height: height,
                  width: width,
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
                Container(
                  height: height,
                  width: width * clamped,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.green, AppColors.brand2],
                    ),
                    borderRadius: BorderRadius.circular(height),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
