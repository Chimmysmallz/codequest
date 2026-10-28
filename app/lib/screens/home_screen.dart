import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/xp_bar.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'world_map_screen.dart';

/// The player's home base: profile card + primary navigation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  /// Account + settings sheet. Shows the signed-in email and a Sign Out action,
  /// or a Sign In prompt for guests.
  Future<void> _openSettings(BuildContext context, GameState game) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final loggedIn = game.isLoggedIn;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      loggedIn ? Icons.verified_user : Icons.person_outline,
                      color: loggedIn ? AppColors.green : AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loggedIn
                            ? (game.user?.email ?? 'Signed in')
                            : "You're playing as a guest. Sign in to save "
                                'your progress.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (loggedIn)
                  PrimaryButton(
                    label: 'Sign Out',
                    ghost: true,
                    icon: Icons.logout,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await game.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Signed out. Your progress is saved on this '
                              'device.',
                            ),
                          ),
                        );
                      }
                    },
                  )
                else
                  PrimaryButton(
                    label: 'Sign In',
                    icon: Icons.login_rounded,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openLogin(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmNewGame(BuildContext context, GameState game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a New Game?'),
        content: const Text(
          'This will erase your XP, coins and completed missions. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset',
                style: TextStyle(color: AppColors.pink)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await game.resetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New game started. Good luck!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, game, _) {
            final p = game.progress;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back, Coder!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            if (game.isLoggedIn && game.user != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Signed in as ${game.user!.email}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _OnlineDot(online: game.online),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!game.isLoggedIn) ...[
                    _SignInBanner(onTap: () => _openLogin(context)),
                    const SizedBox(height: 16),
                  ],
                  _PlayerCard(
                    level: p.level,
                    xpIntoLevel: p.xpIntoLevel,
                    coins: p.coins,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Continue',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/world-map'),
                          builder: (_) => const WorldMapScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'New Game',
                    ghost: true,
                    icon: Icons.restart_alt,
                    onPressed: () => _confirmNewGame(context, game),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Leaderboard',
                          ghost: true,
                          icon: Icons.emoji_events,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: '/leaderboard',
                                ),
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Settings',
                          ghost: true,
                          icon: Icons.settings,
                          onPressed: () => _openSettings(context, game),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final int level;
  final int xpIntoLevel;
  final int coins;

  const _PlayerCard({
    required this.level,
    required this.xpIntoLevel,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.panel2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.brand, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Image(
              image: AssetImage('assets/art/art-avatar.png'),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.monetization_on,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                XpBar(
                  progress: xpIntoLevel / 250.0,
                  label: '$xpIntoLevel / 250 XP',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  final bool online;
  const _OnlineDot({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A prominent, tappable call-to-action shown to guests inviting them to sign
/// in so their progress is saved to the backend.
class _SignInBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SignInBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brand.withOpacity(0.35),
                AppColors.brand2.withOpacity(0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.brand),
          ),
          child: Row(
            children: const [
              Icon(Icons.cloud_upload_outlined,
                  color: AppColors.gold, size: 26),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in to save your progress',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sync your XP and missions across devices',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
