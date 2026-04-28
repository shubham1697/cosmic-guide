import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

// ─── Planet color mapping ────────────────────────────────────────────────────

const Map<String, Color> _planetColors = {
  'Sun': Color(0xFFFFD700),
  'Moon': Color(0xFFE0E0E0),
  'Mercury': Color(0xFF9E9E9E),
  'Venus': Color(0xFFE91E63),
  'Mars': Color(0xFFFF5722),
  'Jupiter': Color(0xFFFF9800),
  'Saturn': Color(0xFF78909C),
  'Uranus': Color(0xFF00BCD4),
  'Neptune': Color(0xFF7C4DFF),
  'Pluto': Color(0xFF795548),
};

// Planet placement descriptions (keyed by "PlanetName-SignName")
String _placementText(String planet, String sign) {
  final key = '$planet-$sign';
  const placements = {
    'Sun-Aries': 'Bold identity, natural leader, self-starter energy.',
    'Sun-Taurus': 'Steady, sensual, values comfort and material security.',
    'Sun-Gemini': 'Quick-witted, curious, thrives on communication.',
    'Sun-Cancer': 'Nurturing soul, emotional depth, family-oriented.',
    'Sun-Leo': 'Radiant self-expression, generous, loves the spotlight.',
    'Sun-Virgo': 'Analytical mind, service-oriented, detail-focused.',
    'Sun-Libra': 'Harmony-seeker, diplomatic, values partnerships.',
    'Sun-Scorpio': 'Intense, transformative, deeply perceptive.',
    'Sun-Sagittarius': 'Adventurous spirit, philosophical, freedom-loving.',
    'Sun-Capricorn': 'Ambitious, disciplined, builds lasting structures.',
    'Sun-Aquarius': 'Innovative, humanitarian, marches to own beat.',
    'Sun-Pisces': 'Dreamy, empathetic, artistically gifted.',
    'Moon-Aries': 'Emotionally impulsive, needs independence and action.',
    'Moon-Taurus': 'Emotionally steady, seeks comfort and sensory pleasure.',
    'Moon-Gemini': 'Emotionally curious, needs variety and conversation.',
    'Moon-Cancer': 'Deeply intuitive, emotionally rich, needs security.',
    'Moon-Leo': 'Warm-hearted emotions, needs recognition and drama.',
    'Moon-Virgo': 'Emotionally reserved, analyses feelings carefully.',
    'Moon-Libra': 'Emotionally balanced, needs harmony in relationships.',
    'Moon-Scorpio': 'Intense emotions, powerful instincts, deeply private.',
    'Moon-Sagittarius': 'Emotionally adventurous, needs freedom and meaning.',
    'Moon-Capricorn': 'Emotionally cautious, mature, needs achievement.',
    'Moon-Aquarius': 'Emotionally detached, needs intellectual stimulation.',
    'Moon-Pisces': 'Deeply empathetic, absorbs others emotions, dreamy.',
  };
  return placements[key] ?? '$planet in $sign — unique cosmic energy at play.';
}

// ─── Chart painter ────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final String sunSign;
  final double animValue;
  final int? highlightedPlanetIndex;
  final List<PlanetPosition> planets;
  final double? ascendantLongitude; // AC
  final double? midheavenLongitude; // MC

  const _ChartPainter({
    required this.sunSign,
    required this.animValue,
    this.highlightedPlanetIndex,
    required this.planets,
    this.ascendantLongitude,
    this.midheavenLongitude,
  });

  // ─── Chart painter paint method ──────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.46;
    final zodiacR = outerR * 0.84; // ring where zodiac glyphs sit
    final innerR = outerR * 0.56; // inner boundary of planet ring
    final coreR = outerR * 0.38; // core circle
    // Planet radial lanes: outer-first; overlapping planets stack inward
    final lane0R = outerR * 0.77; // primary — near zodiac ring
    final lane1R = outerR * 0.68; // secondary
    final lane2R = outerR * 0.59; // tertiary

    final sunIdx = zodiacSigns.indexWhere((z) => z.name == sunSign);
    final ascLon = ascendantLongitude ?? (sunIdx * 30.0);

    // rotationOffset: maps ecliptic longitude → screen angle (CCW, AC at left)
    // Formula: screenAngle = rotationOffset - eclipticLon - 90
    // We want AC (eclipticLon = ascLon) at screen 180° (left):
    //   rotationOffset - ascLon - 90 = 180 → rotationOffset = ascLon + 270
    final rotationOffset = ascLon + 270;

    // Helper to convert ecliptic longitude to screen angle in radians
    double toScreen(double eclipticLon) =>
        (rotationOffset - eclipticLon - 90) * math.pi / 180;

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

    // ── Zodiac sign spokes (outer band: zodiacR → outerR) ──────────────────
    final signSpokePaint = Paint()
      ..color = const Color(0xFF7C4DFF).withAlpha(55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angle = toScreen(i * 30.0);
      canvas.drawLine(
        Offset(cx + zodiacR * math.cos(angle), cy + zodiacR * math.sin(angle)),
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        signSpokePaint,
      );
    }

    // ── House spokes (inner band: coreR → innerR) ──────────────────────────
    final houseSpokePaint = Paint()
      ..color = const Color(0xFF7C4DFF).withAlpha(40)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int j = 0; j < 12; j++) {
      // Equal houses: each house cusp at ascLon + j * 30
      final houseCusp = ascLon + j * 30.0;
      final angle = toScreen(houseCusp);
      canvas.drawLine(
        Offset(cx + coreR * math.cos(angle), cy + coreR * math.sin(angle)),
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        houseSpokePaint,
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
      // Midpoint of sign i: i*30 + 15
      final angle = toScreen(i * 30.0 + 15);
      final r = (zodiacR + outerR) / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

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
      -2 * math.pi * animValue,
      false,
      Paint()
        ..color = const Color(0xFFFFD700).withAlpha(130)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── House numbers (1–12) in inner ring — anchored to Ascendant ─────────
    for (int j = 0; j < 12; j++) {
      // Midpoint of house j: ascLon + j*30 + 15
      final houseMid = ascLon + j * 30.0 + 15;
      final angle = toScreen(houseMid);
      final r = (coreR + innerR) / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      // Subtle background circle behind number
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..color = const Color(0xFF1A2240).withAlpha(200)
          ..style = PaintingStyle.fill,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${j + 1}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: (j == 0 || j == 3 || j == 6 || j == 9)
                ? const Color(0xFFB0B8D1) // angular houses brighter
                : const Color(0xFF6B7394),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // ── AC / DC axis (Ascendant–Descendant) ─────────────────────────────────
    if (ascendantLongitude != null) {
      final acAngle = toScreen(ascendantLongitude!);
      final dcAngle = acAngle + math.pi;

      final axisPaint = Paint()
        ..color = const Color(0xFFFF5252).withAlpha((200 * animValue).toInt())
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(
          cx + outerR * math.cos(acAngle),
          cy + outerR * math.sin(acAngle),
        ),
        Offset(
          cx + outerR * math.cos(dcAngle),
          cy + outerR * math.sin(dcAngle),
        ),
        axisPaint,
      );

      final acLabelR = outerR + 10;
      _drawAxisLabel(
        canvas,
        cx,
        cy,
        acAngle,
        acLabelR,
        'AC',
        const Color(0xFFFF5252),
        animValue,
      );
      _drawAxisLabel(
        canvas,
        cx,
        cy,
        dcAngle,
        acLabelR,
        'DC',
        const Color(0xFFFF5252).withAlpha(150),
        animValue,
      );

      // AC arrow tip
      final acTipX = cx + (outerR + 2) * math.cos(acAngle);
      final acTipY = cy + (outerR + 2) * math.sin(acAngle);
      canvas.drawCircle(
        Offset(acTipX, acTipY),
        3,
        Paint()
          ..color = const Color(0xFFFF5252).withAlpha((220 * animValue).toInt())
          ..style = PaintingStyle.fill,
      );
    }

    // ── MC / IC axis (Midheaven–Imum Coeli) ─────────────────────────────────
    if (midheavenLongitude != null) {
      final mcAngle = toScreen(midheavenLongitude!);
      final icAngle = mcAngle + math.pi;

      final axisPaint = Paint()
        ..color = const Color(0xFF448AFF).withAlpha((180 * animValue).toInt())
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(
          cx + outerR * math.cos(mcAngle),
          cy + outerR * math.sin(mcAngle),
        ),
        Offset(
          cx + outerR * math.cos(icAngle),
          cy + outerR * math.sin(icAngle),
        ),
        axisPaint,
      );

      final mcLabelR = outerR + 10;
      _drawAxisLabel(
        canvas,
        cx,
        cy,
        mcAngle,
        mcLabelR,
        'MC',
        const Color(0xFF448AFF),
        animValue,
      );
      _drawAxisLabel(
        canvas,
        cx,
        cy,
        icAngle,
        mcLabelR,
        'IC',
        const Color(0xFF448AFF).withAlpha(150),
        animValue,
      );
    }

    // ── Planet symbols — outer-first, stack inward on overlap ──────────────
    // Helpers
    double norm(double a) {
      a = a % (2 * math.pi);
      return a < 0 ? a + 2 * math.pi : a;
    }

    double angDist(double a, double b) {
      final d = (a - b).abs() % (2 * math.pi);
      return d > math.pi ? 2 * math.pi - d : d;
    }

    const minAngGap = 14.0 * math.pi / 180; // ~14° collision threshold
    final lanes = [lane0R, lane1R, lane2R];
    final laneAngles = [<double>[], <double>[], <double>[]];

    final screenAngles = [for (final p in planets) norm(toScreen(p.longitude))];
    final radii = List<double>.filled(planets.length, lane0R);

    // Assign each planet to the outermost lane with no angular conflict
    for (int idx = 0; idx < planets.length; idx++) {
      final a = screenAngles[idx];
      bool placed = false;
      for (int lane = 0; lane < lanes.length; lane++) {
        final conflict = laneAngles[lane].any((b) => angDist(a, b) < minAngGap);
        if (!conflict) {
          radii[idx] = lanes[lane];
          laneAngles[lane].add(a);
          placed = true;
          break;
        }
      }
      if (!placed) radii[idx] = lane2R; // fallback: innermost
    }

    for (int idx = 0; idx < planets.length; idx++) {
      final planet = planets[idx];
      final pColor = _planetColors[planet.name] ?? const Color(0xFFB0B8D1);
      final angle = screenAngles[idx];
      final r = radii[idx];

      final isHighlighted = highlightedPlanetIndex == idx;
      final alpha = (255 * animValue).clamp(0, 255).toInt();

      // Tick line from innerR to just behind glyph
      canvas.drawLine(
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        Offset(cx + (r - 6) * math.cos(angle), cy + (r - 6) * math.sin(angle)),
        Paint()
          ..color = pColor.withAlpha(
            (isHighlighted ? 200 : 60) * animValue ~/ 1,
          )
          ..strokeWidth = isHighlighted ? 1.5 : 1,
      );

      // Glow behind planet symbol
      if (isHighlighted || animValue > 0.6) {
        canvas.drawCircle(
          Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
          isHighlighted ? 14 : 10,
          Paint()
            ..color = pColor.withAlpha(isHighlighted ? 80 : 35)
            ..style = PaintingStyle.fill,
        );
      }

      // Planet glyph text
      final tp = TextPainter(
        text: TextSpan(
          text: planet.symbol,
          style: TextStyle(
            fontSize: isHighlighted ? 17 : 15,
            color: pColor.withAlpha(alpha),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
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

  void _drawAxisLabel(
    Canvas canvas,
    double cx,
    double cy,
    double angle,
    double radius,
    String label,
    Color color,
    double anim,
  ) {
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);

    // Background pill
    final bgPaint = Paint()
      ..color = const Color(0xFF12192E).withAlpha((230 * anim).toInt())
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 22, height: 14),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color.withAlpha((255 * anim).toInt()),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.animValue != animValue ||
      old.sunSign != sunSign ||
      old.highlightedPlanetIndex != highlightedPlanetIndex ||
      old.planets != planets ||
      old.ascendantLongitude != ascendantLongitude ||
      old.midheavenLongitude != midheavenLongitude;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChartScreen extends StatefulWidget {
  final String userSign;
  final HoroscopeData? initialHoroscope;
  final ValueChanged<HoroscopeData>? onHoroscopeUpdated;
  final String? birthDate; // YYYY-MM-DD
  final String? birthTime; // HH:MM
  final String? birthPlace;

  const ChartScreen({
    super.key,
    required this.userSign,
    this.initialHoroscope,
    this.onHoroscopeUpdated,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen>
    with TickerProviderStateMixin {
  late AnimationController _chartAnim;
  late Animation<double> _chartDraw;
  late TabController _tabController;
  HoroscopeData? _horoscope;
  bool _isLoading = true;
  int? _highlightedPlanet;

  // Real birth chart data from backend
  BirthChartData? _birthChart;
  List<TransitData> _transits = [];

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
      _loadHoroscope();
    }
    _loadBirthChart();
    _loadTransits();
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
    // Re-fetch birth chart when birth details change
    if (widget.birthDate != old.birthDate ||
        widget.birthTime != old.birthTime ||
        widget.birthPlace != old.birthPlace) {
      _loadBirthChart();
    }
  }

  Future<void> _loadHoroscope() async {
    if (mounted) setState(() => _isLoading = true);
    final data = await ApiService.getHoroscope(widget.userSign);
    if (mounted) {
      setState(() {
        if (data != null) _horoscope = data;
        _isLoading = false;
      });
      if (data != null) {
        widget.onHoroscopeUpdated?.call(data);
        _chartAnim.forward(from: 0);
      }
    }
  }

  Future<void> _loadBirthChart() async {
    if (widget.birthDate == null) return;
    final chart = await ApiService.getBirthChart(
      birthDate: widget.birthDate!,
      birthTime: widget.birthTime,
      birthPlace: widget.birthPlace,
    );
    if (mounted && chart != null) {
      setState(() => _birthChart = chart);
      _chartAnim.forward(from: 0);
    }
  }

  Future<void> _loadTransits() async {
    final transits = await ApiService.getTransits();
    if (mounted && transits.isNotEmpty) {
      setState(() => _transits = transits);
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
    final sign = zodiacSigns.firstWhere((z) => z.name == widget.userSign);

    // Use real planet data if available, otherwise empty
    final planets = _birthChart?.planets ?? [];

    return StarryBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async {
            await Future.wait([
              _loadHoroscope(),
              _loadBirthChart(),
              _loadTransits(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(sign),
                const SizedBox(height: 24),
                _buildChartWheel(planets),
                const SizedBox(height: 16),
                _buildPlanetPlacements(planets),
                const SizedBox(height: 24),
                _buildBig3(sign),
                if (_birthChart?.moonNakshatra != null) ...[
                  const SizedBox(height: 24),
                  _buildNakshatra(_birthChart!.moonNakshatra),
                ],
                const SizedBox(height: 24),
                _buildTransitsSection(),
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

  Widget _buildChartWheel(List<PlanetPosition> planets) {
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
              planets: planets,
              ascendantLongitude: _birthChart?.ascendantLongitude,
              midheavenLongitude: _birthChart?.midheavenLongitude,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanetPlacements(List<PlanetPosition> planets) {
    if (planets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
            const SizedBox(height: 12),
            Text(
              'Add your birth details in Profile\nto see real planet positions',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
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
          itemCount: planets.length,
          itemBuilder: (context, idx) {
            final p = planets[idx];
            final pColor = _planetColors[p.name] ?? const Color(0xFFB0B8D1);
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
                  color: isSelected ? pColor.withAlpha(25) : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? pColor : pColor.withAlpha(60),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.symbol,
                      style: TextStyle(fontSize: 22, color: pColor),
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
                      'in ${p.sign}',
                      style: TextStyle(color: pColor, fontSize: 10),
                    ),
                    if (p.isRetrograde)
                      Text(
                        '℞',
                        style: TextStyle(color: Colors.redAccent, fontSize: 10),
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

  void _showPlanetDetail(BuildContext context, PlanetPosition planet) {
    final pColor = _planetColors[planet.name] ?? const Color(0xFFB0B8D1);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: pColor.withAlpha(77)),
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
                    color: pColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pColor.withAlpha(100)),
                  ),
                  child: Center(
                    child: Text(
                      planet.symbol,
                      style: TextStyle(fontSize: 28, color: pColor),
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
                      'in ${planet.sign} ${planet.degreeDisplay}',
                      style: TextStyle(
                        color: pColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (planet.isRetrograde)
                      const Text(
                        '℞ Retrograde',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
                border: Border.all(color: pColor.withAlpha(51)),
              ),
              child: Text(
                _placementText(planet.name, planet.sign),
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
    // Use real Big 3 data from backend if available
    final big3 = _birthChart?.big3;

    final ZodiacSign moonSign;
    final ZodiacSign risingSign;
    final bool isEstimated;

    if (big3 != null) {
      moonSign = zodiacSigns.firstWhere(
        (z) => z.name == big3.moonSign,
        orElse: () => sign,
      );
      risingSign = zodiacSigns.firstWhere(
        (z) => z.name == big3.risingSign,
        orElse: () => sign,
      );
      isEstimated = big3.risingIsEstimated;
    } else {
      // Estimate from Sun sign offset when no birth chart is available
      moonSign =
          zodiacSigns[(zodiacSigns.indexWhere(
                    (z) => z.name == widget.userSign,
                  ) +
                  4) %
              12];
      risingSign =
          zodiacSigns[(zodiacSigns.indexWhere(
                    (z) => z.name == widget.userSign,
                  ) +
                  8) %
              12];
      isEstimated = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Your Big 3', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (isEstimated)
              const Tooltip(
                message:
                    'Moon & Rising estimated.\nAdd birth time & place for accuracy.',
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

  Widget _buildNakshatra(NakshatraData nakshatra) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(51)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withAlpha(77)),
            ),
            child: const Center(
              child: Text(
                '☽',
                style: TextStyle(fontSize: 22, color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moon Nakshatra',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${nakshatra.name} · Pada ${nakshatra.pada}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lord: ${nakshatra.lord}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitsSection() {
    if (_transits.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Transits",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Loading current transits...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Transits", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        ..._transits.map((t) {
          final tColor = _planetColors[t.name] ?? const Color(0xFFB0B8D1);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tColor.withAlpha(51)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tColor.withAlpha(77)),
                  ),
                  child: Center(
                    child: Text(
                      t.symbol,
                      style: TextStyle(fontSize: 22, color: tColor),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(
                          color: tColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'in ${t.sign} ${t.degreeDisplay}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (t.isRetrograde)
                        const Text(
                          '℞ Retrograde',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHoroscopeSection() {
    final horoscope = _horoscope;
    if (horoscope == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: _isLoading
              ? const CircularProgressIndicator(color: AppColors.accent)
              : const Text(
                  'Reading unavailable. Pull down to refresh.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
        ),
      );
    }
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
                '${horoscope.overallScore}%',
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
              _readingCard(horoscope.general, Icons.star, AppColors.general),
              _readingCard(horoscope.love, Icons.favorite, AppColors.love),
              _readingCard(horoscope.career, Icons.work, AppColors.career),
              _readingCard(
                horoscope.health,
                Icons.health_and_safety,
                AppColors.health,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildLuckyRow(horoscope),
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

  Widget _buildLuckyRow(HoroscopeData horoscope) {
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
          _luckyItem(Icons.casino, 'Number', horoscope.luckyNumber),
          _luckyItem(Icons.palette, 'Color', horoscope.luckyColor),
          _luckyItem(Icons.mood, 'Mood', horoscope.mood),
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
