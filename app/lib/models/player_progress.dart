/// Persistent player state: identity, currency, XP and completed missions.
///
/// Level math (mirrors the backend rules):
///   XP_PER_LEVEL = 250
///   level        = 1 + xp ~/ 250
///   xpIntoLevel  = xp % 250
///   xpToNext     = 250 - xpIntoLevel
class PlayerProgress {
  static const int xpPerLevel = 250;

  final String? userId;
  final int xp;
  final int coins;
  final Set<String> completed;

  /// The player's public handle, shown on the leaderboard. Empty until it is
  /// defaulted on sign-in (from the email's local part) or set by the player.
  final String displayName;

  const PlayerProgress({
    this.userId,
    this.xp = 0,
    this.coins = 0,
    this.completed = const <String>{},
    this.displayName = '',
  });

  int get level => 1 + xp ~/ xpPerLevel;
  int get xpIntoLevel => xp % xpPerLevel;
  int get xpToNext => xpPerLevel - xpIntoLevel;

  /// 0..1 progress toward the next level (handy for the XP bar).
  double get levelProgress => xpIntoLevel / xpPerLevel;

  bool isCompleted(String missionId) => completed.contains(missionId);

  PlayerProgress copyWith({
    String? userId,
    int? xp,
    int? coins,
    Set<String>? completed,
    String? displayName,
  }) {
    return PlayerProgress(
      userId: userId ?? this.userId,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      completed: completed ?? this.completed,
      displayName: displayName ?? this.displayName,
    );
  }

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['completed'];
    return PlayerProgress(
      userId: json['userId'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      completed: rawCompleted is List
          ? rawCompleted.map((e) => e.toString()).toSet()
          : <String>{},
      displayName: (json['displayName'] as String?) ?? '',
    );
  }

  /// Server progress shape includes derived fields for convenience.
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'xp': xp,
        'coins': coins,
        'level': level,
        'completed': completed.toList(),
        'displayName': displayName,
      };
}
