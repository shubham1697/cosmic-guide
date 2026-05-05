import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
  DateTime _selectedDate = DateTime.now();

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

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadHoroscope();
  }

  void _goToNextDay() {
    final today = DateTime.now();
    if (_selectedDate.isBefore(DateTime(today.year, today.month, today.day))) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      });
      _loadHoroscope();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: AppColors.primary,
              surface: AppColors.secondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadHoroscope();
    }
  }

  void _shareHoroscope() {
    if (horoscope == null) return;
    final sign = zodiacSigns.firstWhere((z) => z.name == widget.userSign);
    final dateStr = DateFormat('MMMM d, yyyy').format(_selectedDate);
    final text =
        '${sign.symbol} ${sign.name} Horoscope — $dateStr\n\n'
        '⭐ Overall Score: ${horoscope!.overallScore}%\n\n'
        '✨ General: ${horoscope!.general}\n\n'
        '❤️ Love: ${horoscope!.love}\n\n'
        '💼 Career: ${horoscope!.career}\n\n'
        '🍀 Lucky Number: ${horoscope!.luckyNumber} | Color: ${horoscope!.luckyColor} | Mood: ${horoscope!.mood}\n\n'
        '— CosmicGuide App';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horoscope copied to clipboard!'),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final sign = zodiacSigns.firstWhere((z) => z.name == widget.userSign);
    final isToday =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day) ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Daily Horoscope', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
          actions: [
            if (horoscope != null)
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                onPressed: _shareHoroscope,
                tooltip: 'Share',
              ),
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
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! > 300) {
              _goToPreviousDay();
            } else if (details.primaryVelocity! < -300) {
              _goToNextDay();
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDateNavigator(isToday),
                const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildDateNavigator(bool isToday) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          onPressed: _goToPreviousDay,
        ),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withAlpha(77)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  _dateLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: isToday
                ? AppColors.textMuted.withAlpha(77)
                : AppColors.textSecondary,
          ),
          onPressed: isToday ? null : _goToNextDay,
        ),
      ],
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
