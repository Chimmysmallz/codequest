import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mission.dart';
import '../models/world.dart';

/// Result of loading content from the server.
class ContentResult {
  final List<World> worlds;
  final List<Mission> missions;
  const ContentResult({required this.worlds, required this.missions});
}

/// Result of running code through the backend (no grading).
class RunResult {
  final String output;
  final String error;
  final bool timedOut;
  const RunResult({
    this.output = '',
    this.error = '',
    this.timedOut = false,
  });

  factory RunResult.fromJson(Map<String, dynamic> json) => RunResult(
        output: (json['output'] as String?) ?? '',
        error: (json['error'] as String?) ?? '',
        timedOut: (json['timedOut'] as bool?) ?? false,
      );
}

/// Result of submitting an answer to the backend for grading.
class ServerSubmitResult {
  final bool passed;
  final int stars;
  final int xpEarned;
  final int coinsEarned;
  final String? output;
  final String? error;
  final String? hint;
  final String message;
  final Map<String, dynamic>? progress;

  const ServerSubmitResult({
    required this.passed,
    required this.stars,
    required this.xpEarned,
    required this.coinsEarned,
    this.output,
    this.error,
    this.hint,
    this.message = '',
    this.progress,
  });

  factory ServerSubmitResult.fromJson(Map<String, dynamic> json) {
    return ServerSubmitResult(
      passed: (json['passed'] as bool?) ?? false,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? 0,
      output: json['output'] as String?,
      error: json['error'] as String?,
      hint: json['hint'] as String?,
      message: (json['message'] as String?) ?? '',
      progress: json['progress'] as Map<String, dynamic>?,
    );
  }
}

/// Thin HTTP client for the CodeQuest FastAPI backend.
///
/// The backend is now used ONLY to run and grade real Python (`/run`,
/// `/submit`). Accounts and per-user progress live in Firebase Auth and Cloud
/// Firestore, not here.
///
/// The protected `/run` and `/submit` endpoints require the caller to pass the
/// current user's **Firebase ID token**, which is sent as an
/// `Authorization: Bearer <idToken>` header. The backend verifies it with the
/// Firebase Admin SDK.
class ApiService {
  /// Base URL of the backend.
  ///
  /// Default targets the Android emulator loopback (10.0.2.2). For the iOS
  /// simulator, desktop or web use `http://localhost:8000` instead.
  /// Override at build time without editing code:
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
  String baseUrl;

  final Duration timeout;
  final http.Client _client;

  ApiService({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
    this.timeout = const Duration(seconds: 4),
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// JSON headers plus a bearer token when a Firebase ID token is supplied.
  Map<String, String> _authHeaders(String? idToken) => {
        'Content-Type': 'application/json',
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken',
      };

  /// Returns true if the backend answers a healthy `/health` ping.
  Future<bool> ping() async {
    try {
      final res = await _client.get(_uri('/health')).timeout(timeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Content & gameplay
  // ---------------------------------------------------------------------------

  /// Fetches worlds + missions from the server (answers are hidden server-side).
  ///
  /// Optional: the client ships the same content in [SeedContent], so this is
  /// only used to keep an online client fresh.
  Future<ContentResult> fetchContent() async {
    final res = await _client.get(_uri('/content')).timeout(timeout);
    if (res.statusCode != 200) {
      throw ApiException('content fetch failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final worlds = ((body['worlds'] as List?) ?? [])
        .map((e) => World.fromJson(e as Map<String, dynamic>))
        .toList();
    final missions = ((body['missions'] as List?) ?? [])
        .map((e) => Mission.fromJson(e as Map<String, dynamic>))
        .toList();
    return ContentResult(worlds: worlds, missions: missions);
  }

  /// Executes Python code and returns its captured output/error. Protected —
  /// pass the Firebase ID token.
  Future<RunResult> runCode(String code, {String? idToken}) async {
    final res = await _client
        .post(
          _uri('/run'),
          headers: _authHeaders(idToken),
          body: jsonEncode({'code': code}),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw ApiException('run failed (${res.statusCode})');
    }
    return RunResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Submits an answer (`fill_blank`) or code for grading. Protected — pass the
  /// Firebase ID token; the server identifies the user from it, so no userId is
  /// sent.
  Future<ServerSubmitResult> submit({
    required String missionId,
    String? answer,
    String? code,
    String? idToken,
  }) async {
    final payload = <String, dynamic>{
      'missionId': missionId,
      if (answer != null) 'answer': answer,
      if (code != null) 'code': code,
    };
    final res = await _client
        .post(
          _uri('/submit'),
          headers: _authHeaders(idToken),
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw ApiException('submit failed (${res.statusCode})');
    }
    return ServerSubmitResult.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}

/// Simple typed error for backend failures.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
