/// Barrel file — re-exports all mock data from split files and provides
/// the original [MockData] façade so existing imports keep working.
library;

import '../models/zodiac.dart';

export 'zodiac_signs_data.dart';
export 'tarot_deck_data.dart';
export 'horoscope_mock_data.dart';
export 'compatibility_mock_data.dart';
export 'kundli_mock_data.dart';
export 'stories_mock_data.dart';
export 'fortune_mock_data.dart';

// Re-export through the old MockData class so call-sites like
// MockData.zodiacSigns, MockData.getHoroscope(...) etc. still compile.
import 'zodiac_signs_data.dart' as zd;
import 'tarot_deck_data.dart' as td;
import 'horoscope_mock_data.dart' as hd;
import 'compatibility_mock_data.dart' as cd;
import 'kundli_mock_data.dart' as kd;
import 'stories_mock_data.dart' as sd;
import 'fortune_mock_data.dart' as fd;

class MockData {
  static List<ZodiacSign> get zodiacSigns => zd.zodiacSigns;
  static List<TarotCard> get tarotDeck => td.tarotDeck;
  static HoroscopeData getHoroscope(String sign) => hd.getHoroscope(sign);
  static CompatibilityResult getCompatibility(String sign1, String sign2) =>
      cd.getCompatibility(sign1, sign2);
  static KundliResult getKundliResult() => kd.getKundliResult();
  static List<AstrologyStory> get stories => sd.stories;
  static List<String> get fortuneTopics => fd.fortuneTopics;
  static List<String> get moods => fd.moods;
  static List<String> get fortunes => fd.fortunes;
}
