import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

/// Per-user progress storage in Cloud Firestore.
///
/// Each player's progress lives at `users/{uid}` as a single document:
/// `{email, displayName, xp, coins, completed, updatedAt}`.
///
/// A **separate public** `leaderboard/{uid}` collection holds only the fields
/// safe to expose for ranking (`{displayName, xp, level, updatedAt}`), so the
/// private `users/{uid}` docs are never read by other players.
///
/// Firestore's offline persistence is enabled by default on mobile, so reads
/// and writes keep working without a connection and reconcile automatically
/// once the device is back online — no extra configuration needed here.
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _db.collection('leaderboard');

  /// Reads the user's progress document, or null if it doesn't exist yet.
  Future<Map<String, dynamic>?> loadProgress(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  /// Writes progress with `merge: true` so unrelated fields are preserved.
  ///
  /// `updatedAt` is stamped server-side.
  Future<void> saveProgress(
    String uid, {
    required String email,
    required String displayName,
    required int xp,
    required int coins,
    required List<String> completed,
  }) async {
    await _userDoc(uid).set(
      <String, dynamic>{
        'email': email,
        'displayName': displayName,
        'xp': xp,
        'coins': coins,
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Publishes (upserts) the player's public leaderboard row at
  /// `leaderboard/{uid}`. Written with `merge: true` and a server timestamp.
  /// Security rules restrict writes to the owning user.
  Future<void> publishLeaderboard(
    String uid, {
    required String displayName,
    required int xp,
    required int level,
  }) async {
    await _leaderboard.doc(uid).set(
      <String, dynamic>{
        'displayName': displayName,
        'xp': xp,
        'level': level,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Reads the top [limit] players ranked by XP (descending).
  ///
  /// A single-field `orderBy('xp')` needs no composite index. Any signed-in
  /// user may read the collection per the security rules.
  Future<List<LeaderboardEntry>> topLeaderboard({int limit = 50}) async {
    final snapshot = await _leaderboard
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => LeaderboardEntry.fromDoc(doc.id, doc.data()))
        .toList();
  }
}
