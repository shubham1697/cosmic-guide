import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/starry_background.dart';

class ProfileScreen extends StatelessWidget {
  final String userSign;
  final String userName;

  const ProfileScreen({
    super.key,
    required this.userSign,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final sign = MockData.zodiacSigns.firstWhere((z) => z.name == userSign);

    return StarryBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAvatar(sign),
              const SizedBox(height: 16),
              Text(
                userName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sign.name} ${sign.symbol} | ${sign.dateRange}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildPersonalitySection(sign),
              const SizedBox(height: 24),
              _buildSignDetails(sign),
              const SizedBox(height: 24),
              _buildPremiumCard(),
              const SizedBox(height: 24),
              _buildMenuItems(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(dynamic sign) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradientPurple,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withAlpha(102),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(sign.symbol, style: const TextStyle(fontSize: 44)),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStat('Readings', '24'),
        Container(
          width: 1,
          height: 40,
          color: AppColors.textMuted.withAlpha(51),
        ),
        _buildStat('Streak', '7 days'),
        Container(
          width: 1,
          height: 40,
          color: AppColors.textMuted.withAlpha(51),
        ),
        _buildStat('Fortune', '12'),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPersonalitySection(dynamic sign) {
    final traits = _getTraits(sign.name);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personality Traits',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTraitRow('Strengths', traits['strengths']!, AppColors.health),
          const SizedBox(height: 12),
          _buildTraitRow('Weaknesses', traits['weaknesses']!, AppColors.love),
          const SizedBox(height: 12),
          _buildTraitRow(
            'Emotional',
            traits['emotional']!,
            AppColors.mysticTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildTraitRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignDetails(dynamic sign) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.water_drop, 'Element', sign.element),
          const Divider(color: AppColors.surface, height: 24),
          _buildDetailRow(Icons.public, 'Ruling Planet', sign.rulingPlanet),
          const Divider(color: AppColors.surface, height: 24),
          _buildDetailRow(Icons.calendar_today, 'Date Range', sign.dateRange),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientGold,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Unlock advanced reports & unlimited readings',
                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: AppColors.primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final items = [
      _MenuItem(
        Icons.notifications_outlined,
        'Notifications',
        AppColors.accent,
      ),
      _MenuItem(Icons.history, 'Reading History', AppColors.purple),
      _MenuItem(Icons.settings_outlined, 'Settings', AppColors.textSecondary),
      _MenuItem(Icons.help_outline, 'Help & Support', AppColors.mysticTeal),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(item.icon, color: item.color),
            title: Text(
              item.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<String, String> _getTraits(String sign) {
    final allTraits = {
      'Aries': {
        'strengths': 'Courageous, determined, confident, enthusiastic',
        'weaknesses': 'Impatient, moody, aggressive',
        'emotional': 'Passionate and direct with feelings',
      },
      'Taurus': {
        'strengths': 'Reliable, patient, devoted, stable',
        'weaknesses': 'Stubborn, possessive, uncompromising',
        'emotional': 'Deep and steady emotional connections',
      },
      'Gemini': {
        'strengths': 'Versatile, curious, witty, communicative',
        'weaknesses': 'Inconsistent, restless, superficial',
        'emotional': 'Expressive yet guarded, processes feelings through words',
      },
      'Cancer': {
        'strengths': 'Nurturing, protective, loyal, empathetic',
        'weaknesses': 'Overly sensitive, clingy, moody',
        'emotional': 'Deeply intuitive with powerful emotional memory',
      },
      'Leo': {
        'strengths': 'Generous, warm-hearted, creative, charismatic',
        'weaknesses': 'Arrogant, stubborn, attention-seeking',
        'emotional': 'Wears heart on sleeve, needs admiration and loyalty',
      },
      'Virgo': {
        'strengths': 'Analytical, practical, diligent, detail-oriented',
        'weaknesses': 'Overly critical, perfectionist, anxious',
        'emotional': 'Reserved on the surface but deeply caring underneath',
      },
      'Libra': {
        'strengths': 'Diplomatic, gracious, fair-minded, social',
        'weaknesses': 'Indecisive, avoids confrontation, people-pleasing',
        'emotional': 'Seeks harmony in all relationships, dislikes conflict',
      },
      'Scorpio': {
        'strengths': 'Resourceful, brave, passionate, loyal',
        'weaknesses': 'Jealous, secretive, dominating',
        'emotional': 'Intensely emotional and deeply intuitive',
      },
      'Sagittarius': {
        'strengths': 'Optimistic, adventurous, honest, philosophical',
        'weaknesses': 'Tactless, impatient, overconfident',
        'emotional':
            'Free-spirited, avoids heavy emotions but deeply idealistic',
      },
      'Capricorn': {
        'strengths': 'Disciplined, ambitious, responsible, patient',
        'weaknesses': 'Pessimistic, rigid, workaholic tendencies',
        'emotional': 'Guarded but fiercely loyal once trust is earned',
      },
      'Aquarius': {
        'strengths': 'Progressive, original, independent, humanitarian',
        'weaknesses': 'Emotionally detached, unpredictable, aloof',
        'emotional': 'Values intellectual bonds, struggles with vulnerability',
      },
      'Pisces': {
        'strengths': 'Compassionate, artistic, intuitive, gentle',
        'weaknesses': 'Escapist, overly trusting, easily overwhelmed',
        'emotional':
            'Absorbs others\u2019 emotions like a sponge, deeply empathetic',
      },
    };
    return allTraits[sign] ??
        {
          'strengths': 'Adaptable, intuitive, creative, compassionate',
          'weaknesses': 'Overthinking, indecisive at times',
          'emotional': 'Deeply empathetic and emotionally aware',
        };
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem(this.icon, this.label, this.color);
}
