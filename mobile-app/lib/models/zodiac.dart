import 'package:flutter/material.dart';

class ZodiacSign {
  final String name;
  final String symbol;
  final String element;
  final String dateRange;
  final String rulingPlanet;
  final IconData icon;

  const ZodiacSign({
    required this.name,
    required this.symbol,
    required this.element,
    required this.dateRange,
    required this.rulingPlanet,
    required this.icon,
  });
}

class TarotCard {
  final String name;
  final String number;
  final String meaning;
  final String interpretation;
  final String reversedInterpretation;
  final bool isReversed;

  const TarotCard({
    required this.name,
    required this.number,
    required this.meaning,
    required this.interpretation,
    this.reversedInterpretation = '',
    this.isReversed = false,
  });
}

class HoroscopeData {
  final String sign;
  final String date;
  final String general;
  final String love;
  final String career;
  final String health;
  final int overallScore;
  final String luckyNumber;
  final String luckyColor;
  final String mood;

  const HoroscopeData({
    required this.sign,
    required this.date,
    required this.general,
    required this.love,
    required this.career,
    required this.health,
    required this.overallScore,
    required this.luckyNumber,
    required this.luckyColor,
    required this.mood,
  });
}

class CompatibilityResult {
  final String sign1;
  final String sign2;
  final int score;
  final String description;
  final String loveAdvice;
  final String strengthsTogether;
  final String challenges;

  const CompatibilityResult({
    required this.sign1,
    required this.sign2,
    required this.score,
    required this.description,
    required this.loveAdvice,
    required this.strengthsTogether,
    required this.challenges,
  });
}

class KundliResult {
  final int totalScore;
  final int maxScore;
  final Map<String, int> kootaScores;
  final String compatibility;
  final String analysis;
  final bool hasManglikDosha;

  const KundliResult({
    required this.totalScore,
    required this.maxScore,
    required this.kootaScores,
    required this.compatibility,
    required this.analysis,
    required this.hasManglikDosha,
  });
}

class AstrologyStory {
  final String title;
  final String summary;
  final String category;
  final String readTime;
  final String content;

  const AstrologyStory({
    required this.title,
    required this.summary,
    required this.category,
    required this.readTime,
    required this.content,
  });
}

class PlanetPosition {
  final String name;
  final String symbol;
  final double longitude;
  final String sign;
  final String signSymbol;
  final double degreeInSign;
  final String degreeDisplay;
  final bool isRetrograde;
  final String? placement;

  const PlanetPosition({
    required this.name,
    required this.symbol,
    required this.longitude,
    required this.sign,
    required this.signSymbol,
    required this.degreeInSign,
    required this.degreeDisplay,
    required this.isRetrograde,
    this.placement,
  });

  factory PlanetPosition.fromJson(Map<String, dynamic> json) {
    return PlanetPosition(
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      longitude: (json['longitude'] ?? 0).toDouble(),
      sign: json['sign'] ?? '',
      signSymbol: json['signSymbol'] ?? '',
      degreeInSign: (json['degreeInSign'] ?? 0).toDouble(),
      degreeDisplay: json['degreeDisplay'] ?? '',
      isRetrograde: json['isRetrograde'] ?? false,
    );
  }
}

class Big3Data {
  final String sunSign;
  final String sunDegree;
  final String moonSign;
  final String moonDegree;
  final String risingSign;
  final String risingDegree;
  final bool risingIsEstimated;

  const Big3Data({
    required this.sunSign,
    required this.sunDegree,
    required this.moonSign,
    required this.moonDegree,
    required this.risingSign,
    required this.risingDegree,
    required this.risingIsEstimated,
  });

  factory Big3Data.fromJson(Map<String, dynamic> json) {
    final sun = json['sun'] ?? {};
    final moon = json['moon'] ?? {};
    final rising = json['rising'] ?? {};
    return Big3Data(
      sunSign: sun['sign'] ?? '',
      sunDegree: sun['degree'] ?? '',
      moonSign: moon['sign'] ?? '',
      moonDegree: moon['degree'] ?? '',
      risingSign: rising['sign'] ?? '',
      risingDegree: rising['degree'] ?? '',
      risingIsEstimated: rising['isEstimated'] ?? true,
    );
  }
}

class AspectData {
  final String planet1;
  final String planet2;
  final String aspect;
  final double angle;
  final double orb;

  const AspectData({
    required this.planet1,
    required this.planet2,
    required this.aspect,
    required this.angle,
    required this.orb,
  });

  factory AspectData.fromJson(Map<String, dynamic> json) {
    return AspectData(
      planet1: json['planet1'] ?? '',
      planet2: json['planet2'] ?? '',
      aspect: json['aspect'] ?? '',
      angle: (json['angle'] ?? 0).toDouble(),
      orb: (json['orb'] ?? 0).toDouble(),
    );
  }
}

class NakshatraData {
  final String name;
  final int pada;
  final String lord;

  const NakshatraData({
    required this.name,
    required this.pada,
    required this.lord,
  });

  factory NakshatraData.fromJson(Map<String, dynamic> json) {
    return NakshatraData(
      name: json['name'] ?? '',
      pada: json['pada'] ?? 1,
      lord: json['lord'] ?? '',
    );
  }
}

class BirthChartData {
  final List<PlanetPosition> planets;
  final Big3Data big3;
  final NakshatraData moonNakshatra;
  final List<AspectData> aspects;
  final bool hasAccurateHouses;

  const BirthChartData({
    required this.planets,
    required this.big3,
    required this.moonNakshatra,
    required this.aspects,
    required this.hasAccurateHouses,
  });

  factory BirthChartData.fromJson(Map<String, dynamic> json) {
    return BirthChartData(
      planets: (json['planets'] as List? ?? [])
          .map((p) => PlanetPosition.fromJson(p))
          .toList(),
      big3: Big3Data.fromJson(json['big3'] ?? {}),
      moonNakshatra: NakshatraData.fromJson(json['moonNakshatra'] ?? {}),
      aspects: (json['aspects'] as List? ?? [])
          .map((a) => AspectData.fromJson(a))
          .toList(),
      hasAccurateHouses: json['hasAccurateHouses'] ?? false,
    );
  }
}

class TransitData {
  final String name;
  final String symbol;
  final String sign;
  final String degreeDisplay;
  final bool isRetrograde;

  const TransitData({
    required this.name,
    required this.symbol,
    required this.sign,
    required this.degreeDisplay,
    required this.isRetrograde,
  });

  factory TransitData.fromJson(Map<String, dynamic> json) {
    return TransitData(
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      sign: json['sign'] ?? '',
      degreeDisplay: json['degreeDisplay'] ?? '',
      isRetrograde: json['isRetrograde'] ?? false,
    );
  }
}
