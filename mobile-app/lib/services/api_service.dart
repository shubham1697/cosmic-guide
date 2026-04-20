import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/zodiac.dart';
import '../data/mock_data.dart';

class ApiService {
  // Local backend (Docker): use 10.0.2.2 for Android emulator, localhost for iOS/web
  static const String _baseUrl = 'http://localhost:8000/api/v1';

  // Render free tier can take 15-30s to cold-start; use a generous timeout.
  static const _timeout = Duration(seconds: 20);

  /// Fetch today's horoscope for a sign. Falls back to mock data on failure.
  static Future<HoroscopeData> getHoroscope(String sign) async {
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
    return MockData.getHoroscope(sign);
  }

  /// Draw a random tarot card. Falls back to mock data on failure.
  static Future<({TarotCard card, bool isReversed})> drawTarotCard() async {
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
    // Fallback: use local mock data
    return _drawLocalTarotCard();
  }

  static ({TarotCard card, bool isReversed}) _drawLocalTarotCard() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final card = MockData.tarotDeck[random % MockData.tarotDeck.length];
    final isReversed = (random % 10) < 3; // ~30% chance
    return (card: card, isReversed: isReversed);
  }

  /// Generate a fortune. Falls back to mock data on failure.
  static Future<String> generateFortune(
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
    // Fallback: random local fortune
    final random = DateTime.now().millisecondsSinceEpoch;
    return MockData.fortunes[random % MockData.fortunes.length];
  }

  /// Check compatibility between two signs. Falls back to mock data on failure.
  static Future<CompatibilityResult> checkCompatibility(
    String sign1,
    String sign2,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/compatibility/check'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'sign1': sign1, 'sign2': sign2}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CompatibilityResult(
          sign1: data['sign1'],
          sign2: data['sign2'],
          score: data['score'],
          description: data['description'],
          loveAdvice: data['loveAdvice'],
          strengthsTogether: data['strengthsTogether'],
          challenges: data['challenges'],
        );
      }
    } catch (_) {}
    return MockData.getCompatibility(sign1, sign2);
  }

  /// Calculate Kundli matching. Falls back to mock data on failure.
  static Future<KundliResult> calculateKundli({
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
    return MockData.getKundliResult();
  }

  /// Fetch cosmic stories. Falls back to mock data on failure.
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
    return MockData.stories;
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
      }
    } catch (_) {}
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
}
