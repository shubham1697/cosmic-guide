import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// The reading identity resolved for the user's chosen tradition.
///
/// Western (and the default) readings are keyed on the tropical Sun
/// sign. Vedic readings are keyed on the sidereal Moon sign (Janma Rashi),
/// which requires an accurate birth time and place.
class ReadingIdentity {
  /// Sign sent to the horoscope API as `zodiac_sign` and shown as the
  /// headline sign on Home.
  final String readingSign;

  /// The `system` sent to the horoscope API: 'western' or 'vedic'.
  final String system;

  /// True when the user chose Vedic but their Moon sign cannot be computed
  /// because birth time and/or place are missing. The reading falls back to
  /// Western and the UI should nudge the user to add the missing details.
  final bool needsBirthDetailsForVedic;

  const ReadingIdentity({
    required this.readingSign,
    required this.system,
    this.needsBirthDetailsForVedic = false,
  });

  bool get isVedic => system == 'vedic';
}

/// Resolves which sign + system a daily reading should use for a given
/// tradition — the heart of the dual-tradition experience.
///
/// - Western / Both / unknown → tropical Sun sign, `system=western`.
/// - Vedic → sidereal Moon sign (Janma Rashi), `system=vedic`.
///
/// The sidereal Moon sign is a fixed property of the birth, so it is computed
/// once via `/chart/vedic` and cached in SharedPreferences (keyed on the birth
/// inputs); later resolutions are instant and work offline.
/// The reading styles the app supports.
///
/// Profiles saved before the "both" option was removed still carry that value,
/// so every read goes through here and collapses it to western.
String normalizeTradition(String? value) =>
    value == 'vedic' ? 'vedic' : 'western';

class SignResolver {
  static const _moonSignKey = 'vedicMoonSign';
  static const _moonSignInputsKey = 'vedicMoonSignInputs';

  /// Forget the cached Moon sign so the next resolve re-fetches `/chart/vedic`.
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_moonSignKey);
    await prefs.remove(_moonSignInputsKey);
  }

  static Future<ReadingIdentity> resolve({
    required String tradition,
    required String sunSign,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    // Western is the safe default for any value that is not vedic.
    if (tradition != 'vedic') {
      return ReadingIdentity(readingSign: sunSign, system: 'western');
    }

    // A trustworthy Moon sign needs date + time + place. Without them the
    // Janma Rashi can't be fixed, so fall back to Western and flag a nudge.
    final hasBirthData =
        _notBlank(birthDate) && _notBlank(birthTime) && _notBlank(birthPlace);
    if (!hasBirthData) {
      return ReadingIdentity(
        readingSign: sunSign,
        system: 'western',
        needsBirthDetailsForVedic: true,
      );
    }

    final moonSign = await _resolveMoonSign(
      birthDate: birthDate!,
      birthTime: birthTime,
      birthPlace: birthPlace,
    );

    // Birth data was present but the chart couldn't be fetched (e.g. backend
    // offline). Fall back to Western silently — this is transient, not a
    // missing-details problem, so we don't nag the user.
    if (moonSign == null || moonSign.isEmpty) {
      return ReadingIdentity(readingSign: sunSign, system: 'western');
    }

    return ReadingIdentity(readingSign: moonSign, system: 'vedic');
  }

  /// The user's sidereal Moon sign (Janma Rashi), cached after first fetch.
  /// The cache invalidates automatically when any birth input changes.
  static Future<String?> _resolveMoonSign({
    required String birthDate,
    String? birthTime,
    String? birthPlace,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final inputs = '$birthDate|$birthTime|$birthPlace';

    if (prefs.getString(_moonSignInputsKey) == inputs) {
      final cached = prefs.getString(_moonSignKey);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final chart = await ApiService.getVedicChart(
      birthDate: birthDate,
      birthTime: birthTime,
      birthPlace: birthPlace,
    );
    final moonSign = chart?.big3.moonSign;
    if (moonSign != null && moonSign.isNotEmpty) {
      await prefs.setString(_moonSignInputsKey, inputs);
      await prefs.setString(_moonSignKey, moonSign);
    }
    return moonSign;
  }

  static bool _notBlank(String? s) => s != null && s.isNotEmpty;
}
