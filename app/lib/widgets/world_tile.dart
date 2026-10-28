import 'package:flutter/material.dart';

import '../models/world.dart';
import '../theme/app_theme.dart';

/// A row in the world map: art icon, name, status text, and stars or a lock.
///
/// When [current] is true (the next world to play) the tile is highlighted
/// with a gold border.
class WorldTile extends StatelessWidget {
  final World world;

  /// Short status line, e.g. "3 / 3 missions", "Locked", "In progress".
  final String status;

  /// Total stars earned across the world's missions.
  final int stars;

  /// Maximum stars available (missions * 3), used to render the row of stars.
  final int maxStars;

  final bool locked;
  final bool current;
  final VoidCallback? onTap;

  const WorldTile({
    super.key,
    required this.world,
    required this.status,
    this.stars = 0,
    this.maxStars = 0,
    this.locked = false,
    this.current = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.65 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: current ? AppColors.gold : AppColors.panel2,
                width: current ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image(
                    image: AssetImage(world.assetPath),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        world.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!locked && maxStars > 0) ...[
                        const SizedBox(height: 6),
                        _Stars(earned: stars, max: maxStars),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (locked)
                  const Icon(Icons.lock, color: AppColors.muted, size: 26)
                else if (current)
                  const Icon(Icons.play_circle_fill,
                      color: AppColors.gold, size: 30)
                else
                  const Icon(Icons.chevron_right,
                      color: AppColors.muted, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int earned;
  final int max;
  const _Stars({required this.earned, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: AppColors.gold, size: 16),
        const SizedBox(width: 4),
        Text(
          '$earned / $max',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
