import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

/// Title screen: glowing robot, wordmark, tagline and a PRESS START button.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: [AppColors.panel2, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Glowing robot hero.
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.5),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Image(
                    image: AssetImage('assets/art/art-robot.png'),
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // Wordmark: "Code" in ink, "Quest" in gold.
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    children: [
                      TextSpan(
                        text: 'Code',
                        style: TextStyle(color: AppColors.ink),
                      ),
                      TextSpan(
                        text: 'Quest',
                        style: TextStyle(color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Learn to code. Save the galaxy.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Consumer<GameState>(
                  builder: (context, game, _) {
                    if (game.loading) {
                      return Column(
                        children: const [
                          SizedBox(
                            height: 34,
                            width: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.gold,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Warming up the engines...',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      );
                    }
                    return PrimaryButton(
                      label: 'PRESS START',
                      icon: Icons.rocket_launch,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/home'),
                            builder: (_) => const HomeScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
