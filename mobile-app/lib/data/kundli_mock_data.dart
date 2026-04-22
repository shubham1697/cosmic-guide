import '../models/zodiac.dart';

KundliResult getKundliResult() {
  return const KundliResult(
    totalScore: 26,
    maxScore: 36,
    kootaScores: {
      'Varna': 1,
      'Vashya': 2,
      'Tara': 3,
      'Yoni': 4,
      'Graha Maitri': 5,
      'Gana': 6,
      'Bhakoot': 3,
      'Nadi': 2,
    },
    compatibility: 'Good',
    analysis:
        'The Gun Milan score indicates good compatibility between the two individuals. The planetary alignments suggest a harmonious relationship with strong emotional and spiritual bonds. Minor challenges in the Nadi koota can be mitigated through understanding and mutual respect.',
    hasManglikDosha: false,
  );
}
