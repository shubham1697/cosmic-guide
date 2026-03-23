import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';
import 'story_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userSign;
  final VoidCallback onHoroscopeTap;
  final VoidCallback onTarotTap;
  final VoidCallback onFortuneTap;
  final VoidCallback onCompatibilityTap;
  final VoidCallback onKundliTap;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userSign,
    required this.onHoroscopeTap,
    required this.onTarotTap,
    required this.onFortuneTap,
    required this.onCompatibilityTap,
    required this.onKundliTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HoroscopeData _horoscope;
  List<AstrologyStory> _stories = MockData.stories;
  TarotCard? _dailyTarotCard;
  bool _dailyTarotReversed = false;

  @override
  void initState() {
    super.initState();
    _horoscope = MockData.getHoroscope(widget.userSign);
    _loadData();
    _loadDailyTarot();
  }

  Future<void> _loadDailyTarot() async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('daily_tarot_date');

    int cardIndex;
    bool isReversed;

    if (cachedDate == today) {
      // Restore cached card for today
      cardIndex = prefs.getInt('daily_tarot_index') ?? 0;
      isReversed = prefs.getBool('daily_tarot_reversed') ?? false;
    } else {
      // Pick new card deterministically from today's date + save
      final now = DateTime.now();
      final seed = now.year * 10000 + now.month * 100 + now.day;
      cardIndex = seed % MockData.tarotDeck.length;
      isReversed = (seed % 10) < 3; // ~30% chance reversed
      await prefs.setString('daily_tarot_date', today);
      await prefs.setInt('daily_tarot_index', cardIndex);
      await prefs.setBool('daily_tarot_reversed', isReversed);
    }

    if (mounted) {
      setState(() {
        _dailyTarotCard = MockData.tarotDeck[cardIndex];
        _dailyTarotReversed = isReversed;
      });
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      ApiService.getHoroscope(widget.userSign),
      ApiService.getStories(),
    ]);
    if (mounted) {
      setState(() {
        _horoscope = results[0] as HoroscopeData;
        _stories = results[1] as List<AstrologyStory>;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sign = MockData.zodiacSigns.firstWhere(
      (z) => z.name == widget.userSign,
    );
    final horoscope = _horoscope;

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
                const SizedBox(height: 24),
                _buildDailyCard(context, horoscope),
                const SizedBox(height: 24),
                _buildDailyTarotWidget(context),
                const SizedBox(height: 24),
                _buildQuickActions(context),
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
            ],
          ),
        ),
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

  Widget _buildDailyCard(BuildContext context, dynamic horoscope) {
    return GestureDetector(
      onTap: widget.onHoroscopeTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withAlpha(51)),
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
            _buildHoroscopePreview(horoscope.general),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.casino, 'Lucky: ${horoscope.luckyNumber}'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.palette, horoscope.luckyColor),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.mood, horoscope.mood),
              ],
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
      return const ['The stars are aligning for you today.', 'Trust your intuition and move with confidence.'];
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
    return [firstLine, secondLine.isEmpty ? 'Your natural leadership will shine.' : secondLine];
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
      spans.add(TextSpan(text: '$word ', style: isKeyword ? highlightStyle : baseStyle));
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
                  widget.onTarotTap();
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

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction('Tarot', Icons.style, AppColors.purple, widget.onTarotTap),
      _QuickAction(
        'Fortune',
        Icons.auto_awesome,
        AppColors.accent,
        widget.onFortuneTap,
      ),
      _QuickAction(
        'Match',
        Icons.favorite,
        AppColors.love,
        widget.onCompatibilityTap,
      ),
      _QuickAction(
        'Kundli',
        Icons.circle_outlined,
        AppColors.mysticTeal,
        widget.onKundliTap,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: _QuickActionTile(action: action),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStoryFeed(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trending Today 🔥', style: Theme.of(context).textTheme.titleLarge),
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

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _isPressed ? 0.96 : 1,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.card.withAlpha(245),
                action.color.withAlpha(36),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: action.color.withAlpha(_isPressed ? 170 : 95),
              width: _isPressed ? 1.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: action.color.withAlpha(_isPressed ? 90 : 30),
                blurRadius: _isPressed ? 16 : 8,
                spreadRadius: _isPressed ? 1.5 : 0,
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 140),
                scale: _isPressed ? 1.06 : 1,
                child: Icon(action.icon, color: action.color, size: 32),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: action.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
