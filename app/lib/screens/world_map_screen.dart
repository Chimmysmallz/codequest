import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/world.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/world_tile.dart';
import 'mission_screen.dart';

/// The world map: a list of worlds with unlock state and progress.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  void _openWorld(BuildContext context, GameState game, World world) {
    if (!game.isWorldUnlocked(world)) {
      final prev = game.previousWorld(world);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Finish ${prev?.name ?? 'the previous world'} to unlock '
            '${world.name}.',
          ),
        ),
      );
      return;
    }

    final next = game.nextMissionForWorld(world.id);
    if (next == null) {
      // World fully completed — replay the first mission.
      final all = game.missionsForWorld(world.id);
      if (all.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${world.name} complete! Replaying missions.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MissionScreen(mission: all.first),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissionScreen(mission: next),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a World'),
        actions: [
          Consumer<GameState>(
            builder: (context, game, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _StatusBadge(online: game.online)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Consumer<GameState>(
          builder: (context, game, _) {
            final worlds = game.worlds;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: worlds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final world = worlds[i];
                final unlocked = game.isWorldUnlocked(world);
                final worldMissions = game.missionsForWorld(world.id);
                final done = worldMissions
                    .where((m) => game.isMissionCompleted(m.id))
                    .length;
                final complete =
                    worldMissions.isNotEmpty && done == worldMissions.length;
                final isCurrent =
                    unlocked && !complete && _isFirstPlayable(game, world);

                final status = !unlocked
                    ? 'Locked'
                    : complete
                        ? 'Completed'
                        : '$done / ${worldMissions.length} missions';

                return WorldTile(
                  world: world,
                  status: status,
                  stars: done * 3,
                  maxStars: worldMissions.length * 3,
                  locked: !unlocked,
                  current: isCurrent,
                  onTap: () => _openWorld(context, game, world),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The "current" highlight goes on the first unlocked, incomplete world.
  bool _isFirstPlayable(GameState game, World world) {
    for (final w in game.worlds) {
      final unlocked = game.isWorldUnlocked(w);
      final complete = game.isWorldComplete(w.id);
      if (unlocked && !complete) {
        return w.id == world.id;
      }
    }
    return false;
  }
}

class _StatusBadge extends StatelessWidget {
  final bool online;
  const _StatusBadge({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.cloud_done : Icons.cloud_off,
              size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
