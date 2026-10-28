import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leaderboard_entry.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Public leaderboard: the top players ranked by XP.
///
/// Reads the public `leaderboard` collection (via [GameState.loadLeaderboard]),
/// highlights the signed-in player's own row, and lets them edit their public
/// display name. Guests see a friendly prompt to sign in.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const int _limit = 50;

  bool _loading = true;
  List<LeaderboardEntry> _entries = const <LeaderboardEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Initial load with the full-screen spinner.
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final entries = await context.read<GameState>().loadLeaderboard(
          limit: _limit,
        );
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  /// Pull-to-refresh reload (keeps the current list visible while fetching).
  Future<void> _refresh() async {
    final entries = await context.read<GameState>().loadLeaderboard(
          limit: _limit,
        );
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const LoginScreen(),
      ),
    );
    // On success the login screen pops back toward Home, so this screen may be
    // gone; the guard keeps us safe if it is still mounted.
    if (!mounted) return;
    await _load();
  }

  Future<void> _editName() async {
    final game = context.read<GameState>();
    final controller = TextEditingController(text: game.progress.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          'Edit display name',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppColors.gold,
          decoration: const InputDecoration(
            hintText: 'Your public handle',
            hintStyle: TextStyle(color: AppColors.muted),
            counterStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // dialog dismissed / cancelled
    await game.setDisplayName(result);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Display name updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final signedIn = game.isLoggedIn;
    final myUid = game.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Edit name',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editName,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(signedIn, myUid),
      ),
    );
  }

  Widget _buildBody(bool signedIn, String? myUid) {
    if (!signedIn) {
      return _SignInPrompt(onSignIn: _openLogin);
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.gold),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.panel,
      onRefresh: _refresh,
      child: _entries.isEmpty
          ? const _EmptyBoard()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = _entries[i];
                return _LeaderboardRow(
                  rank: i + 1,
                  entry: entry,
                  isMe: myUid != null && entry.uid == myUid,
                );
              },
            ),
    );
  }
}

/// Shown to guests: an invitation to sign in and join the board.
class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 72, color: AppColors.gold.withOpacity(0.85)),
            const SizedBox(height: 20),
            const Text(
              'Sign in to join the leaderboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Compete with other coders and climb the ranks by earning XP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 26),
            PrimaryButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onPressed: onSignIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when signed in but the board has no rows yet. Scrollable so
/// pull-to-refresh still works.
class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.emoji_events_outlined,
          size: 64,
          color: AppColors.muted.withOpacity(0.6),
        ),
        const SizedBox(height: 16),
        const Text(
          'No players ranked yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete missions to earn XP and claim the top spot!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }
}

/// A single ranked row: rank badge, display name (+ "You" tag), level badge,
/// and XP. The signed-in player's own row is highlighted.
class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final topThree = rank <= 3;
    final borderColor = isMe
        ? AppColors.gold
        : (topThree ? AppColors.gold.withOpacity(0.5) : AppColors.panel2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.panel2 : AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isMe ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: _RankBadge(rank: rank))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _LevelBadge(level: entry.level),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gold/silver/bronze medals for the top 3, otherwise the numeric rank.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    const medals = <int, String>{1: '🥇', 2: '🥈', 3: '🥉'};
    final medal = medals[rank];
    if (medal != null) {
      return Text(medal, style: const TextStyle(fontSize: 24));
    }
    return Text(
      '$rank',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// A small pill showing the player's level.
class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brand.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield, size: 12, color: AppColors.brand2),
          const SizedBox(width: 4),
          Text(
            'Level $level',
            style: const TextStyle(
              color: AppColors.brand2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
