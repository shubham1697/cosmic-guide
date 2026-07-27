import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

/// A short, friendly guide that explains why a person's Western and Vedic
/// signs differ, plus a glossary of the Jyotish (and Western) terms used
/// throughout CosmicGuide. Read-only and reachable from Profile.
class AstroGlossaryScreen extends StatelessWidget {
  const AstroGlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Astrology Guide',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: StarryBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A quick guide to the two traditions CosmicGuide blends — '
                  'and the words you\'ll see along the way.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                _sectionTitle('Why your two signs differ'),
                const SizedBox(height: 12),
                _whyDifferCard(),
                const SizedBox(height: 28),

                _sectionTitle('Jyotish terms'),
                const SizedBox(height: 12),
                ..._jyotishTerms.map(_termCard),
                const SizedBox(height: 16),

                _sectionTitle('Western terms'),
                const SizedBox(height: 12),
                ..._westernTerms.map(_termCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.accent,
      ),
    );
  }

  Widget _whyDifferCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        border: Border.all(color: AppColors.mysticTeal.withAlpha(90)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                color: AppColors.mysticTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tropical vs. sidereal',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Western astrology uses the tropical zodiac, tied to the seasons '
            '(0° Aries = the spring equinox). Vedic astrology (Jyotish) uses '
            'the sidereal zodiac, tied to the fixed stars. Over centuries the '
            'two have drifted about 24° apart — an offset called the ayanamsa '
            '(CosmicGuide uses the Lahiri ayanamsa, India\'s standard).',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Because of that gap, your Vedic Sun is often the previous sign '
            'from your Western Sun. In CosmicGuide your Western daily reading '
            'is keyed on your tropical Sun sign, while your Vedic reading is '
            'keyed on your sidereal Moon sign (Janma Rashi) — the heart of '
            'Jyotish.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _termCard(_Term term) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withAlpha(46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                term.term,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (term.also != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    term.also!,
                    style: const TextStyle(
                      color: AppColors.mysticTeal,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            term.definition,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Term {
  final String term;
  final String? also;
  final String definition;
  const _Term(this.term, this.definition, {this.also});
}

const List<_Term> _jyotishTerms = [
  _Term(
    'Rashi',
    'Your zodiac sign in the sidereal system. Your Moon rashi (Janma Rashi) '
        'anchors your Vedic daily reading.',
    also: 'sign',
  ),
  _Term(
    'Lagna',
    'The ascendant — the sign rising on the eastern horizon at your birth. '
        'It forms the 1st house of your kundli.',
    also: 'ascendant / rising',
  ),
  _Term(
    'Graha',
    'A "planet" in Jyotish. The nine grahas are the Sun, Moon, Mars, Mercury, '
        'Jupiter, Venus, Saturn, and the lunar nodes Rahu & Ketu.',
    also: 'planet',
  ),
  _Term(
    'Nakshatra',
    'One of the 27 lunar mansions the Moon travels through. Your birth '
        '(Janma) Nakshatra shapes personality and timing.',
    also: 'lunar mansion',
  ),
  _Term(
    'Dasha',
    'A planetary period. The Vimshottari Dasha maps your life into '
        'graha-ruled chapters, calculated from your birth Moon.',
    also: 'planetary period',
  ),
  _Term(
    'Kundli',
    'Your Vedic birth chart, drawn as a North Indian (diamond) or South '
        'Indian (grid) diagram.',
    also: 'birth chart',
  ),
  _Term(
    'Gochara',
    'Transits — where the grahas are moving today, relative to your birth '
        'chart.',
    also: 'transits',
  ),
  _Term(
    'Ayanamsa',
    'The ~24° gap between the tropical and sidereal zodiacs. CosmicGuide '
        'uses the Lahiri ayanamsa.',
  ),
  _Term(
    'Panchang',
    'The Vedic almanac for a day: Tithi, Vara, Nakshatra, Yoga, and Karana.',
    also: 'almanac',
  ),
];

const List<_Term> _westernTerms = [
  _Term(
    'Sun',
    'Your core identity and ego. The basis of your Western daily horoscope.',
  ),
  _Term(
    'Moon',
    'Your emotions and inner world. In Jyotish the Moon\'s rashi is your '
        'primary sign.',
  ),
  _Term(
    'Rising',
    'How you meet the world — the sign rising at your birth. Called the '
        'Lagna in Jyotish.',
    also: 'ascendant / Lagna',
  ),
];
