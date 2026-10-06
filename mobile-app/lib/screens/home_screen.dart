import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../widgets/starry_background.dart';
import '../widgets/energy_forecast_chart.dart';
import 'discover_screen.dart';
import 'fortune_screen.dart';
import 'horoscope_screen.dart';
import 'notifications_screen.dart';
import 'tarot_screen.dart';
import 'story_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userSign;

  /// The sign the daily reading is keyed on: tropical Sun (western/both) or
  /// the sidereal Moon rashi (vedic). Shown as the headline sign.
  final String readingSign;

  /// 'western' or 'vedic' — the tradition of the current daily reading.
  final String system;

  /// True when Vedic was chosen but birth time/place are missing, so the
  /// reading fell back to Western. Drives the "add birth details" nudge.
  final bool needsBirthDetailsForVedic;

  /// The user's chosen tradition: 'western' (default) or 'vedic'. Changing it
  /// reloads the reading.
  final String tradition;

  /// Birth details, used to personalise the daily reading and the forecast.
  final String? birthDate;
  final String? birthTime;
  final String? birthPlace;

  final HoroscopeData? initialHoroscope;
  final ValueChanged<HoroscopeData>? onHoroscopeUpdated;

  /// Opens the Profile tab so the user can add missing birth details.
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userSign,
    required this.readingSign,
    this.system = 'western',
    this.needsBirthDetailsForVedic = false,
    this.tradition = 'western',
    this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.initialHoroscope,
    this.onHoroscopeUpdated,
    this.onOpenProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HoroscopeData? _horoscope;
  List<AstrologyStory> _stories = [];
  TarotCard? _dailyTarotCard;
  bool _dailyTarotReversed = false;
  bool _isLoading = true;

  /// 7-day forecast points per system ('western'/'vedic') for the daily-card
  /// sparkline. Empty list = fetched but unavailable; missing key = not fetched.
  final Map<String, List<ForecastPoint>> _forecastBySystem = {};

  /// Drives the dot on the notification bell: off means the user has never
  /// set up their daily reminder.
  bool _remindersOn = true;

  @override
  void initState() {
    super.initState();
    _horoscope = widget.initialHoroscope;
    _isLoading = widget.initialHoroscope == null;
    _loadData();
    _loadDailyTarot();
    _loadReminderState();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHoroscope != null &&
        widget.initialHoroscope != oldWidget.initialHoroscope) {
      setState(() {
        _horoscope = widget.initialHoroscope!;
        _isLoading = false;
      });
    }
    // Tradition or birth details changed (e.g. edited in Profile) — re-resolve
    // so the Western/Vedic compare view stays in sync.
    if (widget.tradition != oldWidget.tradition ||
        widget.birthDate != oldWidget.birthDate ||
        widget.birthTime != oldWidget.birthTime ||
        widget.birthPlace != oldWidget.birthPlace) {
      _forecastBySystem.clear();
      _loadData();
    }
  }

  Future<void> _loadReminderState() async {
    final enabled = await NotificationService.isEnabled();
    if (mounted) setState(() => _remindersOn = enabled);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    await _loadReminderState();
  }

  Future<void> _loadDailyTarot() async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('daily_tarot_date');

    if (cachedDate == today) {
      // Restore cached card fields from today's prefs
      final name = prefs.getString('daily_tarot_name');
      if (name != null && mounted) {
        setState(() {
          _dailyTarotCard = TarotCard(
            name: name,
            number: prefs.getString('daily_tarot_number') ?? '',
            meaning: prefs.getString('daily_tarot_meaning') ?? '',
            interpretation: prefs.getString('daily_tarot_interpretation') ?? '',
            reversedInterpretation:
                prefs.getString('daily_tarot_reversed_interpretation') ?? '',
            isReversed: prefs.getBool('daily_tarot_reversed') ?? false,
          );
          _dailyTarotReversed = prefs.getBool('daily_tarot_reversed') ?? false;
        });
      }
      return;
    }

    // Fetch new card from API and cache all fields
    final result = await ApiService.drawTarotCard();
    if (result != null && mounted) {
      final card = result.card;
      final isReversed = result.isReversed;
      await prefs.setString('daily_tarot_date', today);
      await prefs.setString('daily_tarot_name', card.name);
      await prefs.setString('daily_tarot_number', card.number);
      await prefs.setString('daily_tarot_meaning', card.meaning);
      await prefs.setString('daily_tarot_interpretation', card.interpretation);
      await prefs.setString(
        'daily_tarot_reversed_interpretation',
        card.reversedInterpretation,
      );
      await prefs.setBool('daily_tarot_reversed', isReversed);
      setState(() {
        _dailyTarotCard = card;
        _dailyTarotReversed = isReversed;
      });
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    // Only show loading state if we don't already have data from parent
    if (widget.initialHoroscope == null && mounted) {
      setState(() => _isLoading = true);
    }
    final results = await Future.wait([
      ApiService.getHoroscope(
        widget.readingSign,
        system: widget.system,
        birthDate: widget.birthDate,
        birthTime: widget.birthTime,
        birthPlace: widget.birthPlace,
      ),
      ApiService.getStories(),
    ]);
    if (mounted) {
      setState(() {
        _horoscope = results[0] as HoroscopeData?;
        _stories = results[1] as List<AstrologyStory>;
        _isLoading = false;
      });
      final horoscope = results[0] as HoroscopeData?;
      if (horoscope != null) {
        widget.onHoroscopeUpdated?.call(horoscope);
        HistoryService.recordDailyHoroscope(
          sign: widget.readingSign,
          system: widget.system,
        );
      }
    }
    if (mounted) _ensureForecast(widget.system);
  }

  @override
  Widget build(BuildContext context) {
    final sign = zodiacSigns.firstWhere(
      (z) => z.name == widget.readingSign,
      orElse: () => zodiacSigns.firstWhere((z) => z.name == widget.userSign),
    );

    return StarryBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(context, sign),
                if (widget.needsBirthDetailsForVedic) ...[
                  const SizedBox(height: 16),
                  _buildVedicNudge(context),
                ],
                const SizedBox(height: 24),
                _buildDailyCard(context, _horoscope),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildDailyTarotWidget(context),
                const SizedBox(height: 24),
                _buildStoryFeed(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, dynamic sign) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName.isNotEmpty
                    ? 'Good ${_getGreeting()}, ${widget.userName}'
                    : 'Good ${_getGreeting()},',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${sign.name} ${sign.symbol}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.system == 'vedic')
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Moon sign · Janma Rashi',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mysticTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildNotificationBell(context),
        const SizedBox(width: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradientPurple,
          ),
          child: Center(
            child: Text(sign.symbol, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return IconButton(
      onPressed: _openNotifications,
      tooltip: 'Reminders',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none,
            color: AppColors.textSecondary,
            size: 26,
          ),
          if (!_remindersOn)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVedicNudge(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenProfile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.mysticTeal.withAlpha(20),
          border: Border.all(color: AppColors.mysticTeal.withAlpha(102)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.spa_outlined,
              color: AppColors.mysticTeal,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock your Vedic reading',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Add your birth time & place so we can find your Moon '
                    'sign (Janma Rashi). Showing a Western reading for now.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mysticTeal,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCard(BuildContext context, HoroscopeData? horoscope) {
    final isLoading = _isLoading;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HoroscopeScreen(
              userSign: widget.readingSign,
              system: widget.system,
              initialHoroscope: _horoscope,
              birthDate: widget.birthDate,
              birthTime: widget.birthTime,
              birthPlace: widget.birthPlace,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          // Subtle pulsing border while live data is loading
          border: isLoading
              ? Border.all(color: AppColors.accent.withAlpha(80))
              : Border.all(color: AppColors.accent.withAlpha(51)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Horoscope',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else if (horoscope != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${horoscope.overallScore}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              )
            else if (horoscope == null)
              const Text(
                'Unable to load your reading. Pull down to refresh.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              )
            else ...[
              if (horoscope.band != null) _buildBandWhy(horoscope),
              _buildHoroscopePreview(horoscope.general),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.casino,
                    'Lucky: ${horoscope.luckyNumber}',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.palette, horoscope.luckyColor),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.mood, horoscope.mood),
                ],
              ),
              _buildSparkline(),
            ],
          ],
        ),
      ),
    );
  }

  /// Lazily fetch the 7-day forecast for [system] (once) so the daily card can
  /// show a sparkline. Marks the slot in-flight to coalesce duplicate calls.
  Future<void> _ensureForecast(String system) async {
    final bd = widget.birthDate;
    if (bd == null || bd.isEmpty) return;
    if (_forecastBySystem.containsKey(system)) return;
    _forecastBySystem[system] = const [];
    final res = await ApiService.getForecast(
      birthDate: bd,
      birthTime: widget.birthTime,
      birthPlace: widget.birthPlace,
      system: system,
      days: 7,
    );
    if (!mounted) return;
    setState(() {
      _forecastBySystem[system] = res?.points ?? const <ForecastPoint>[];
    });
  }

  /// A coloured band chip ("Mixed · 54%") plus the one-line "why" for the
  /// active personalized reading.
  Widget _buildBandWhy(HoroscopeData h) {
    final color = forecastScoreColor(h.overallScore);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Text(
            '${h.band} \u00b7 ${h.overallScore}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (h.moodSummary != null && h.moodSummary!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            h.moodSummary!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  /// The compact 7-day energy sparkline for the active reading, or nothing when
  /// the forecast isn't available.
  Widget _buildSparkline() {
    final points = _forecastBySystem[widget.system];
    if (points == null || points.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              const Text(
                'Next 7 days',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          EnergyForecastChart(points: points, compact: true),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.style,
                title: 'Tarot',
                subtitle: 'Draw your card',
                accentColor: AppColors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TarotScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.auto_awesome,
                title: 'Fortune',
                subtitle: 'Get your reading',
                accentColor: AppColors.accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FortuneScreen(userSign: widget.userSign),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoroscopePreview(String text) {
    final lines = _splitHoroscopeLines(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightedLine(lines[0], addSparkle: true),
        const SizedBox(height: 4),
        _buildHighlightedLine(lines[1]),
      ],
    );
  }

  List<String> _splitHoroscopeLines(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return const [
        'The stars are aligning for you today.',
        'Trust your intuition and move with confidence.',
      ];
    }

    final sentenceParts = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (sentenceParts.length >= 2) {
      return [sentenceParts[0].trim(), sentenceParts[1].trim()];
    }

    final words = normalized.split(' ');
    if (words.length <= 8) {
      return [normalized, 'Your natural leadership will shine.'];
    }

    final splitIndex = (words.length / 2).ceil();
    final firstLine = words.sublist(0, splitIndex).join(' ').trim();
    final secondLine = words.sublist(splitIndex).join(' ').trim();
    return [
      firstLine,
      secondLine.isEmpty ? 'Your natural leadership will shine.' : secondLine,
    ];
  }

  Widget _buildHighlightedLine(String line, {bool addSparkle = false}) {
    const baseStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.45,
    );
    const highlightStyle = TextStyle(
      color: AppColors.accent,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w700,
    );

    const keywords = {
      'bold',
      'fresh',
      'leadership',
      'shine',
      'love',
      'career',
      'health',
      'focus',
      'energy',
      'success',
      'opportunity',
      'confidence',
      'growth',
      'intuition',
      'balance',
      'creative',
      'passion',
      'harmony',
      'luck',
    };

    final words = line.split(' ');
    final spans = <TextSpan>[];

    for (final word in words) {
      if (word.isEmpty) continue;
      final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      final isKeyword = keywords.contains(cleaned);
      spans.add(
        TextSpan(text: '$word ', style: isKeyword ? highlightStyle : baseStyle),
      );
    }

    if (addSparkle) {
      spans.add(const TextSpan(text: '✨', style: TextStyle(fontSize: 14)));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showDailyCardDetail(
    BuildContext context,
    TarotCard card,
    bool isReversed,
  ) {
    final borderColor = isReversed ? const Color(0xFFE53935) : AppColors.accent;
    final interpretationText =
        isReversed && card.reversedInterpretation.isNotEmpty
        ? card.reversedInterpretation
        : card.interpretation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.purple.withAlpha(77)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  const Icon(Icons.style, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Card of the Day',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Card visual (larger)
              Center(
                child: Container(
                  width: 140,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: isReversed
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3E1A1A), Color(0xFF1A1A2E)],
                          )
                        : AppColors.gradientPurple,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withAlpha(77),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: isReversed ? 3.14159 : 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.number,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Icon(Icons.auto_awesome, color: borderColor, size: 40),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            card.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Card name + reversed badge
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Text(
                      card.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isReversed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE53935).withAlpha(128),
                          ),
                        ),
                        child: const Text(
                          'Reversed',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  card.meaning,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Interpretation card (detail view only)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isReversed
                        ? const Color(0xFFE53935).withAlpha(77)
                        : AppColors.purple.withAlpha(77),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isReversed ? Icons.sync : Icons.auto_awesome,
                          color: isReversed
                              ? const Color(0xFFE53935)
                              : AppColors.purple,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isReversed ? 'Reversed Reading' : 'Interpretation',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isReversed
                                ? const Color(0xFFE53935)
                                : AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      interpretationText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // CTA to open full tarot screen
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TarotScreen()),
                  );
                },
                icon: const Icon(Icons.style, size: 18),
                label: const Text('Draw Your Own Card'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: BorderSide(color: AppColors.purple.withAlpha(128)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTarotWidget(BuildContext context) {
    final card = _dailyTarotCard;
    final isReversed = _dailyTarotReversed;
    return GestureDetector(
      onTap: card == null
          ? null
          : () => _showDailyCardDetail(context, card, isReversed),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purple.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.style, color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Card of the Day',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.purple,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (card == null)
              const Center(
                child: SizedBox(
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.purple,
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Mini card visual
                  Container(
                    width: 72,
                    height: 104,
                    decoration: BoxDecoration(
                      gradient: isReversed
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF3E1A1A), Color(0xFF1A1A2E)],
                            )
                          : AppColors.gradientPurple,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isReversed
                            ? const Color(0xFFE53935)
                            : AppColors.accent,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isReversed
                                      ? const Color(0xFFE53935)
                                      : AppColors.purple)
                                  .withAlpha(102),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color:
                              (isReversed
                                      ? const Color(0xFFE53935)
                                      : AppColors.accent)
                                  .withAlpha(51),
                          blurRadius: 26,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: isReversed ? 3.14159 : 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: isReversed
                                ? const Color(0xFFE53935)
                                : AppColors.accent,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 11,
                              color: isReversed
                                  ? const Color(0xFFE53935)
                                  : AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Card info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                card.name,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isReversed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFE53935,
                                    ).withAlpha(128),
                                  ),
                                ),
                                child: const Text(
                                  'Reversed',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.meaning,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryFeed(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trending Today 🔥',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscoverScreen(userSign: widget.userSign),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._stories.take(3).map((story) => _buildStoryCard(context, story)),
      ],
    );
  }

  Widget _buildStoryCard(BuildContext context, AstrologyStory story) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    story.summary,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              story.readTime,
              style: const TextStyle(color: AppColors.accent, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
