import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/zodiac.dart';

class ApiService {
  // Optional override for physical devices:
  // flutter run --dart-define=API_HOST=192.168.29.123
  static const String _apiHostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  // Local backend (Docker): Android emulator must use 10.0.2.2.
  static String get _baseUrl {
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

  // ── Request de-duplication + short-lived cache ───────────────────────────
  // The Home, Chart and Vedic tabs all live in an IndexedStack (they stay alive)
  // and each fetches the same read endpoints, so identical GETs tend to fire at
  // once and on every rebuild. These maps coalesce identical in-flight requests
  // and briefly cache their parsed result, keyed by the full request URL.
  static final Map<String, Future<Object?>> _inFlight = {};
  static final Map<String, ({DateTime at, Object? value})> _responseCache = {};

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
          if (result != null) {
            _responseCache[key] = (at: DateTime.now(), value: result);
          }
          return result;
        })
        .whenComplete(() {
          _inFlight.remove(key);
        });
  }

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
        final response = await http.get(Uri.parse(url)).timeout(timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
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
          );
        }
      } catch (_) {}
      return null;
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
    return _dedup<({List<ForecastPoint> points, ForecastPoint? bestDay})>(url, () async {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final points = (data['forecast'] as List<dynamic>? ?? const [])
              .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
              .toList();
          if (points.isEmpty) return null;
          final bd = data['bestDay'];
          final bestDay = bd is Map<String, dynamic>
              ? ForecastPoint.fromJson(bd)
              : null;
          return (points: points, bestDay: bestDay);
        }
      } catch (_) {}
      return null;
    });
  }

  /// Draw a random tarot card. Returns null on failure.
  static Future<({TarotCard card, bool isReversed})?> drawTarotCard() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/tarot/draw'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
      }
    } catch (_) {}
    return null;
  }

  /// Generate a fortune. Returns null on failure.
  static Future<String?> generateFortune(
    String zodiacSign,
    String topic,
    String mood,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/fortune/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'zodiacSign': zodiacSign,
              'topic': topic,
              'mood': mood,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['fortuneText'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Check compatibility between two signs. Returns null on failure.
  static Future<CompatibilityResult?> checkCompatibility(
    String sign1,
    String sign2,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/compatibility/check');
      debugPrint(
        'checkCompatibility request: url=$url sign1=$sign1 sign2=$sign2',
      );
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'sign1': sign1, 'sign2': sign2}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
      }
      debugPrint(
        'checkCompatibility failed: status=${response.statusCode} body=${response.body}',
      );
    } catch (e) {
      debugPrint('checkCompatibility exception: $e');
    }
    return null;
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/kundli/match'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
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
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return KundliResult(
          totalScore: data['totalScore'],
          maxScore: data['maxScore'],
          kootaScores: Map<String, int>.from(data['kootaScores']),
          compatibility: data['compatibility'],
          analysis: data['analysis'],
          hasManglikDosha: data['hasManglikDosha'],
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetch cosmic stories. Returns empty list on failure.
  static Future<List<AstrologyStory>> getStories() async {
    final url = '$_baseUrl/stories';
    final result = await _dedup<List<AstrologyStory>>(url, () async {
      try {
        final response = await http.get(Uri.parse(url)).timeout(_timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
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
        }
      } catch (_) {}
      return null;
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chart/birth'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'birthDate': birthDate,
              'birthTime': birthTime,
              'birthPlace': birthPlace,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BirthChartData.fromJson(data);
      } else {
        debugPrint(
          'getBirthChart failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('getBirthChart error: $e');
    }
    return null;
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chart/vedic'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'birthDate': birthDate,
              'birthTime': birthTime,
              'birthPlace': birthPlace,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BirthChartData.fromJson(data);
      } else {
        debugPrint(
          'getVedicChart failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('getVedicChart error: $e');
    }
    return null;
  }

  /// Fetch current planetary transits.
  static Future<List<TransitData>> getTransits() async {
    final url = '$_baseUrl/chart/transits';
    final result = await _dedup<List<TransitData>>(url, () async {
      try {
        final response = await http.get(Uri.parse(url)).timeout(_timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final transits = data['transits'] as List;
          final parsed = transits.map((t) => TransitData.fromJson(t)).toList();
          return parsed.isEmpty ? null : parsed;
        }
      } catch (_) {}
      return null;
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
        final response = await http.get(uri).timeout(_timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return VedicHomeSummaryData.fromJson(data);
        }
      } catch (_) {}
      return null;
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'token': token,
              'platform': platform,
              'zodiacSign': zodiacSign,
              'tradition': tradition,
              'birthDate': birthDate,
              'birthTime': birthTime,
              'birthPlace': birthPlace,
              'dailyHoroscopeEnabled': dailyHoroscopeEnabled,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('registerDeviceToken error: $e');
      return false;
    }
  }

  /// Remove this device's token from the backend (e.g. on sign-out or opt-out).
  static Future<bool> unregisterDeviceToken(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/unregister'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': token}),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('unregisterDeviceToken error: $e');
      return false;
    }
  }

  /// Toggle the daily horoscope reminder for an already-registered device.
  static Future<bool> updateNotificationPreferences({
    required String token,
    required bool dailyHoroscopeEnabled,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/notifications/preferences'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'token': token,
              'dailyHoroscopeEnabled': dailyHoroscopeEnabled,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateNotificationPreferences error: $e');
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/test'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'token': token,
              if (title != null) 'title': title,
              if (body != null) 'body': body,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['sent'] == true;
      }
    } catch (e) {
      debugPrint('sendTestPush error: $e');
    }
    return false;
  }
}
