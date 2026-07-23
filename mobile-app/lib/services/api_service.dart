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

  /// Fetch today's horoscope for a sign. Returns null on failure.
  static Future<HoroscopeData?> getHoroscope(String sign) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/horoscope/today?zodiac_sign=$sign'))
          .timeout(_timeout);
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
        );
      }
    } catch (_) {}
    return null;
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
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/stories'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stories = data['stories'] as List;
        return stories
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
      }
    } catch (_) {}
    return [];
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
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/chart/transits'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final transits = data['transits'] as List;
        return transits.map((t) => TransitData.fromJson(t)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch Vedic hub summary data. Returns null on failure.
  static Future<VedicHomeSummaryData?> getVedicHomeSummary({
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    try {
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
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return VedicHomeSummaryData.fromJson(data);
      }
    } catch (_) {}
    return null;
  }
}
