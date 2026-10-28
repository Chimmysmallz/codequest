import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../data/seed_content.dart';
import '../models/leaderboard_entry.dart';
import '../models/mission.dart';
import '../models/player_progress.dart';
import '../models/user.dart';
import '../models/world.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';
import '../services/local_store.dart';

/// The outcome of a submission, shared by the fill-blank and code flows and
/// consumed by the result / challenge screens.
class SubmitResult {
  final bool passed;
  final int stars;
  final int xpEarned;
  final int coinsEarned;
  final String? output;
  final String? hint;
  final String message;

  const SubmitResult({
    required this.passed,
    this.stars = 0,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.output,
    this.hint,
    this.message = '',
  });
}

/// Central app state: content, player progress, auth and connectivity.
///
/// Accounts use **Firebase Auth**; per-user progress lives in **Cloud
/// Firestore**. Guests (not signed in) play fully offline against the bundled
/// [SeedContent], with progress cached in [LocalStore]. The FastAPI backend is
/// only used to run/grade real Python, authenticated with the user's Firebase
/// ID token.
class GameState extends ChangeNotifier {
  GameState({
    ApiService? api,
    LocalStore? store,
    FirebaseAuthService? auth,
    FirestoreService? firestore,
  })  : _api = api ?? ApiService(),
        _store = store ?? LocalStore(),
        _auth = auth ?? FirebaseAuthService(),
        _firestore = firestore ?? FirestoreService();

  final ApiService _api;
  final LocalStore _store;
  final FirebaseAuthService _auth;
  final FirestoreService _firestore;

  StreamSubscription<fb.User?>? _authSub;

  List<World> worlds = const [];
  List<Mission> missions = const [];
  PlayerProgress progress = const PlayerProgress();

  /// True when signed in and backed by cloud save (Firestore). Guests are
  /// "offline". Drives the Online/Offline badge in the UI.
  bool online = false;
  bool loading = true;

  bool get isLoggedIn => _auth.currentUser != null;

  String? get userId => _auth.currentUser?.uid;

  String? get userEmail => _auth.currentUser?.email;

  /// A UI-friendly view of the signed-in account, or null for a guest.
  AppUser? get user {
    final u = _auth.currentUser;
    if (u == null) return null;
    return AppUser(uid: u.uid, email: u.email ?? '');
  }

  ApiService get api => _api;

  // ---------------------------------------------------------------------------
  // Startup
  // ---------------------------------------------------------------------------

  /// Loads local (guest) progress first so the game is instantly playable, then
  /// subscribes to Firebase auth changes. When a user is (or becomes) signed
  /// in, their Firestore progress is merged with local progress exactly once.
  Future<void> init() async {
    loading = true;
    notifyListeners();

    // 1. Local guest progress first — instant offline play.
    final localGuest = await _store.loadGuestProgress();
    if (localGuest != null) {
      progress = localGuest;
    }

    // Seed content is the default; unlocks recompute from progress.
    worlds = [...SeedContent.worlds]..sort((a, b) => a.order.compareTo(b.order));
    missions = SeedContent.missions;

    // 2. React to Firebase auth state. authStateChanges() fires immediately
    //    with the current user (or null), so this also handles the
    //    already-signed-in-at-launch case.
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);

    loading = false;
    notifyListeners();
  }

  /// Handles sign-in / sign-out transitions.
  Future<void> _onAuthStateChanged(fb.User? user) async {
    if (user == null) {
      // Signed out — fall back to local guest progress.
      online = false;
      progress = await _store.loadGuestProgress() ?? const PlayerProgress();
      notifyListeners();
      return;
    }

    // Signed in — enter cloud mode and merge once with Firestore.
    online = true;
    notifyListeners();
    await _syncOnSignIn(user);
  }

  /// One-time merge on sign-in: union local guest progress with the user's
  /// Firestore progress (union completed, max xp/coins), save the merged result
  /// back to Firestore, then adopt it as the source of truth.
  Future<void> _syncOnSignIn(fb.User user) async {
    final uid = user.uid;
    final email = user.email ?? '';

    // The in-memory `progress` currently holds the local guest progress.
    final local = progress;

    PlayerProgress merged;
    try {
      final remoteData = await _firestore.loadProgress(uid);
      final remote = remoteData == null
          ? const PlayerProgress()
          : PlayerProgress.fromJson(remoteData);
      final union = _unionProgress(local, remote);
      merged = union.copyWith(
        userId: uid,
        displayName: _ensureDisplayName(union, email),
      );

      // Persist the merged union back to Firestore once, and seed the public
      // leaderboard row so the player appears on the board right away.
      await _firestore.saveProgress(
        uid,
        email: email,
        displayName: merged.displayName,
        xp: merged.xp,
        coins: merged.coins,
        completed: merged.completed.toList(),
      );
      await _firestore.publishLeaderboard(
        uid,
        displayName: merged.displayName,
        xp: merged.xp,
        level: merged.level,
      );
    } catch (_) {
      // Firestore unreachable — keep local; offline persistence reconciles
      // later. Stay in cloud mode, but still adopt the uid + a display name.
      merged = local.copyWith(
        userId: uid,
        displayName: _ensureDisplayName(local, email),
      );
    }

    progress = merged;
    online = true;
    notifyListeners();
  }

  /// Returns [p]'s display name, or a default derived from the email's local
  /// part (before `@`) when it is empty. The result is shown **publicly** on
  /// the leaderboard and is editable via [setDisplayName].
  String _ensureDisplayName(PlayerProgress p, String email) {
    final existing = p.displayName.trim();
    if (existing.isNotEmpty) return existing;
    final at = email.indexOf('@');
    final local = at > 0 ? email.substring(0, at) : email;
    // Keep letters/digits and a few safe separators; trim to a tidy handle.
    final cleaned = local.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '').trim();
    if (cleaned.isEmpty) return 'Explorer';
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  /// Combines two progress snapshots: union of completed missions and the max
  /// of xp / coins.
  PlayerProgress _unionProgress(PlayerProgress a, PlayerProgress b) {
    // Prefer a non-empty display name from either side (local first).
    final name = a.displayName.trim().isNotEmpty ? a.displayName : b.displayName;
    return PlayerProgress(
      userId: a.userId ?? b.userId,
      xp: a.xp >= b.xp ? a.xp : b.xp,
      coins: a.coins >= b.coins ? a.coins : b.coins,
      completed: {...a.completed, ...b.completed},
      displayName: name,
    );
  }

  // ---------------------------------------------------------------------------
  // Auth (pass-throughs to FirebaseAuthService)
  // ---------------------------------------------------------------------------

  /// Creates an account. The auth-state listener then merges + syncs progress.
  /// Throws [AuthException] with a friendly message on failure.
  Future<void> register(String email, String password) async {
    await _auth.register(email.trim(), password);
  }

  /// Signs in. The auth-state listener then merges + syncs progress.
  /// Throws [AuthException] with a friendly message on failure.
  Future<void> signIn(String email, String password) async {
    await _auth.signIn(email.trim(), password);
  }

  /// Signs out; the listener falls back to local guest progress.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password-reset email. Throws [AuthException] on failure.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordReset(email.trim());
  }

  // ---------------------------------------------------------------------------
  // Query helpers
  // ---------------------------------------------------------------------------

  /// Missions of a world, ordered by their [Mission.index].
  List<Mission> missionsForWorld(String worldId) {
    final list = missions.where((m) => m.worldId == worldId).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  World? worldById(String worldId) {
    for (final w in worlds) {
      if (w.id == worldId) return w;
    }
    return null;
  }

  /// The world immediately before [world] by order, or null for the first.
  World? previousWorld(World world) {
    World? prev;
    for (final w in worlds) {
      if (w.order < world.order) {
        if (prev == null || w.order > prev.order) prev = w;
      }
    }
    return prev;
  }

  /// A world is unlocked if it is first (order 0) or every mission in the
  /// previous world has been completed.
  bool isWorldUnlocked(World world) {
    if (world.order == 0) return true;
    final prev = previousWorld(world);
    if (prev == null) return true;
    final prevMissions = missionsForWorld(prev.id);
    if (prevMissions.isEmpty) return true;
    return prevMissions.every((m) => progress.isCompleted(m.id));
  }

  bool isMissionCompleted(String id) => progress.isCompleted(id);

  /// The first not-yet-completed mission in a world, or null if all done.
  Mission? nextMissionForWorld(String worldId) {
    for (final m in missionsForWorld(worldId)) {
      if (!progress.isCompleted(m.id)) return m;
    }
    return null;
  }

  /// Stars for a mission (3 for completed in MVP, 0 otherwise).
  int starsFor(String id) => progress.isCompleted(id) ? 3 : 0;

  /// Whether every mission of a world is complete.
  bool isWorldComplete(String worldId) {
    final list = missionsForWorld(worldId);
    if (list.isEmpty) return false;
    return list.every((m) => progress.isCompleted(m.id));
  }

  // ---------------------------------------------------------------------------
  // Running & submitting
  // ---------------------------------------------------------------------------

  /// Runs Python and returns its combined output. Requires the backend and a
  /// signed-in user (the `/run` endpoint needs a Firebase ID token).
  Future<String> runCode(String code) async {
    if (!isLoggedIn) {
      return 'Sign in to run and check real code.';
    }
    final idToken = await _auth.idToken();
    if (idToken == null) {
      return 'Sign in to run and check real code.';
    }
    try {
      final res = await _api.runCode(code, idToken: idToken);
      if (res.timedOut) return 'Your code took too long to run. Try again!';
      if (res.error.isNotEmpty) return res.error;
      return res.output.isEmpty ? '(no output)' : res.output;
    } catch (_) {
      return 'Could not reach the code runner. Check that the backend is running.';
    }
  }

  /// Submits a fill-in-the-blank answer, graded locally against the bundled
  /// [SeedContent] answers so it stays fully playable offline and as a guest.
  ///
  /// On a pass the reward is awarded exactly once (double-completion guarded),
  /// then persisted to Firestore when signed in, or to the local guest cache
  /// otherwise.
  Future<SubmitResult> submitFillBlank(Mission mission, String answer) async {
    final expected = _localAnswerFor(mission);
    final passed = expected != null && answer.trim() == expected;
    if (passed) {
      final already = progress.isCompleted(mission.id);
      await _award(mission);
      return SubmitResult(
        passed: true,
        stars: 3,
        xpEarned: already ? 0 : mission.xp,
        coinsEarned: already ? 0 : mission.coins,
        message: 'Correct!',
      );
    }
    return SubmitResult(
      passed: false,
      hint: mission.challenge.hint,
      message: 'Not quite — try again!',
    );
  }

  /// Submits a code challenge. Real Python needs the backend + a signed-in user
  /// (for the Firebase ID token). On a pass the reward is awarded once and
  /// persisted to Firestore.
  Future<SubmitResult> submitCode(Mission mission, String code) async {
    if (!isLoggedIn) {
      return SubmitResult(
        passed: false,
        hint: mission.challenge.hint,
        message: 'Sign in to run real code.',
      );
    }
    final idToken = await _auth.idToken();
    if (idToken == null) {
      return SubmitResult(
        passed: false,
        hint: mission.challenge.hint,
        message: 'Sign in to run real code.',
      );
    }
    try {
      final already = progress.isCompleted(mission.id);
      final res = await _api.submit(
        missionId: mission.id,
        code: code,
        idToken: idToken,
      );
      if (res.passed) {
        await _award(mission);
      }
      return SubmitResult(
        passed: res.passed,
        stars: res.passed ? (res.stars == 0 ? 3 : res.stars) : 0,
        xpEarned: res.passed && !already ? mission.xp : 0,
        coinsEarned: res.passed && !already ? mission.coins : 0,
        output: res.output,
        hint: res.hint ?? mission.challenge.hint,
        message: res.message.isEmpty
            ? (res.passed ? 'Great job!' : 'Not quite — check your output.')
            : res.message,
      );
    } catch (_) {
      return SubmitResult(
        passed: false,
        hint: mission.challenge.hint,
        message: 'Could not reach the code runner. Check the backend and try again.',
      );
    }
  }

  /// The expected fill-blank answer for local grading, resolved from the mission
  /// and falling back to the bundled [SeedContent].
  String? _localAnswerFor(Mission mission) {
    final own = mission.challenge.answer;
    if (own != null && own.isNotEmpty) return own;
    for (final m in SeedContent.missions) {
      if (m.id == mission.id) {
        final seed = m.challenge.answer;
        if (seed != null && seed.isNotEmpty) return seed;
      }
    }
    return null;
  }

  /// Awards XP/coins and marks a mission completed, guarding double-awarding.
  /// Persists to Firestore when signed in, or to the guest cache otherwise.
  Future<void> _award(Mission mission) async {
    if (progress.isCompleted(mission.id)) {
      // Already awarded — nothing to add.
      return;
    }
    progress = progress.copyWith(
      xp: progress.xp + mission.xp,
      coins: progress.coins + mission.coins,
      completed: {...progress.completed, mission.id},
      userId: userId ?? progress.userId,
    );
    await _persist();
    notifyListeners();
  }

  /// Persists the current progress to the right place: Firestore when signed
  /// in, the local guest cache otherwise.
  Future<void> _persist() async {
    final u = _auth.currentUser;
    if (u != null) {
      try {
        await _firestore.saveProgress(
          u.uid,
          email: u.email ?? '',
          displayName: progress.displayName,
          xp: progress.xp,
          coins: progress.coins,
          completed: progress.completed.toList(),
        );
        // Keep the public leaderboard row in sync after each change (e.g. every
        // completed mission) so the board reflects the latest XP/level/name.
        await _firestore.publishLeaderboard(
          u.uid,
          displayName: progress.displayName,
          xp: progress.xp,
          level: progress.level,
        );
      } catch (_) {
        // Firestore offline persistence will retry the writes automatically.
      }
    } else {
      await _store.saveGuestProgress(progress);
    }
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  /// Loads the top players by XP from the public `leaderboard` collection.
  ///
  /// Returns an empty list when signed out (reads require auth) or on any
  /// error — it never throws, so the UI can render a friendly empty state.
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) async {
    if (!isLoggedIn) return const <LeaderboardEntry>[];
    try {
      return await _firestore.topLeaderboard(limit: limit);
    } catch (_) {
      return const <LeaderboardEntry>[];
    }
  }

  /// Sets the player's public display name (leaderboard handle).
  ///
  /// Trims and validates the input, falling back to `'Explorer'` when empty and
  /// capping the length. Updates the in-memory progress and persists it — which
  /// also republishes the leaderboard row when signed in — then notifies.
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    final clean = trimmed.isEmpty
        ? 'Explorer'
        : (trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed);
    if (clean == progress.displayName) return;
    progress = progress.copyWith(displayName: clean);
    await _persist();
    notifyListeners();
  }

  /// Resets all progress (New Game). Keeps the current session if signed in.
  Future<void> resetProgress() async {
    // Keep the public display name across a New Game — only game progress
    // (XP, coins, completed missions) is wiped.
    progress = PlayerProgress(
      userId: userId,
      displayName: progress.displayName,
    );
    if (_auth.currentUser == null) {
      await _store.clearGuestProgress();
    }
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _api.dispose();
    super.dispose();
  }
}
