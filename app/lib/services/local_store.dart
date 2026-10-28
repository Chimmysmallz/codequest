import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_progress.dart';

/// Local, offline cache of a **guest** player's progress.
///
/// When the player is signed in, progress lives in Cloud Firestore (which has
/// its own offline persistence). When playing as a guest — not signed in — the
/// game persists progress here in [SharedPreferences] so nothing is lost
/// between launches and offline play stays fully functional.
///
/// Firebase Auth manages its own token persistence, so there is no token or
/// secure storage here anymore.
class LocalStore {
  static const String _kGuestProgress = 'cq_guest_progress';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Persists the guest's progress object as JSON.
  Future<void> saveGuestProgress(PlayerProgress progress) async {
    final prefs = await _prefs;
    await prefs.setString(_kGuestProgress, jsonEncode(progress.toJson()));
  }

  /// Loads the guest's progress, or null if nothing has been saved yet.
  Future<PlayerProgress?> loadGuestProgress() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kGuestProgress);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clears the cached guest progress (used by "New Game" while a guest).
  Future<void> clearGuestProgress() async {
    final prefs = await _prefs;
    await prefs.remove(_kGuestProgress);
  }
}
