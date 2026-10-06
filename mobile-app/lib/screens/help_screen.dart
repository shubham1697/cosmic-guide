import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';
import 'astro_glossary_screen.dart';

/// Support address shown on this screen. Update when a real inbox exists.
const String kSupportEmail = 'support@cosmicguide.app';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

const List<_Faq> _faqs = [
  _Faq(
    'Why is my Vedic sign different from my Western sign?',
    'Western astrology uses the tropical zodiac, which is tied to the seasons. '
        'Vedic (Jyotish) uses the sidereal zodiac, tied to the fixed stars. The '
        'two have drifted roughly 24° apart, so your Vedic Sun is usually the '
        'previous sign. CosmicGuide also keys your Vedic reading on the Moon '
        'sign (Janma Rashi), not the Sun — that is the traditional approach.',
  ),
  _Faq(
    'Why does the app ask for my birth time and place?',
    'The Moon moves about one degree every two hours and the Ascendant changes '
        'every two hours, so without an accurate time and place we cannot work '
        'out your Moon sign, Lagna, houses or nakshatra. Readings still work '
        'without them — they are just general to your sign rather than to your '
        'chart.',
  ),
  _Faq(
    'What makes a reading "personalised"?',
    'When your birth details are saved, your daily reading is built from your '
        'real natal chart and the planetary positions for today, including the '
        'aspects between them. The percentage you see is calculated from those '
        'aspects, not written by the AI.',
  ),
  _Faq(
    'Where does the astrology data come from?',
    'Planetary positions come from the Swiss Ephemeris, the same engine used '
        'by professional astrology software. Panchang, Vimshottari Dasha, '
        'doshas and Ashta Koota matching are computed from those positions '
        'using classical rules.',
  ),
  _Faq(
    'My daily reminder is not arriving',
    'Check Notifications in the app and make sure the reminder is on. If the '
        'switch will not stay on, notifications are blocked for CosmicGuide in '
        'your device settings. On some Android phones battery optimisation can '
        'also delay reminders.',
  ),
  _Faq(
    'How do I change my birth details or reading style?',
    'Open Profile and tap Edit. You can update your name, birth date, time, '
        'place and whether you read Western, Vedic or both. Your readings '
        'refresh straight away.',
  ),
  _Faq(
    'Is my data private?',
    'Your name, birth details and reading history are stored on this device '
        'only. Birth details are sent to the CosmicGuide server when a chart '
        'needs to be calculated, and are not linked to an account. You can '
        'erase everything from Settings → Delete all app data.',
  ),
];

/// Help & Support: FAQs, a way to reach support, and a pointer to the glossary.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Help & Support', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _sectionTitle('Frequently asked'),
            const SizedBox(height: 8),
            Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                // Keeps the expansion divider from fighting the card edges.
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Column(
                  children: [
                    for (var i = 0; i < _faqs.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.textMuted.withAlpha(30),
                        ),
                      _FaqTile(faq: _faqs[i]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Learn the terms'),
            const SizedBox(height: 8),
            _LinkCard(
              icon: Icons.menu_book_outlined,
              color: AppColors.mysticTeal,
              title: 'Astrology Guide',
              subtitle: 'Tropical vs sidereal, Jyotish and Western terms',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AstroGlossaryScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Still stuck?'),
            const SizedBox(height: 8),
            _ContactCard(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;

  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      iconColor: AppColors.accent,
      collapsedIconColor: AppColors.textMuted,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        faq.question,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Text(
          faq.answer,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, color: AppColors.accent, size: 22),
              const SizedBox(width: 12),
              Text(
                'Email support',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tell us what happened and include your birth date, time and place '
            'if the question is about a reading.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  kSupportEmail,
                  style: GoogleFonts.poppins(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: kSupportEmail),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email address copied.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
