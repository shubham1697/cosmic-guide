import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../theme/app_theme.dart';

/// The visual for the shareable "cosmic blueprint" card: the user's name and
/// their Big 3 (Sun / Moon / Rising) on a starry gradient with app branding.
///
/// Rendered at a fixed logical width so the captured PNG is crisp and
/// consistent regardless of device size.
class ShareableChartCard extends StatelessWidget {
  final String name;
  final String sunSign;
  final String moonSign;
  final String risingSign;
  final bool isEstimated;

  /// Vedic framing: label the ascendant "Lagna" instead of "Rising".
  final bool isVedic;

  const ShareableChartCard({
    super.key,
    required this.name,
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    this.isEstimated = false,
    this.isVedic = false,
  });

  static const _sunColor = Color(0xFFFFD700);
  static const _moonColor = Color(0xFFE0E0E0);
  static const _risingColor = Color(0xFF7C4DFF);

  ZodiacSign _sign(String name) => zodiacSigns.firstWhere(
    (z) => z.name == name,
    orElse: () => zodiacSigns.first,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F52), Color(0xFF1A1A2E), Color(0xFF0F1A3C)],
        ),
        border: Border.all(color: AppColors.accent.withAlpha(70), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _brand(),
          const SizedBox(height: 22),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'COSMIC BLUEPRINT',
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 28),
          _big3Row('Sun ☉', _sign(sunSign), 'Identity & core self', _sunColor),
          const SizedBox(height: 14),
          _big3Row(
            'Moon ☽',
            _sign(moonSign),
            'Emotions & instincts',
            _moonColor,
          ),
          const SizedBox(height: 14),
          _big3Row(
            isVedic ? 'Lagna ↑' : 'Rising ↑',
            _sign(risingSign),
            'How others see you',
            _risingColor,
          ),
          const SizedBox(height: 24),
          if (isEstimated) ...[
            Text(
              isVedic
                  ? '✦ Moon & Lagna estimated'
                  : '✦ Moon & Rising estimated',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(height: 1, color: AppColors.accent.withAlpha(45)),
          const SizedBox(height: 12),
          Text(
            'Discover your stars on CosmicGuide',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '✦',
          style: TextStyle(color: AppColors.accent, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          'COSMICGUIDE',
          style: GoogleFonts.poppins(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '✦',
          style: TextStyle(color: AppColors.accent, fontSize: 13),
        ),
      ],
    );
  }

  Widget _big3Row(String label, ZodiacSign sign, String meaning, Color color) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(28),
            border: Border.all(color: color.withAlpha(115), width: 1.5),
          ),
          child: Center(
            child: Text(
              sign.symbol,
              style: TextStyle(fontSize: 26, color: color),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sign.name,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                meaning,
                style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
