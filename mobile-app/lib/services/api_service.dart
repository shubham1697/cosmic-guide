import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/zodiac.dart';

/// Why a request failed. Collapsing these into `null` hides an expired session
/// behind the same "unable to load" message as a flaky train tunnel.
enum ApiErrorKind {
  /// No usable connection, DNS failure, or the host does not exist.
  network,

  /// The request was sent but nothing came back in time.
  timeout,

  /// 401/403 — the session is no longer accepted. Not retryable.
  unauthorized,

  /// 429 — throttled. [ApiException.retryAfter] says how long to wait.
  rateLimited,

  /// 5xx other than 503.
  server,

  /// 503 — the server is up but a dependency it needs is not.
  unavailable,

  /// 2xx with a body we could not parse, or an unexpected 4xx.
  badResponse,
}

class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.retryAfter});

  final ApiErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  /// Copy suitable for showing to a user.
  String get message => switch (kind) {
    ApiErrorKind.network => "Can't reach CosmicGuide. Check your connection.",
    ApiErrorKind.timeout => 'The stars are taking their time. Try again.',
    ApiErrorKind.unauthorized => 'Your session expired. Please sign in again.',
    ApiErrorKind.rateLimited =>
      retryAfter == null
          ? 'Too many requests. Give it a moment.'
          : 'Too many requests. Try again in ${retryAfter!.inSeconds}s.',
    ApiErrorKind.server => 'Something went wrong on our side.',
    ApiErrorKind.unavailable => 'CosmicGuide is briefly unavailable.',
    ApiErrorKind.badResponse => "We couldn't read the response.",
  };

  /// Whether trying again (eventually) could succeed.
  bool get isRetryable => kind != ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException(${kind.name}, status: $statusCode)';
}

class ApiService {
  /// Production API root, including scheme and `/api/v1`. Set at build time:
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://api.example.com/api/v1
  /// Falls back to [_fallbackProdBaseUrl] so a release build never silently
  /// talks to localhost. Must be HTTPS — release builds block cleartext.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Placeholder host. A release build that still resolves to this cannot talk
  /// to any backend, so [assertReleaseConfig] refuses to let it start quietly.
  /// Replace it with the real hostname, or keep passing
  /// --dart-define=API_BASE_URL at build time.
  static const String _fallbackProdBaseUrl =
      'https://api.cosmicguide.app/api/v1';

  /// True when a release build has no real backend configured.
  static bool get isUsingPlaceholderHost =>
      kReleaseMode &&
      _apiBaseUrlOverride.isEmpty &&
      _fallbackProdBaseUrl.contains('api.cosmicguide.app');

  /// Fails loudly in a debug/profile build, so the misconfiguration surfaces
  /// while it is still cheap. Release builds cannot assert, which is exactly
  /// why CI also greps the artifact.
  static void assertReleaseConfig() {
    assert(
      !isUsingPlaceholderHost,
      'API_BASE_URL is not set and the fallback host is still the placeholder. '
      'Build with --dart-define=API_BASE_URL=https://<your-host>/api/v1.',
    );
  }

  // Optional override for physical devices in development:
  // flutter run --dart-define=API_HOST=192.168.29.123
  static const String _apiHostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  // Local backend (Docker): Android emulator must use 10.0.2.2.
  static String get _baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    if (kReleaseMode) {
      return _fallbackProdBaseUrl;
    }
    if (_apiHostOverride.isNotEmpty) {
      return 'http://$_apiHostOverride:8000/api/v1';
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8000/api/v1';
    }
  }

  // Render free tier can take 15-30s to cold-start; use a generous timeout.
  static const _timeout = Duration(seconds: 20);

  /// Supplies the Firebase ID token for authenticated calls. Wired to
  /// `AuthService.idToken` in main() so this layer stays testable.
  static Future<String?> Function()? tokenProvider;

  /// Invoked when the server rejects our credentials. Wired in main() to sign
  /// the user out — otherwise a revoked session leaves them signed in forever,
  /// retrying a request that can never succeed.
  static Future<void> Function()? onUnauthorized;

  /// The most recent failure, or null after any success. Screens listen to this
  /// to say *why* a reading is missing instead of "unable to load".
  static final ValueNotifier<ApiException?> lastError =
      ValueNotifier<ApiException?>(null);

  static Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = await tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static ApiException _fail(
    ApiErrorKind kind, {
    int? statusCode,
    Duration? retryAfter,
  }) {
    final error = ApiException(
      kind,
      statusCode: statusCode,
      retryAfter: retryAfter,
    );
    lastError.value = error;
    return error;
  }

  /// Swappable so tests can drive the status-code handling without a server.
  @visibleForTesting
  static http.Client client = http.Client();

  /// Single entry point for every call: attaches credentials, applies the
  /// timeout, and turns a status code into a typed [ApiException]. Returns the
  /// decoded JSON body on success.
  static Future<dynamic> _send(
    String method,
    Uri uri, {
    Object? body,
    Duration? timeout,
  }) async {
    final headers = await _authHeaders(json: body != null);
    http.Response response;
    try {
      final Future<http.Response> pending = switch (method) {
        'GET' => client.get(uri, headers: headers),
        'POST' => client.post(uri, headers: headers, body: json.encode(body)),
        'PUT' => client.put(uri, headers: headers, body: json.encode(body)),
        'DELETE' => client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method $method'),
      };
      response = await pending.timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw _fail(ApiErrorKind.timeout);
    } catch (e) {
      debugPrint('$method $uri failed: $e');
      throw _fail(ApiErrorKind.network);
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      lastError.value = null;
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (_) {
        throw _fail(ApiErrorKind.badResponse, statusCode: code);
      }
    }

    if (code == 401 || code == 403) {
      final error = _fail(ApiErrorKind.unauthorized, statusCode: code);
      unawaited(Future(() async => onUnauthorized?.call()));
      throw error;
    }
    if (code == 429) {
      throw _fail(
        ApiErrorKind.rateLimited,
        statusCode: code,
        retryAfter: _parseRetryAfter(response.headers['retry-after']),
      );
    }
    if (code == 503) throw _fail(ApiErrorKind.unavailable, statusCode: code);
    if (code >= 500) throw _fail(ApiErrorKind.server, statusCode: code);

    debugPrint('$method $uri -> $code ${response.body}');
    throw _fail(ApiErrorKind.badResponse, statusCode: code);
  }

  // ── Request de-duplication + short-lived cache ───────────────────────────
  // The Home, Chart and Vedic tabs all live in an IndexedStack (they stay alive)
  // and each fetches the same read endpoints, so identical GETs tend to fire at
  // once and on every rebuild. These maps coalesce identical in-flight requests
  // and briefly cache their parsed result, keyed by the full request URL.
  static final Map<String, Future<Object?>> _inFlight = {};
  static final Map<String, ({DateTime at, Object? value})> _responseCache = {};

  /// Keys are per-URL (every date navigated, every forecast window), so the
  /// cache is capped and pruned on write rather than growing for the life of
  /// the process.
  static const int _responseCacheMax = 100;

  static void _storeInCache(String key, Object? value) {
    final now = DateTime.now();
    _responseCache.remove(key); // re-insert so iteration order tracks recency
    _responseCache[key] = (at: now, value: value);
    _responseCache.removeWhere(
      (_, entry) => now.difference(entry.at) > const Duration(minutes: 10),
    );
    while (_responseCache.length > _responseCacheMax) {
      _responseCache.remove(_responseCache.keys.first);
    }
  }

  /// Coalesce and briefly cache an idempotent read.
  ///
  /// Returns a fresh cached value (within [ttl]) without a network call; shares
  /// the same Future when an identical request is already running. Only non-null
  /// results are cached, so failures retry immediately.
  static Future<T?> _dedup<T>(
    String key,
    Future<T?> Function() fetch, {
    Duration ttl = const Duration(minutes: 2),
  }) {
    final cached = _responseCache[key];
    if (cached != null && DateTime.now().difference(cached.at) < ttl) {
      return Future.value(cached.value as T?);
    }
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then((v) => v as T?);
    }
    final future = fetch();
    _inFlight[key] = future;
    return future
        .then((result) {
          if (result != null) _storeInCache(key, result);
          return result;
        })
        .whenComplete(() {
          _inFlight.remove(key);
        });
  }

  /// Drop every cached response so the next read hits the network.
  /// In-flight requests are left alone; they complete normally.
  static void clearCache() => _responseCache.clear();

  /// Fetch today's horoscope for a sign. Returns null on failure.
  ///
  /// [system] selects the tradition: 'western' (tropical Sun sign) or 'vedic'
  /// (sidereal reading keyed on the Moon rashi / Janma Rashi).
  static Future<HoroscopeData?> getHoroscope(
    String sign, {
    String system = 'western',
    String period = 'daily',
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) {
    final path = period == 'weekly'
        ? 'weekly'
        : period == 'monthly'
        ? 'monthly'
        : 'today';
    // Birth details personalize the DAILY reading (real natal chart + today's
    // transits to it). Weekly/monthly stay generic per-sign.
    final personal = period == 'daily' && (birthDate?.isNotEmpty ?? false);
    final buf = StringBuffer(
      '$_baseUrl/horoscope/$path?zodiac_sign=$sign&system=$system',
    );
    if (personal) {
      buf.write('&birthDate=${Uri.encodeQueryComponent(birthDate!)}');
      if (birthTime?.isNotEmpty ?? false) {
        buf.write('&birthTime=${Uri.encodeQueryComponent(birthTime!)}');
      }
      if (birthPlace?.isNotEmpty ?? false) {
        buf.write('&birthPlace=${Uri.encodeQueryComponent(birthPlace!)}');
      }
    }
    final url = buf.toString();
    // Weekly/monthly, and personalized daily, may be generated on-demand by a
    // local LLM — allow longer.
    final timeout = (period == 'daily' && !personal)
        ? _timeout
        : const Duration(seconds: 35);
    return _dedup<HoroscopeData>(url, () async {
      try {
        final data = await _send('GET', Uri.parse(url), timeout: timeout);
        return HoroscopeData(
          sign: data['sign'],
          date: data['date'],
          general: data['general'],
          love: data['love'],
          career: data['career'],
          health: data['health'],
          overallScore: data['overallScore'],
          luckyNumber: data['luckyNumber'],
          luckyColor: data['luckyColor'],
          mood: data['mood'],
          personalized: data['personalized'] == true,
          band: data['band'] as String?,
          moodSummary: data['moodSummary'] as String?,
          source: data['source'] as String?,
        );
      } catch (_) {
        return null;
      }
    });
  }

  /// Fetch the personalized [days]-day energy forecast: a deterministic score
  /// and band per day, computed from that day's transit-to-natal aspects.
  /// Requires a birth date; returns null on failure.
  static Future<({List<ForecastPoint> points, ForecastPoint? bestDay})?>
  getForecast({
    required String birthDate,
    String? birthTime,
    String? birthPlace,
    String system = 'western',
    int days = 30,
  }) {
    if (birthDate.isEmpty) return Future.value(null);
    final buf = StringBuffer(
      '$_baseUrl/horoscope/forecast'
      '?birthDate=${Uri.encodeQueryComponent(birthDate)}'
      '&system=$system&days=$days',
    );
    if (birthTime?.isNotEmpty ?? false) {
      buf.write('&birthTime=${Uri.encodeQueryComponent(birthTime!)}');
    }
    if (birthPlace?.isNotEmpty ?? false) {
      buf.write('&birthPlace=${Uri.encodeQueryComponent(birthPlace!)}');
    }
    final url = buf.toString();
    return _dedup<({List<ForecastPoint> points, ForecastPoint? bestDay})>(
      url,
      () async {
        try {
          final data =
              await _send(
                    'GET',
                    Uri.parse(url),
                    timeout: const Duration(seconds: 30),
                  )
                  as Map<String, dynamic>;
          final points = (data['forecast'] as List<dynamic>? ?? const [])
              .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
              .toList();
          if (points.isEmpty) return null;
          final bd = data['bestDay'];
          final bestDay = bd is Map<String, dynamic>
              ? ForecastPoint.fromJson(bd)
              : null;
          return (points: points, bestDay: bestDay);
        } catch (_) {
          return null;
        }
      },
    );
  }

  /// Draw a random tarot card. Returns null on failure.
  static Future<({TarotCard card, bool isReversed})?> drawTarotCard() async {
    try {
      final data = await _send('GET', Uri.parse('$_baseUrl/tarot/draw'));
      final isReversed = data['isReversed'] as bool;
      return (
        card: TarotCard(
          name: data['name'],
          number: data['number'],
          meaning: data['meaning'],
          interpretation: isReversed ? '' : data['interpretation'],
          reversedInterpretation: isReversed ? data['interpretation'] : '',
          isReversed: isReversed,
        ),
        isReversed: isReversed,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generate a fortune. Returns null on failure.
  static Future<String?> generateFortune(
    String zodiacSign,
    String topic,
    String mood,
  ) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/fortune/generate'),
        body: {'zodiacSign': zodiacSign, 'topic': topic, 'mood': mood},
      );
      return data['fortuneText'] as String;
    } catch (_) {
      return null;
    }
  }

  /// Check compatibility between two signs. Returns null on failure.
  static Future<CompatibilityResult?> checkCompatibility(
    String sign1,
    String sign2,
  ) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/compatibility/check'),
        body: {'sign1': sign1, 'sign2': sign2},
      );
      final loveAdvice = (data['loveAdvice'] ?? data['love_advice'] ?? '')
          .toString();
      final strengthsTogether =
          (data['strengthsTogether'] ?? data['strengths_together'] ?? '')
              .toString();
      final challenges = (data['challenges'] ?? data['challenge'] ?? '')
          .toString();
      return CompatibilityResult(
        sign1: (data['sign1'] ?? sign1).toString(),
        sign2: (data['sign2'] ?? sign2).toString(),
        score: (data['score'] as num?)?.toInt() ?? 70,
        description: (data['description'] ?? '').toString(),
        loveAdvice: loveAdvice,
        strengthsTogether: strengthsTogether,
        challenges: challenges,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculate Kundli matching. Returns null on failure.
  static Future<KundliResult?> calculateKundli({
    required String name1,
    required String birthDate1,
    String? birthTime1,
    String? birthPlace1,
    required String name2,
    required String birthDate2,
    String? birthTime2,
    String? birthPlace2,
  }) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/kundli/match'),
        body: {
          'person1': {
            'name': name1,
            'birthDate': birthDate1,
            'birthTime': birthTime1,
            'birthPlace': birthPlace1,
          },
          'person2': {
            'name': name2,
            'birthDate': birthDate2,
            'birthTime': birthTime2,
            'birthPlace': birthPlace2,
          },
        },
        timeout: const Duration(seconds: 30),
      );
      return KundliResult(
        totalScore: data['totalScore'],
        maxScore: data['maxScore'],
        kootaScores: Map<String, int>.from(data['kootaScores']),
        compatibility: data['compatibility'],
        analysis: data['analysis'],
        hasManglikDosha: data['hasManglikDosha'],
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch cosmic stories. Returns empty list on failure.
  static Future<List<AstrologyStory>> getStories() async {
    final url = '$_baseUrl/stories';
    final result = await _dedup<List<AstrologyStory>>(url, () async {
      try {
        final data = await _send('GET', Uri.parse(url));
        final stories = data['stories'] as List;
        final parsed = stories
            .map(
              (s) => AstrologyStory(
                title: s['title'],
                summary: s['summary'],
                category: s['category'],
                readTime: s['readTime'],
                content: s['content'] ?? '',
              ),
            )
            .toList();
        return parsed.isEmpty ? null : parsed;
      } catch (_) {
        return null;
      }
    });
    return result ?? [];
  }

  /// Fetch a full birth chart calculated with Swiss Ephemeris.
  static Future<BirthChartData?> getBirthChart({
    required String birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/chart/birth'),
        body: {
          'birthDate': birthDate,
          'birthTime': birthTime,
          'birthPlace': birthPlace,
        },
        timeout: const Duration(seconds: 30),
      );
      return BirthChartData.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetch a sidereal Vedic (Jyotish) birth chart — Lahiri ayanamsa, the nine
  /// grahas (incl. Rahu/Ketu), and whole-sign houses. This is the data that
  /// powers the authentic North/South Indian kundli chart.
  static Future<BirthChartData?> getVedicChart({
    required String birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/chart/vedic'),
        body: {
          'birthDate': birthDate,
          'birthTime': birthTime,
          'birthPlace': birthPlace,
        },
        timeout: const Duration(seconds: 30),
      );
      return BirthChartData.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetch current planetary transits.
  static Future<List<TransitData>> getTransits() async {
    final url = '$_baseUrl/chart/transits';
    final result = await _dedup<List<TransitData>>(url, () async {
      try {
        final data = await _send('GET', Uri.parse(url));
        final transits = data['transits'] as List;
        final parsed = transits.map((t) => TransitData.fromJson(t)).toList();
        return parsed.isEmpty ? null : parsed;
      } catch (_) {
        return null;
      }
    });
    return result ?? [];
  }

  /// Fetch Vedic hub summary data. Returns null on failure.
  static Future<VedicHomeSummaryData?> getVedicHomeSummary({
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) {
    final query = <String, String>{};
    if (birthDate != null && birthDate.isNotEmpty) {
      query['birthDate'] = birthDate;
    }
    if (birthTime != null && birthTime.isNotEmpty) {
      query['birthTime'] = birthTime;
    }
    if (birthPlace != null && birthPlace.isNotEmpty) {
      query['birthPlace'] = birthPlace;
    }

    final uri = Uri.parse(
      '$_baseUrl/vedic/home-summary',
    ).replace(queryParameters: query.isEmpty ? null : query);
    return _dedup<VedicHomeSummaryData>(uri.toString(), () async {
      try {
        final data = await _send('GET', uri) as Map<String, dynamic>;
        return VedicHomeSummaryData.fromJson(data);
      } catch (_) {
        return null;
      }
    });
  }

  // ── Push notifications ─────────────────────────────────────────────────────

  /// Register (or update) this device's push token so it can receive daily
  /// reminders. Upserts by token on the backend. Returns true on success.
  static Future<bool> registerDeviceToken({
    required String token,
    required String platform,
    String? zodiacSign,
    String? tradition,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
    bool dailyHoroscopeEnabled = true,
  }) async {
    try {
      await _send(
        'POST',
        Uri.parse('$_baseUrl/notifications/register'),
        body: {
          'token': token,
          'platform': platform,
          'zodiacSign': zodiacSign,
          'tradition': tradition,
          'birthDate': birthDate,
          'birthTime': birthTime,
          'birthPlace': birthPlace,
          'dailyHoroscopeEnabled': dailyHoroscopeEnabled,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove this device's token from the backend (e.g. on sign-out or opt-out).
  /// Call it *before* signing out, while the token is still valid.
  static Future<bool> unregisterDeviceToken(String token) async {
    try {
      await _send(
        'POST',
        Uri.parse('$_baseUrl/notifications/unregister'),
        body: {'token': token},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle the daily horoscope reminder for an already-registered device.
  static Future<bool> updateNotificationPreferences({
    required String token,
    required bool dailyHoroscopeEnabled,
  }) async {
    try {
      await _send(
        'PUT',
        Uri.parse('$_baseUrl/notifications/preferences'),
        body: {'token': token, 'dailyHoroscopeEnabled': dailyHoroscopeEnabled},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ask the backend to send a one-off test push to [token]. Returns whether
  /// the server actually dispatched it (false when FCM isn't configured yet).
  static Future<bool> sendTestPush({
    required String token,
    String? title,
    String? body,
  }) async {
    try {
      final data = await _send(
        'POST',
        Uri.parse('$_baseUrl/notifications/test'),
        body: {
          'token': token,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
        },
      );
      return data['sent'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Signed-in profile ────────────────────────────────────────────────────

  /// Fetch the synced profile, creating it server-side on first call.
  ///
  /// Throws [ApiException] so the caller can tell "this account has no profile
  /// yet" apart from "we could not reach the server" — conflating the two sends
  /// a returning user back through onboarding and overwrites their real data.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final data = await _send('GET', Uri.parse('$_baseUrl/users/me'));
    return data as Map<String, dynamic>?;
  }

  /// Push local profile fields to the server. Omitted values are left as-is;
  /// pass an empty string to clear a field.
  static Future<bool> updateProfile({
    String? name,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
    String? zodiacSign,
    String? tradition,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name.isEmpty ? null : name,
      if (birthDate != null) 'birthDate': birthDate.isEmpty ? null : birthDate,
      if (birthTime != null) 'birthTime': birthTime.isEmpty ? null : birthTime,
      if (birthPlace != null)
        'birthPlace': birthPlace.isEmpty ? null : birthPlace,
      if (zodiacSign != null && zodiacSign.isNotEmpty) 'zodiacSign': zodiacSign,
      if (tradition != null && tradition.isNotEmpty) 'tradition': tradition,
    };
    if (payload.isEmpty) return true;

    try {
      await _send('PUT', Uri.parse('$_baseUrl/users/me'), body: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Erase the server-side account. The server only commits the deletion once
  /// the sign-in credential is gone, so a false here means nothing was removed
  /// and the call can safely be retried.
  static Future<bool> deleteProfile() async {
    try {
      final data = await _send('DELETE', Uri.parse('$_baseUrl/users/me'));
      return data is Map && data['credentialRemoved'] == true;
    } catch (_) {
      return false;
    }
  }
}
