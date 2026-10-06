import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

class _Perk {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Perk(this.icon, this.color, this.title, this.subtitle);
}

const List<_Perk> _perks = [
  _Perk(
    Icons.description_outlined,
    AppColors.accent,
    'Full birth chart report',
    'Every placement, house and aspect written up, saved as a PDF you can keep.',
  ),
  _Perk(
    Icons.favorite_outline,
    AppColors.love,
    'Deep compatibility breakdown',
    'Separate love, friendship and work scores instead of a single number.',
  ),
  _Perk(
    Icons.spa_outlined,
    AppColors.mysticTeal,
    'Full Kundli match report',
    'All eight kootas explained, dosha analysis and classical remedies, ready to share.',
  ),
  _Perk(
    Icons.insights_outlined,
    AppColors.purple,
    'Year-ahead forecast',
    'Your energy forecast extended from 30 days to a full twelve months.',
  ),
  _Perk(
    Icons.auto_awesome_outlined,
    AppColors.accent,
    'Ask the Oracle',
    'Ask anything and get an answer read from your own chart.',
  ),
];

/// Premium preview. Nothing is purchasable yet, so this screen is explicit
/// about that and only collects an opt-in for launch news.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _optInKey = 'premium_notify_optin';

  bool _notifyMe = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyMe = prefs.getBool(_optInKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _notifyMe = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optInKey, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'We\'ll let you know when Premium opens up.'
              : 'You won\'t be notified about Premium.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Premium', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildHero(),
                  const SizedBox(height: 24),
                  Text(
                    'What Premium will unlock',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final perk in _perks) ...[
                    _buildPerk(perk),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  _buildOptIn(),
                  const SizedBox(height: 16),
                  const Text(
                    'Everything in CosmicGuide today stays free. You will not '
                    'be charged, and no payment details are collected on this '
                    'screen.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.gradientGold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: AppColors.primary,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CosmicGuide Premium',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Coming soon',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The deeper reports we are building — written from your own chart, '
            'not a generic sign description.',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerk(_Perk perk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(perk.icon, color: perk.color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perk.title,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  perk.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptIn() {
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.accent.withAlpha(60)),
      ),
      child: SwitchListTile(
        value: _notifyMe,
        onChanged: _toggle,
        activeThumbColor: AppColors.accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          'Tell me when Premium launches',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'One notification, nothing else.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}
