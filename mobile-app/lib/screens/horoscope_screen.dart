import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

class HoroscopeScreen extends StatefulWidget {
  final String userSign;
  final HoroscopeData? initialHoroscope;
  const HoroscopeScreen({
    super.key,
    required this.userSign,
    this.initialHoroscope,
  });

  @override
  State<HoroscopeScreen> createState() => _HoroscopeScreenState();
}

class _HoroscopeScreenState extends State<HoroscopeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  HoroscopeData? horoscope;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialHoroscope != null) {
      horoscope = widget.initialHoroscope!;
      _isLoading = false;
    } else {
      _loadHoroscope();
    }
  }

  @override
  void didUpdateWidget(HoroscopeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHoroscope != null &&
        widget.initialHoroscope != oldWidget.initialHoroscope) {
      setState(() {
        horoscope = widget.initialHoroscope!;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHoroscope() async {
    if (mounted) setState(() => _isLoading = true);
    final data = await ApiService.getHoroscope(widget.userSign);
    if (mounted) {
      setState(() {
        horoscope = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = zodiacSigns.firstWhere((z) => z.name == widget.userSign);

    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Daily Horoscope', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSignHeader(sign),
              const SizedBox(height: 24),
              if (_isLoading && horoscope == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (horoscope == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Reading unavailable. Pull down to refresh.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else ...[
                _buildScoreRing(),
                const SizedBox(height: 24),
                _buildTabBar(),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContent(
                        horoscope!.general,
                        Icons.star,
                        AppColors.general,
                      ),
                      _buildContent(
                        horoscope!.love,
                        Icons.favorite,
                        AppColors.love,
                      ),
                      _buildContent(
                        horoscope!.career,
                        Icons.work,
                        AppColors.career,
                      ),
                      _buildContent(
                        horoscope!.health,
                        Icons.health_and_safety,
                        AppColors.health,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildLuckySection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignHeader(dynamic sign) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(sign.symbol, style: const TextStyle(fontSize: 40)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sign.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              sign.dateRange,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreRing() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradientCard,
        border: Border.all(color: AppColors.accent.withAlpha(77), width: 2),
      ),
      child: Column(
        children: [
          Text(
            '${horoscope!.overallScore}%',
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const Text(
            'Overall',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.gradientPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(Icons.star, size: 18), text: 'General'),
          Tab(icon: Icon(Icons.favorite, size: 18), text: 'Love'),
          Tab(icon: Icon(Icons.work, size: 18), text: 'Career'),
          Tab(icon: Icon(Icons.health_and_safety, size: 18), text: 'Health'),
        ],
      ),
    );
  }

  Widget _buildContent(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuckySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(51)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLuckyItem(Icons.casino, 'Number', horoscope!.luckyNumber),
          _buildLuckyItem(Icons.palette, 'Color', horoscope!.luckyColor),
          _buildLuckyItem(Icons.mood, 'Mood', horoscope!.mood),
        ],
      ),
    );
  }

  Widget _buildLuckyItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
