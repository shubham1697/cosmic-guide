import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';
import 'compatibility_screen.dart';
import 'kundli_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: DefaultTabController(
        length: 2,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relationships',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Find your cosmic connection',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        indicator: BoxDecoration(
                          gradient: AppColors.gradientGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textMuted,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: '♎  Western'),
                          Tab(text: '☸  Vedic'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    CompatibilityScreen(embedded: true),
                    KundliScreen(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
