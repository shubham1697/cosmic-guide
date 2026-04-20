import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

// ─── Static planet/transit data ──────────────────────────────────────────────

class _Planet {
  final String symbol;
  final String name;
  final int degreeOffset; // 0–359, position on wheel
  final Color color;
  final String inSign; // which zodiac sign it's currently in
  final String placement; // one-line meaning of planet in this sign

  const _Planet({
    required this.symbol,
    required this.name,
    required this.degreeOffset,
    required this.color,
    required this.inSign,
    required this.placement,
  });
}

class _Transit {
  final String planet;
  final String symbol;
  final String influence;
  final String detail;
  final Color color;

  const _Transit({
    required this.planet,
    required this.symbol,
    required this.influence,
    required this.detail,
    required this.color,
  });
}

// Planets positioned relative to the chart wheel.
// degreeOffset 0–359 maps directly onto the zodiac ring (0 = start of Aries).
// Replace with real ephemeris data from backend when available.
const List<_Planet> _planets = [
  _Planet(
    symbol: '☉',
    name: 'Sun',
    degreeOffset: 15,
    color: Color(0xFFFFD700),
    inSign: 'Aries',
    placement: 'Bold identity, natural leader, self-starter energy.',
  ),
  _Planet(
    symbol: '☽',
    name: 'Moon',
    degreeOffset: 75,
    color: Color(0xFFE0E0E0),
    inSign: 'Gemini',
    placement: 'Emotionally curious, needs variety and conversation.',
  ),
  _Planet(
    symbol: '☿',
    name: 'Mercury',
    degreeOffset: 30,
    color: Color(0xFF9E9E9E),
    inSign: 'Taurus',
    placement: 'Slow, deliberate thinker; persuasive and grounded speech.',
  ),
  _Planet(
    symbol: '♀',
    name: 'Venus',
    degreeOffset: 330,
    color: Color(0xFFE91E63),
    inSign: 'Pisces',
    placement: 'Romantic idealist, deeply empathetic in love.',
  ),
  _Planet(
    symbol: '♂',
    name: 'Mars',
    degreeOffset: 160,
    color: Color(0xFFFF5722),
    inSign: 'Virgo',
    placement: 'Precise drive, works hard on details and improvement.',
  ),
  _Planet(
    symbol: '♃',
    name: 'Jupiter',
    degreeOffset: 210,
    color: Color(0xFFFF9800),
    inSign: 'Scorpio',
    placement: 'Growth through depth, transformation, and intensity.',
  ),
  _Planet(
    symbol: '♄',
    name: 'Saturn',
    degreeOffset: 270,
    color: Color(0xFF78909C),
    inSign: 'Capricorn',
    placement: 'Disciplined, ambitious, strong sense of responsibility.',
  ),
  _Planet(
    symbol: '♅',
    name: 'Uranus',
    degreeOffset: 125,
    color: Color(0xFF00BCD4),
    inSign: 'Leo',
    placement: 'Rebels with flair; original, dramatic self-expression.',
  ),
  _Planet(
    symbol: '♆',
    name: 'Neptune',
    degreeOffset: 300,
    color: Color(0xFF7C4DFF),
    inSign: 'Aquarius',
    placement: 'Idealistic vision for humanity, spiritual innovation.',
  ),
];

List<_Transit> _transitsForSign(String sign) {
  // Symbolic transits derived from the sign's element and ruling planet
  final signData = MockData.zodiacSigns.firstWhere(
    (z) => z.name == sign,
    orElse: () => MockData.zodiacSigns.first,
  );

  final element = signData.element;

  String mercuryInfluence;
  String venusInfluence;
  String marsInfluence;

  if (element == 'Fire') {
    mercuryInfluence = 'Sharp thinking, bold communication';
    venusInfluence = 'Passionate connections draw near';
    marsInfluence = 'Energy peaks — act on ambitions';
  } else if (element == 'Earth') {
    mercuryInfluence = 'Practical plans crystallise clearly';
    venusInfluence = 'Stability and sensual pleasures favour you';
    marsInfluence = 'Steady momentum builds toward goals';
  } else if (element == 'Air') {
    mercuryInfluence = 'Ideas flow freely, speak your truth';
    venusInfluence = 'Social bonds deepen and charm radiates';
    marsInfluence = 'Mental drive surges — strategise boldly';
  } else {
    // Water
    mercuryInfluence = 'Intuitive insights guide key decisions';
    venusInfluence = 'Emotional bonds intensify and heal';
    marsInfluence = 'Inner resolve strengthens your purpose';
  }

  return [
    _Transit(
      planet: 'Mercury',
      symbol: '☿',
      influence: mercuryInfluence,
      detail:
          'Transit active — supports clear communication and quick thinking.',
      color: const Color(0xFF9E9E9E),
    ),
    _Transit(
      planet: 'Venus',
      symbol: '♀',
      influence: venusInfluence,
      detail: 'Venus energy amplifies relationships and creativity today.',
      color: const Color(0xFFE91E63),
    ),
    _Transit(
      planet: 'Mars',
      symbol: '♂',
      influence: marsInfluence,
      detail: 'Mars drive adds momentum — channel it constructively.',
      color: const Color(0xFFFF5722),
    ),
  ];
}

// ─── Chart painter ────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final String sunSign;
  final double animValue; // 0→1 for draw-on animation
  final int? highlightedPlanetIndex;

  const _ChartPainter({
    required this.sunSign,
    required this.animValue,
    this.highlightedPlanetIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.46;
    final zodiacR = outerR * 0.84; // ring where zodiac glyphs sit
    final planetR = outerR * 0.64; // ring where planet symbols sit
    final innerR = outerR * 0.56; // inner boundary of planet ring
    final coreR = outerR * 0.38; // core circle

    final sunIdx = MockData.zodiacSigns.indexWhere((z) => z.name == sunSign);
    // rotationOffset aligns the sun sign to the Ascendant (left side, 180°)
    final rotationOffset = -(sunIdx * 30).toDouble() + 180;

    // ── Background circles ──────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      outerR,
      Paint()
        ..color = const Color(0xFF12192E)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      innerR,
      Paint()
        ..color = const Color(0xFF1A2240)
        ..style = PaintingStyle.fill,
    );

    final ringStroke = Paint()
      ..color = const Color(0xFF7C4DFF).withAlpha(100)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), outerR, ringStroke);
    canvas.drawCircle(Offset(cx, cy), zodiacR, ringStroke);
    canvas.drawCircle(Offset(cx, cy), innerR, ringStroke);
    canvas.drawCircle(Offset(cx, cy), coreR, ringStroke);

    // ── House dividers (12 spokes from innerR to outerR) ────────────────────
    final spokePaint = Paint()
      ..color = const Color(0xFF7C4DFF).withAlpha(55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angleDeg = rotationOffset + i * 30 - 90;
      final angle = angleDeg * math.pi / 180;
      canvas.drawLine(
        Offset(cx + coreR * math.cos(angle), cy + coreR * math.sin(angle)),
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        spokePaint,
      );
    }

    // ── Zodiac sign glyphs in outer band ────────────────────────────────────
    const zodiacGlyphs = [
      '♈',
      '♉',
      '♊',
      '♋',
      '♌',
      '♍',
      '♎',
      '♏',
      '♐',
      '♑',
      '♒',
      '♓',
    ];
    const zodiacNames = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces',
    ];

    for (int i = 0; i < 12; i++) {
      final angleDeg = rotationOffset + i * 30 + 15 - 90;
      final angle = angleDeg * math.pi / 180;
      final r = (zodiacR + outerR) / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      // Highlight the sun's sign segment
      final isSunSign = zodiacNames[i] == sunSign;

      final tp = TextPainter(
        text: TextSpan(
          text: zodiacGlyphs[i],
          style: TextStyle(
            fontSize: isSunSign ? 17 : 13,
            color: isSunSign
                ? const Color(0xFFFFD700)
                : const Color(0xFFB0B8D1).withAlpha(200),
            fontWeight: isSunSign ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // ── Animated sweep arc (gold accent around zodiac ring) ─────────────────
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: (zodiacR + outerR) / 2),
      -math.pi / 2,
      2 * math.pi * animValue,
      false,
      Paint()
        ..color = const Color(0xFFFFD700).withAlpha(130)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── House numbers (1–12) in inner ring ──────────────────────────────────
    for (int i = 0; i < 12; i++) {
      final angleDeg = rotationOffset + i * 30 + 15 - 90;
      final angle = angleDeg * math.pi / 180;
      final r = (coreR + innerR) / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7394)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // ── Planet symbols on planet ring ───────────────────────────────────────
    for (int idx = 0; idx < _planets.length; idx++) {
      final planet = _planets[idx];
      // Map degreeOffset (0–359) to wheel angle
      final angleDeg = rotationOffset + planet.degreeOffset - 90;
      final angle = angleDeg * math.pi / 180;

      final isHighlighted = highlightedPlanetIndex == idx;
      final alpha = (255 * animValue).clamp(0, 255).toInt();

      // Leader line from innerR to planet track
      final lineStart = Offset(
        cx + innerR * math.cos(angle),
        cy + innerR * math.sin(angle),
      );
      final lineEnd = Offset(
        cx + (planetR + 2) * math.cos(angle),
        cy + (planetR + 2) * math.sin(angle),
      );
      canvas.drawLine(
        lineStart,
        lineEnd,
        Paint()
          ..color = planet.color.withAlpha(
            (isHighlighted ? 200 : 60) * animValue ~/ 1,
          )
          ..strokeWidth = isHighlighted ? 1.5 : 1,
      );

      // Glow behind planet symbol
      if (isHighlighted || animValue > 0.6) {
        canvas.drawCircle(
          Offset(
            cx + planetR * math.cos(angle),
            cy + planetR * math.sin(angle),
          ),
          isHighlighted ? 14 : 10,
          Paint()
            ..color = planet.color.withAlpha(isHighlighted ? 80 : 35)
            ..style = PaintingStyle.fill,
        );
      }

      // Planet glyph text
      final tp = TextPainter(
        text: TextSpan(
          text: planet.symbol,
          style: TextStyle(
            fontSize: isHighlighted ? 17 : 15,
            color: planet.color.withAlpha(alpha),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final px = cx + planetR * math.cos(angle);
      final py = cy + planetR * math.sin(angle);
      tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
    }

    // ── Core fill ─────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7C4DFF).withAlpha(50),
            const Color(0xFF1A1A2E),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR)),
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.animValue != animValue ||
      old.sunSign != sunSign ||
      old.highlightedPlanetIndex != highlightedPlanetIndex;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChartScreen extends StatefulWidget {
  final String userSign;
  final HoroscopeData? initialHoroscope;

  const ChartScreen({super.key, required this.userSign, this.initialHoroscope});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen>
    with TickerProviderStateMixin {
  late AnimationController _chartAnim;
  late Animation<double> _chartDraw;
  late TabController _tabController;
  late HoroscopeData _horoscope;
  bool _isLoading = true;
  int? _highlightedPlanet;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _chartAnim = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _chartDraw = CurvedAnimation(parent: _chartAnim, curve: Curves.easeOut);

    if (widget.initialHoroscope != null) {
      _horoscope = widget.initialHoroscope!;
      _isLoading = false;
      _chartAnim.forward();
    } else {
      _horoscope = MockData.getHoroscope(widget.userSign);
      _loadHoroscope();
    }
  }

  @override
  void didUpdateWidget(ChartScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialHoroscope != null &&
        widget.initialHoroscope != old.initialHoroscope) {
      setState(() {
        _horoscope = widget.initialHoroscope!;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHoroscope() async {
    if (mounted) setState(() => _isLoading = true);
    final data = await ApiService.getHoroscope(widget.userSign);
    if (mounted) {
      setState(() {
        _horoscope = data;
        _isLoading = false;
      });
      _chartAnim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = MockData.zodiacSigns.firstWhere(
      (z) => z.name == widget.userSign,
    );
    final transits = _transitsForSign(widget.userSign);

    return StarryBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: _loadHoroscope,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(sign),
                const SizedBox(height: 24),
                _buildChartWheel(),
                const SizedBox(height: 16),
                _buildPlanetPlacements(),
                const SizedBox(height: 24),
                _buildBig3(sign),
                const SizedBox(height: 24),
                _buildTransits(transits),
                const SizedBox(height: 24),
                _buildHoroscopeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ZodiacSign sign) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Chart',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sign.name} · ${sign.element} · ${sign.rulingPlanet}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
      ],
    );
  }

  Widget _buildChartWheel() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: _chartDraw,
          builder: (_, __) => CustomPaint(
            painter: _ChartPainter(
              sunSign: widget.userSign,
              animValue: _chartDraw.value,
              highlightedPlanetIndex: _highlightedPlanet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanetPlacements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Planet Positions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 8),
            const Text(
              '· tap to highlight',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.05,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _planets.length,
          itemBuilder: (context, idx) {
            final p = _planets[idx];
            final isSelected = _highlightedPlanet == idx;
            return GestureDetector(
              onTap: () {
                setState(() => _highlightedPlanet = isSelected ? null : idx);
                if (!isSelected) _showPlanetDetail(context, p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? p.color.withAlpha(25) : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? p.color : p.color.withAlpha(60),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.symbol,
                      style: TextStyle(fontSize: 22, color: p.color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'in ${p.inSign}',
                      style: TextStyle(color: p.color, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showPlanetDetail(BuildContext context, _Planet planet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: planet.color.withAlpha(77)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: planet.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: planet.color.withAlpha(100)),
                  ),
                  child: Center(
                    child: Text(
                      planet.symbol,
                      style: TextStyle(fontSize: 28, color: planet.color),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planet.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'in ${planet.inSign}',
                      style: TextStyle(
                        color: planet.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: planet.color.withAlpha(51)),
              ),
              child: Text(
                planet.placement,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _highlightedPlanet = null);
    });
  }

  Widget _buildBig3(ZodiacSign sign) {
    // Moon and Rising are estimated from sun sign — replace when birth time is stored
    final moonSign =
        MockData.zodiacSigns[(MockData.zodiacSigns.indexWhere(
                  (z) => z.name == widget.userSign,
                ) +
                4) %
            12];
    final risingSign =
        MockData.zodiacSigns[(MockData.zodiacSigns.indexWhere(
                  (z) => z.name == widget.userSign,
                ) +
                8) %
            12];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Your Big 3', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            const Tooltip(
              message:
                  'Moon & Rising estimated from Sun sign.\nAdd birth time in Profile for accuracy.',
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.info_outline,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Big3Card(
                label: 'Sun ☉',
                sign: sign,
                meaning: 'Identity & core self',
                color: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Big3Card(
                label: 'Moon ☽',
                sign: moonSign,
                meaning: 'Emotions & instincts',
                color: const Color(0xFFE0E0E0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Big3Card(
                label: 'Rising ↑',
                sign: risingSign,
                meaning: 'How others see you',
                color: const Color(0xFF7C4DFF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransits(List<_Transit> transits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Transits", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        ...transits.map((t) => _TransitCard(transit: t)),
      ],
    );
  }

  Widget _buildHoroscopeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Today's Reading",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.gradientGold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_horoscope.overallScore}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppColors.gradientPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Love'),
              Tab(text: 'Career'),
              Tab(text: 'Health'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: TabBarView(
            controller: _tabController,
            children: [
              _readingCard(_horoscope.general, Icons.star, AppColors.general),
              _readingCard(_horoscope.love, Icons.favorite, AppColors.love),
              _readingCard(_horoscope.career, Icons.work, AppColors.career),
              _readingCard(
                _horoscope.health,
                Icons.health_and_safety,
                AppColors.health,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildLuckyRow(),
      ],
    );
  }

  Widget _readingCard(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuckyRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(51)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _luckyItem(Icons.casino, 'Number', _horoscope.luckyNumber),
          _luckyItem(Icons.palette, 'Color', _horoscope.luckyColor),
          _luckyItem(Icons.mood, 'Mood', _horoscope.mood),
        ],
      ),
    );
  }

  Widget _luckyItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Big3Card extends StatelessWidget {
  final String label;
  final ZodiacSign sign;
  final String meaning;
  final Color color;

  const _Big3Card({
    required this.label,
    required this.sign,
    required this.meaning,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(sign.symbol, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            sign.name,
            style: GoogleFonts.playfairDisplay(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meaning,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TransitCard extends StatelessWidget {
  final _Transit transit;

  const _TransitCard({required this.transit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: transit.color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: transit.color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: transit.color.withAlpha(77)),
            ),
            child: Center(
              child: Text(
                transit.symbol,
                style: TextStyle(fontSize: 22, color: transit.color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transit.planet,
                  style: TextStyle(
                    color: transit.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transit.influence,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transit.detail,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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
}
