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
