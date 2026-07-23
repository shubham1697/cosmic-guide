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

class HouseCusp {
  final int house;
  final double cuspLongitude;
  final String sign;
  final double degreeInSign;
  final String degreeDisplay;

  const HouseCusp({
    required this.house,
    required this.cuspLongitude,
    required this.sign,
    required this.degreeInSign,
    required this.degreeDisplay,
  });

  factory HouseCusp.fromJson(Map<String, dynamic> json) {
    return HouseCusp(
      house: json['house'] ?? 1,
      cuspLongitude: (json['cuspLongitude'] ?? 0).toDouble(),
      sign: json['sign'] ?? '',
      degreeInSign: (json['degreeInSign'] ?? 0).toDouble(),
      degreeDisplay: json['degreeDisplay'] ?? '',
    );
  }
}

class BirthChartData {
  final List<PlanetPosition> planets;
  final Big3Data big3;
  final NakshatraData moonNakshatra;
  final List<AspectData> aspects;
  final List<HouseCusp> houses;
  final bool hasAccurateHouses;
  final double? ascendantLongitude;
  final double? midheavenLongitude;

  const BirthChartData({
    required this.planets,
    required this.big3,
    required this.moonNakshatra,
    required this.aspects,
    required this.houses,
    required this.hasAccurateHouses,
    this.ascendantLongitude,
    this.midheavenLongitude,
  });

  factory BirthChartData.fromJson(Map<String, dynamic> json) {
    final ascendant = json['ascendant'];
    final midheaven = json['midheaven'];
    return BirthChartData(
      planets: (json['planets'] as List? ?? [])
          .map((p) => PlanetPosition.fromJson(p))
          .toList(),
      big3: Big3Data.fromJson(json['big3'] ?? {}),
      moonNakshatra: NakshatraData.fromJson(json['moonNakshatra'] ?? {}),
      aspects: (json['aspects'] as List? ?? [])
          .map((a) => AspectData.fromJson(a))
          .toList(),
      houses: (json['houses'] as List? ?? [])
          .map((h) => HouseCusp.fromJson(h))
          .toList(),
      hasAccurateHouses: json['hasAccurateHouses'] ?? false,
      ascendantLongitude: ascendant is Map
          ? (ascendant['longitude'] as num?)?.toDouble()
          : null,
      midheavenLongitude: midheaven is Map
          ? (midheaven['longitude'] as num?)?.toDouble()
          : null,
    );
  }
}

class VedicLocationData {
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;

  const VedicLocationData({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  factory VedicLocationData.fromJson(Map<String, dynamic> json) {
    return VedicLocationData(
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      timezone: (json['timezone'] ?? '').toString(),
    );
  }
}

class PanchangSummaryData {
  final String date;
  final String vara;
  final String varaRuler;
  final String tithi;
  final String paksha;
  final String nakshatra;
  final String yoga;
  final String karana;
  final String insight;

  const PanchangSummaryData({
    required this.date,
    required this.vara,
    required this.varaRuler,
    required this.tithi,
    required this.paksha,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.insight,
  });

  factory PanchangSummaryData.fromJson(Map<String, dynamic> json) {
    return PanchangSummaryData(
      date: (json['date'] ?? '').toString(),
      vara: (json['vara'] ?? '').toString(),
      varaRuler: (json['varaRuler'] ?? '').toString(),
      tithi: (json['tithi'] ?? '').toString(),
      paksha: (json['paksha'] ?? '').toString(),
      nakshatra: (json['nakshatra'] ?? '').toString(),
      yoga: (json['yoga'] ?? '').toString(),
      karana: (json['karana'] ?? '').toString(),
      insight: (json['insight'] ?? '').toString(),
    );
  }
}

class VedicCalendarData {
  final String monthName;
  final int samvatYear;
  final String nextFestivalName;
  final String nextFestivalDate;
  final String note;

  const VedicCalendarData({
    required this.monthName,
    required this.samvatYear,
    required this.nextFestivalName,
    required this.nextFestivalDate,
    required this.note,
  });

  factory VedicCalendarData.fromJson(Map<String, dynamic> json) {
    return VedicCalendarData(
      monthName: (json['monthName'] ?? '').toString(),
      samvatYear: (json['samvatYear'] ?? 0) as int,
      nextFestivalName: (json['nextFestivalName'] ?? '').toString(),
      nextFestivalDate: (json['nextFestivalDate'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class MuhurtaSummaryData {
  final String label;
  final String startsAt;
  final String endsAt;
  final String note;

  const MuhurtaSummaryData({
    required this.label,
    required this.startsAt,
    required this.endsAt,
    required this.note,
  });

  factory MuhurtaSummaryData.fromJson(Map<String, dynamic> json) {
    return MuhurtaSummaryData(
      label: (json['label'] ?? '').toString(),
      startsAt: (json['startsAt'] ?? '').toString(),
      endsAt: (json['endsAt'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class DailyTimingsData {
  final String sunrise;
  final String sunset;
  final String dayLength;
  final String abhijit;
  final String brahmaMuhurta;
  final String rahuKaal;
  final String yamaganda;
  final String gulika;

  const DailyTimingsData({
    required this.sunrise,
    required this.sunset,
    required this.dayLength,
    required this.abhijit,
    required this.brahmaMuhurta,
    required this.rahuKaal,
    required this.yamaganda,
    required this.gulika,
  });

  factory DailyTimingsData.fromJson(Map<String, dynamic> json) {
    String field(String key) => (json[key] ?? '—').toString();
    return DailyTimingsData(
      sunrise: field('sunrise'),
      sunset: field('sunset'),
      dayLength: field('dayLength'),
      abhijit: field('abhijit'),
      brahmaMuhurta: field('brahmaMuhurta'),
      rahuKaal: field('rahuKaal'),
      yamaganda: field('yamaganda'),
      gulika: field('gulika'),
    );
  }
}

class KundliSummaryData {
  final String lagna;
  final String moonSign;
  final String nakshatra;
  final String note;

  const KundliSummaryData({
    required this.lagna,
    required this.moonSign,
    required this.nakshatra,
    required this.note,
  });

  factory KundliSummaryData.fromJson(Map<String, dynamic> json) {
    return KundliSummaryData(
      lagna: (json['lagna'] ?? '').toString(),
      moonSign: (json['moonSign'] ?? '').toString(),
      nakshatra: (json['nakshatra'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class DashaSummaryData {
  final String mahadasha;
  final String mahadashaEndsOn;
  final String antardasha;
  final String guidance;

  const DashaSummaryData({
    required this.mahadasha,
    required this.mahadashaEndsOn,
    required this.antardasha,
    required this.guidance,
  });

  factory DashaSummaryData.fromJson(Map<String, dynamic> json) {
    return DashaSummaryData(
      mahadasha: (json['mahadasha'] ?? '').toString(),
      mahadashaEndsOn: (json['mahadashaEndsOn'] ?? '').toString(),
      antardasha: (json['antardasha'] ?? '').toString(),
      guidance: (json['guidance'] ?? '').toString(),
    );
  }
}

class DoshaSummaryData {
  final int activeCount;
  final List<String> topDoshas;
  final String summary;

  const DoshaSummaryData({
    required this.activeCount,
    required this.topDoshas,
    required this.summary,
  });

  factory DoshaSummaryData.fromJson(Map<String, dynamic> json) {
    return DoshaSummaryData(
      activeCount: (json['activeCount'] ?? 0) as int,
      topDoshas: (json['topDoshas'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      summary: (json['summary'] ?? '').toString(),
    );
  }
}

class RemedySummaryData {
  final String focus;
  final String gemstone;
  final String mantra;
  final String fastingDay;
  final String guidance;

  const RemedySummaryData({
    required this.focus,
    required this.gemstone,
    required this.mantra,
    required this.fastingDay,
    required this.guidance,
  });

  factory RemedySummaryData.fromJson(Map<String, dynamic> json) {
    return RemedySummaryData(
      focus: (json['focus'] ?? '').toString(),
      gemstone: (json['gemstone'] ?? '').toString(),
      mantra: (json['mantra'] ?? '').toString(),
      fastingDay: (json['fastingDay'] ?? '').toString(),
      guidance: (json['guidance'] ?? '').toString(),
    );
  }
}

class VedicHomeSummaryData {
  final VedicLocationData location;
  final PanchangSummaryData panchang;
  final VedicCalendarData calendar;
  final MuhurtaSummaryData muhurta;
  final DailyTimingsData timings;
  final KundliSummaryData? kundli;
  final DashaSummaryData? dasha;
  final DoshaSummaryData? dosha;
  final RemedySummaryData? remedy;

  const VedicHomeSummaryData({
    required this.location,
    required this.panchang,
    required this.calendar,
    required this.muhurta,
    required this.timings,
    this.kundli,
    this.dasha,
    this.dosha,
    this.remedy,
  });

  factory VedicHomeSummaryData.fromJson(Map<String, dynamic> json) {
    return VedicHomeSummaryData(
      location: VedicLocationData.fromJson(json['location'] ?? {}),
      panchang: PanchangSummaryData.fromJson(json['panchang'] ?? {}),
      calendar: VedicCalendarData.fromJson(json['calendar'] ?? {}),
      muhurta: MuhurtaSummaryData.fromJson(json['muhurta'] ?? {}),
      timings: DailyTimingsData.fromJson(json['timings'] ?? {}),
      kundli: json['kundli'] == null
          ? null
          : KundliSummaryData.fromJson(json['kundli']),
      dasha: json['dasha'] == null
          ? null
          : DashaSummaryData.fromJson(json['dasha']),
      dosha: json['dosha'] == null
          ? null
          : DoshaSummaryData.fromJson(json['dosha']),
      remedy: json['remedy'] == null
          ? null
          : RemedySummaryData.fromJson(json['remedy']),
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
