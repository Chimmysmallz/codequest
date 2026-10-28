import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small pill showing a single reward: XP, coins, or a named unlock (hat).
class RewardChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? assetPath;
  final Color color;

  const RewardChip({
    super.key,
    required this.label,
    this.icon,
    this.assetPath,
    this.color = AppColors.gold,
  });

  /// Convenience constructor for an XP reward.
  const RewardChip.xp(int xp, {super.key})
      : label = '+$xp XP',
        icon = Icons.bolt,
        assetPath = null,
        color = AppColors.green;

  /// Convenience constructor for a coins reward.
  const RewardChip.coins(int coins, {super.key})
      : label = '+$coins',
        icon = Icons.monetization_on,
        assetPath = null,
        color = AppColors.gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image(
                image: AssetImage(assetPath!),
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 18, color: color),
            ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
