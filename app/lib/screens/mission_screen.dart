import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mission.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/reward_chip.dart';
import 'code_challenge_screen.dart';

/// Mission briefing: hero art, title, description and the rewards on offer.
class MissionScreen extends StatelessWidget {
  final Mission mission;
  const MissionScreen({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final world = game.worldById(mission.worldId);
    final worldName = world?.name ?? mission.worldId;
    final completed = game.isMissionCompleted(mission.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mission ${mission.index}'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.brand.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Image(
                    image: AssetImage('assets/art/art-robot.png'),
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mission ${mission.index} · $worldName',
                style: const TextStyle(
                  color: AppColors.brand2,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mission.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (completed)
                    const Icon(Icons.check_circle,
                        color: AppColors.green, size: 28),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.panel2),
                ),
                child: Text(
                  mission.description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Rewards',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  RewardChip.xp(mission.xp),
                  RewardChip.coins(mission.coins),
                  RewardChip(
                    label: mission.reward,
                    assetPath: 'assets/art/art-hat.png',
                    color: AppColors.pink,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: completed ? 'Replay Mission' : 'Start Mission',
                icon: Icons.videogame_asset,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CodeChallengeScreen(mission: mission),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
