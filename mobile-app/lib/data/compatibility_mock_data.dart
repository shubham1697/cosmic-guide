import '../models/zodiac.dart';
import 'zodiac_signs_data.dart';

CompatibilityResult getCompatibility(String sign1, String sign2) {
  final scores = {
    'Fire-Fire': 80,
    'Fire-Air': 85,
    'Fire-Earth': 55,
    'Fire-Water': 50,
    'Air-Fire': 85,
    'Air-Air': 75,
    'Air-Earth': 60,
    'Air-Water': 65,
    'Earth-Fire': 55,
    'Earth-Air': 60,
    'Earth-Earth': 90,
    'Earth-Water': 85,
    'Water-Fire': 50,
    'Water-Air': 65,
    'Water-Earth': 85,
    'Water-Water': 80,
  };

  final e1 = zodiacSigns.firstWhere((z) => z.name == sign1).element;
  final e2 = zodiacSigns.firstWhere((z) => z.name == sign2).element;
  final score = scores['$e1-$e2'] ?? 70;

  return CompatibilityResult(
    sign1: sign1,
    sign2: sign2,
    score: score,
    description: score >= 80
        ? 'An excellent cosmic match! You two share a deep, natural connection that flows effortlessly.'
        : score >= 60
        ? 'A promising pairing with room to grow. Your differences complement each other beautifully when embraced.'
        : 'A challenging but potentially transformative match. Growth comes through understanding your differences.',
    loveAdvice: score >= 80
        ? 'Nurture your bond with shared experiences and open communication. Your connection is truly special.'
        : 'Focus on understanding each other\'s needs. Patience and compromise strengthen your bond.',
    strengthsTogether: score >= 80
        ? 'Mutual understanding, shared values, natural chemistry'
        : 'Complementary perspectives, opportunities for growth, dynamic energy',
    challenges: score >= 80
        ? 'Avoid complacency — keep the spark alive through new adventures together.'
        : 'Different communication styles may cause misunderstandings. Practice active listening.',
  );
}
