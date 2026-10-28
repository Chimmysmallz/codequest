import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mission.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/reward_chip.dart';
import 'mission_screen.dart';

/// Celebration screen shown after a mission is passed.
class ResultScreen extends StatelessWidget {
  final Mission mission;
  final SubmitResult result;

  const ResultScreen({
    super.key,
    required this.mission,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final nextMission = game.nextMissionForWorld(mission.worldId);
    final stars = result.stars == 0 ? 3 : result.stars;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [AppColors.panel2, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StarRow(stars: stars),
                const SizedBox(height: 18),
                const Text(
                  'Mission Complete!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mission.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Image(
                      image: AssetImage('assets/art/art-robot.png'),
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _UnlockCard(reward: mission.reward),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RewardChip.xp(mission.xp),
                    const SizedBox(width: 12),
                    RewardChip.coins(mission.coins),
                  ],
                ),
                if (result.message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  label: nextMission != null ? 'Next Mission' : 'Back to Map',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (nextMission != null) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MissionScreen(mission: nextMission),
                        ),
                      );
                    } else {
                      // No more missions in this world — return to the map.
                      Navigator.of(context).popUntil((route) {
                        return route.settings.name == '/world-map' ||
                            route.isFirst;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Home',
                  ghost: true,
                  icon: Icons.home_rounded,
                  onPressed: () {
                    // Pop back to the Home screen (named '/home'); fall back to
                    // the first route if it can't be found.
                    Navigator.of(context).popUntil(
                      (route) =>
                          route.settings.name == '/home' || route.isFirst,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.star_rounded,
              size: i == 1 ? 68 : 56,
              color: i < stars ? AppColors.gold : AppColors.panel2,
            ),
          ),
      ],
    );
  }
}

class _UnlockCard extends StatelessWidget {
  final String reward;
  const _UnlockCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pink.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Image(
              image: AssetImage('assets/art/art-hat.png'),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Reward Unlocked!',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
