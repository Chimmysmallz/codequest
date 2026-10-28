/// A single ranked row on the public leaderboard.
///
/// Sourced from the **public** `leaderboard/{uid}` collection — never from the
/// private `users/{uid}` docs — so ranking never exposes private fields.
///
/// Level math mirrors `PlayerProgress`: `level = 1 + xp ~/ 250`.
class LeaderboardEntry {
  /// Same as the Firestore document id (the player's Firebase uid).
  final String uid;
  final String displayName;
  final int xp;
  final int level;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.xp,
    required this.level,
  });

  /// XP required to advance one level (mirrors `PlayerProgress.xpPerLevel`).
  static const int _xpPerLevel = 250;

  /// Builds an entry from a Firestore document, coercing missing/null fields
  /// to safe defaults: `displayName` falls back to `'Explorer'`, `xp` to `0`,
  /// and when `level` is absent it is derived from XP (`1 + xp ~/ 250`).
  factory LeaderboardEntry.fromDoc(String id, Map<String, dynamic> data) {
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final rawName = (data['displayName'] as String?)?.trim();
    final level = (data['level'] as num?)?.toInt() ?? (1 + xp ~/ _xpPerLevel);
    return LeaderboardEntry(
      uid: id,
      displayName: (rawName == null || rawName.isEmpty) ? 'Explorer' : rawName,
      xp: xp,
      level: level,
    );
  }
}
