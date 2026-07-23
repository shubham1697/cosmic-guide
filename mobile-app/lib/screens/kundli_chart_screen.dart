import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

enum _KundliChartStyle { north, south }

/// Maps planet name to standard Vedic abbreviation.
String _vedicPlanetAbbr(String name) {
  switch (name.toLowerCase()) {
    case 'sun':
      return 'Su';
    case 'moon':
      return 'Mo';
    case 'mars':
      return 'Ma';
    case 'mercury':
      return 'Me';
    case 'jupiter':
      return 'Ju';
    case 'venus':
      return 'Ve';
    case 'saturn':
      return 'Sa';
    case 'rahu':
      return 'Ra';
    case 'ketu':
      return 'Ke';
    case 'uranus':
      return 'Ur';
    case 'neptune':
      return 'Ne';
    case 'pluto':
      return 'Pl';
    default:
      // Fallback: first 2 chars
      return name.length >= 2 ? name.substring(0, 2) : name;
  }
}

/// Returns zodiac sign number (1-12) for a given house based on ascendant.
int _signNumberForHouse(int house, double ascendantLongitude) {
  final ascSignIndex = (ascendantLongitude ~/ 30) % 12; // 0=Aries .. 11=Pisces
  return ((ascSignIndex + house - 1) % 12) + 1;
}

class KundliChartScreen extends StatefulWidget {
  final String? birthDate;
  final String? birthTime;
  final String? birthPlace;

  const KundliChartScreen({
    super.key,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
  });

  @override
  State<KundliChartScreen> createState() => _KundliChartScreenState();
}

class _KundliChartScreenState extends State<KundliChartScreen> {
  _KundliChartStyle _style = _KundliChartStyle.north;
  BirthChartData? _chart;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    if (widget.birthDate == null || widget.birthDate!.isEmpty) return;
    setState(() => _isLoading = true);
    final data = await ApiService.getVedicChart(
      birthDate: widget.birthDate!,
      birthTime: widget.birthTime,
      birthPlace: widget.birthPlace,
    );
    if (!mounted) return;
    setState(() {
      _chart = data;
      _isLoading = false;
    });
  }

  /// Whole-sign house of a planet (the authentic Vedic rasi method): the
  /// ascendant's whole sign is the 1st house, so a planet's house is simply
  /// its sign's offset from the Lagna sign.
  int _houseFromPlanet(PlanetPosition planet) {
    final ascSign = ((_chart?.ascendantLongitude ?? 0) ~/ 30) % 12;
    final planetSign = (planet.longitude ~/ 30) % 12;
    return ((planetSign - ascSign + 12) % 12) + 1;
  }

  Map<int, List<String>> _planetsByHouse() {
    final result = <int, List<String>>{};
    for (var i = 1; i <= 12; i++) {
      result[i] = [];
    }

    final asc = _chart?.ascendantLongitude;
    if (_chart == null || asc == null) return result;

    for (final planet in _chart!.planets) {
      final house = _houseFromPlanet(planet);
      result[house]!.add(_vedicPlanetAbbr(planet.name));
    }
    return result;
  }

  /// Groups planet abbreviations by zodiac sign (0 = Aries … 11 = Pisces).
  /// The South Indian chart is sign-based, so planets sit in fixed sign boxes.
  Map<int, List<String>> _planetsBySign() {
    final result = <int, List<String>>{
      for (var i = 0; i < 12; i++) i: <String>[],
    };
    final chart = _chart;
    if (chart == null) return result;
    for (final planet in chart.planets) {
      final signIndex = (planet.longitude ~/ 30) % 12;
      result[signIndex]!.add(_vedicPlanetAbbr(planet.name));
    }
    return result;
  }

  /// Zodiac sign index (0–11) of the ascendant / Lagna.
  int get _ascSignIndex => ((_chart?.ascendantLongitude ?? 0) ~/ 30) % 12;

  String _styleLabel(_KundliChartStyle style) {
    switch (style) {
      case _KundliChartStyle.north:
        return 'North Indian';
      case _KundliChartStyle.south:
        return 'South Indian';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBirth = widget.birthDate != null && widget.birthDate!.isNotEmpty;
    final byHouse = _planetsByHouse();

    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Kundli Chart',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadChart,
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _buildStyleSelector(),
                const SizedBox(height: 16),
                if (!hasBirth)
                  _buildInfoCard(
                    title: 'Birth details required',
                    text:
                        'Add birth date, time, and place in Profile to render your personalised Kundli chart.',
                  )
                else if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else if (_chart == null)
                  _buildInfoCard(
                    title: 'Chart unavailable',
                    text:
                        'Could not fetch chart data right now. Pull down to retry.',
                  )
                else ...[
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  if (_style == _KundliChartStyle.north)
                    _buildNorthKundli(byHouse)
                  else
                    _buildSouthKundli(),
                  const SizedBox(height: 14),
                  _buildLegend(),
                  if (_chart != null && !_chart!.hasAccurateHouses) ...[
                    const SizedBox(height: 10),
                    _buildEstimatedNote(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 8,
      children: _KundliChartStyle.values.map((style) {
        final selected = _style == style;
        return ChoiceChip(
          label: Text('${_styleLabel(style)} Style'),
          selected: selected,
          selectedColor: AppColors.accent.withAlpha(35),
          labelStyle: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected
                ? AppColors.accent.withAlpha(120)
                : AppColors.textMuted.withAlpha(80),
          ),
          backgroundColor: AppColors.card,
          onSelected: (_) => setState(() => _style = style),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard() {
    final c = _chart!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(40), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Janam Kundli',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Lahiri',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryChip('Lagna', c.big3.risingSign)),
              const SizedBox(width: 12),
              Expanded(child: _summaryChip('Sun', c.big3.sunSign)),
              const SizedBox(width: 12),
              Expanded(child: _summaryChip('Moon', c.big3.moonSign)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryChip(
            'Nakshatra',
            '${c.moonNakshatra.name} · Pada ${c.moonNakshatra.pada} · ${c.moonNakshatra.lord}',
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─── AUTHENTIC NORTH INDIAN KUNDLI ──────────────────────────────────────────

  Widget _buildNorthKundli(Map<int, List<String>> byHouse) {
    final ascLon = _chart?.ascendantLongitude ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(280.0, 420.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0E6), // warm ivory paper
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withAlpha(70),
                      width: 1.2,
                    ),
                    boxShadow: [
                      // Outer ambient shadow
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      // Tight inner shadow for depth
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      // Subtle gold glow
                      BoxShadow(
                        color: AppColors.accent.withAlpha(18),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Subtle paper texture overlay
                        Positioned.fill(
                          child: CustomPaint(painter: _PaperTexturePainter()),
                        ),
                        // Edge vignette for depth
                        Positioned.fill(
                          child: CustomPaint(painter: _VignettePainter()),
                        ),
                        // Chart geometry
                        Positioned.fill(
                          child: CustomPaint(painter: _NorthKundliPainter()),
                        ),
                        ..._northHouseLabels(byHouse, ascLon, size),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _northHouseLabels(
    Map<int, List<String>> byHouse,
    double ascLon,
    double size,
  ) {
    // Positions of the 12 house compartments as fractions of the chart size.
    // Authentic North Indian kundli geometry: the Lagna (1st house) is the
    // top-centre diamond and the houses run ANTI-CLOCKWISE from there.
    //
    //             2    1    12
    //               \  |  /
    //           3  ── \ | / ──  11
    //              4  (centre)  10
    //           5  ── / | \ ──  9
    //               /  |  \
    //             6    7    8
    //
    // Centroids (x, y); corner triangles nudged inward so labels fit inside.
    const positions = <int, Offset>{
      1: Offset(0.50, 0.28), // top centre — Lagna (Kendra)
      2: Offset(0.27, 0.12), // top-left triangle
      3: Offset(0.12, 0.27), // left-upper triangle
      4: Offset(0.28, 0.50), // left centre (Kendra)
      5: Offset(0.12, 0.73), // left-lower triangle
      6: Offset(0.27, 0.88), // bottom-left triangle
      7: Offset(0.50, 0.72), // bottom centre (Kendra)
      8: Offset(0.73, 0.88), // bottom-right triangle
      9: Offset(0.88, 0.73), // right-lower triangle
      10: Offset(0.72, 0.50), // right centre (Kendra)
      11: Offset(0.88, 0.27), // right-upper triangle
      12: Offset(0.73, 0.12), // top-right triangle
    };

    // Kendra houses (the four central diamonds) are larger compartments.
    const kendraHouses = {1, 4, 7, 10};

    return List.generate(12, (i) {
      final house = i + 1;
      final pos = positions[house]!;
      final planets = byHouse[house] ?? const [];
      final signNum = _signNumberForHouse(house, ascLon);
      final isKendra = kendraHouses.contains(house);

      // Size constraints for house label areas
      final maxW = isKendra ? size * 0.22 : size * 0.18;
      final maxH = isKendra ? size * 0.22 : size * 0.16;

      return Positioned(
        left: pos.dx * size - maxW / 2,
        top: pos.dy * size - maxH / 2,
        child: SizedBox(
          width: maxW,
          height: maxH,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sign number + Asc marker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$signNum',
                    style: TextStyle(
                      color: const Color(0xFF2A2118), // warm dark brown
                      fontSize: isKendra ? 12 : 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'serif',
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (house == 1) ...[
                    const SizedBox(width: 3),
                    const Text(
                      'Asc',
                      style: TextStyle(
                        color: Color(0xFFB8860B), // dark goldenrod
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'serif',
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
              // Planet abbreviations
              if (planets.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  planets.join(' '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A2F24), // warm charcoal brown
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontFamily: 'serif',
                    letterSpacing: 0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  // ─── AUTHENTIC SOUTH INDIAN KUNDLI ──────────────────────────────────────────
  // Sign-based chart: the twelve rasis occupy FIXED boxes and never move.
  // Aries is the 2nd box on the top row and the signs run clockwise. The Lagna
  // box is highlighted and marked with a diagonal in its corner.

  static const List<String> _signShort = [
    'Ari',
    'Tau',
    'Gem',
    'Can',
    'Leo',
    'Vir',
    'Lib',
    'Sco',
    'Sag',
    'Cap',
    'Aqu',
    'Pis',
  ];

  // Fixed cell centres (fraction of chart size) keyed by sign index.
  static const Map<int, Offset> _southCellCentres = {
    11: Offset(0.125, 0.125), // Pisces  (top-left corner)
    0: Offset(0.375, 0.125), // Aries
    1: Offset(0.625, 0.125), // Taurus
    2: Offset(0.875, 0.125), // Gemini  (top-right corner)
    3: Offset(0.875, 0.375), // Cancer
    4: Offset(0.875, 0.625), // Leo
    5: Offset(0.875, 0.875), // Virgo   (bottom-right corner)
    6: Offset(0.625, 0.875), // Libra
    7: Offset(0.375, 0.875), // Scorpio
    8: Offset(0.125, 0.875), // Sagittarius (bottom-left corner)
    9: Offset(0.125, 0.625), // Capricorn
    10: Offset(0.125, 0.375), // Aquarius
  };

  Widget _buildSouthKundli() {
    final bySign = _planetsBySign();
    final ascSign = _ascSignIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(280.0, 420.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0E6), // warm ivory paper
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withAlpha(70),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.accent.withAlpha(18),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _PaperTexturePainter()),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _VignettePainter()),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _SouthKundliPainter()),
                        ),
                        _southCentreLabel(size),
                        ..._southSignCells(bySign, ascSign, size),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _southCentreLabel(double size) {
    return Positioned(
      left: size * 0.25,
      top: size * 0.25,
      width: size * 0.5,
      height: size * 0.5,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rāśi',
              style: GoogleFonts.playfairDisplay(
                fontSize: size * 0.058,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B4E1A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'D–1',
              style: TextStyle(
                fontSize: size * 0.032,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A6A2A),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _southSignCells(
    Map<int, List<String>> bySign,
    int ascSign,
    double size,
  ) {
    final cell = size / 4;
    return _southCellCentres.entries.map((entry) {
      final signIndex = entry.key;
      final centre = entry.value;
      final planets = bySign[signIndex] ?? const [];
      final isLagna = signIndex == ascSign;

      return Positioned(
        left: centre.dx * size - cell / 2,
        top: centre.dy * size - cell / 2,
        width: cell,
        height: cell,
        child: Stack(
          children: [
            if (isLagna)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x1AB8860B)),
                ),
              ),
            if (isLagna)
              Positioned.fill(
                child: CustomPaint(painter: _LagnaCornerPainter()),
              ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _signShort[signIndex],
                        style: const TextStyle(
                          color: Color(0xFF9A7B3A),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'serif',
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (isLagna) ...[
                        const SizedBox(width: 3),
                        const Text(
                          'La',
                          style: TextStyle(
                            color: Color(0xFFB8860B),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        planets.join('  '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2A2118),
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'serif',
                          letterSpacing: 0.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInfoCard({required String title, required String text}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    const grahas = <MapEntry<String, String>>[
      MapEntry('Su', 'Sun'),
      MapEntry('Mo', 'Moon'),
      MapEntry('Ma', 'Mars'),
      MapEntry('Me', 'Mercury'),
      MapEntry('Ju', 'Jupiter'),
      MapEntry('Ve', 'Venus'),
      MapEntry('Sa', 'Saturn'),
      MapEntry('Ra', 'Rahu'),
      MapEntry('Ke', 'Ketu'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GRAHAS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: grahas.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.value,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatedNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Birth time unavailable — Lagna estimated from the Moon (Chandra '
            'Lagna). Add an exact time and place for a precise ascendant.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTHENTIC NORTH INDIAN KUNDLI PAINTER
// Traditional diamond-style geometry: outer square + inner diamond + diagonals
// Creates 12 fixed house compartments as used in Vedic astrology
// ═══════════════════════════════════════════════════════════════════════════════

class _NorthKundliPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Inner lines — warm sepia-charcoal
    final paint = Paint()
      ..color =
          const Color(0xFF3D3228) // warm dark sepia
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;
    final margin = 14.0;

    // Outer square
    final rect = Rect.fromLTWH(margin, margin, w - margin * 2, h - margin * 2);

    // Outer border — slightly thicker, darker
    final outerPaint = Paint()
      ..color = const Color(0xFF2A2018)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawRect(rect, outerPaint);

    // Thin decorative inner border (1.5px inset)
    final inset = 4.0;
    final innerRect = rect.deflate(inset);
    final decorPaint = Paint()
      ..color =
          const Color(0x30B8860B) // faint gold decorative line
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawRect(innerRect, decorPaint);

    // Midpoints of outer square sides
    final mTop = Offset(rect.center.dx, rect.top);
    final mRight = Offset(rect.right, rect.center.dy);
    final mBottom = Offset(rect.center.dx, rect.bottom);
    final mLeft = Offset(rect.left, rect.center.dy);

    // Inner diamond: connect midpoints
    canvas.drawLine(mTop, mRight, paint);
    canvas.drawLine(mRight, mBottom, paint);
    canvas.drawLine(mBottom, mLeft, paint);
    canvas.drawLine(mLeft, mTop, paint);

    // Two diagonals of outer square (corner to corner)
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle paper texture — warm-toned grain for premium astrology report feel.
class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkGrain = Paint()
      ..color =
          const Color(0x09000000) // ~3.5% black
      ..style = PaintingStyle.fill;
    final warmGrain = Paint()
      ..color =
          const Color(0x06604020) // ~2% warm brown
      ..style = PaintingStyle.fill;

    const step = 5.0;
    var seed = 0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        seed = ((seed + 1) * 1103515245 + 12345) & 0x7fffffff;
        if (seed % 4 == 0) {
          final dx = (seed % 5) - 2.0;
          final dy = ((seed >> 3) % 5) - 2.0;
          final useDark = (seed >> 5) % 3 != 0;
          canvas.drawCircle(
            Offset(x + dx, y + dy),
            0.5,
            useDark ? darkGrain : warmGrain,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft edge vignette — darkens perimeter slightly for premium depth.
class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: const [
        Color(0x00000000), // transparent center
        Color(0x00000000), // stay transparent until edge
        Color(0x0C000000), // ~5% dark at edges
      ],
      stops: const [0.0, 0.7, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTHENTIC SOUTH INDIAN KUNDLI PAINTER
// Fixed-sign 4×4 grid: twelve rasi boxes around an open 2×2 centre panel.
// ═══════════════════════════════════════════════════════════════════════════════

class _SouthKundliPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final margin = 12.0;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    final cw = rect.width / 4;
    final ch = rect.height / 4;

    final line = Paint()
      ..color =
          const Color(0xFF3D3228) // warm dark sepia
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final outer = Paint()
      ..color = const Color(0xFF2A2018)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Outer border + faint gold inset (matches the North chart styling).
    canvas.drawRect(rect, outer);
    canvas.drawRect(
      rect.deflate(4),
      Paint()
        ..color = const Color(0x30B8860B)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    final xL = rect.left + cw; // x = 1/4
    final xM = rect.left + cw * 2; // x = 1/2
    final xR = rect.left + cw * 3; // x = 3/4
    final yT = rect.top + ch; // y = 1/4
    final yM = rect.top + ch * 2; // y = 1/2
    final yB = rect.top + ch * 3; // y = 3/4

    // Full grid lines at 1/4 and 3/4 — these frame the open centre panel.
    canvas.drawLine(Offset(xL, rect.top), Offset(xL, rect.bottom), line);
    canvas.drawLine(Offset(xR, rect.top), Offset(xR, rect.bottom), line);
    canvas.drawLine(Offset(rect.left, yT), Offset(rect.right, yT), line);
    canvas.drawLine(Offset(rect.left, yB), Offset(rect.right, yB), line);

    // Short segments splitting the four edge bands into individual sign boxes.
    canvas.drawLine(Offset(xM, rect.top), Offset(xM, yT), line); // top band
    canvas.drawLine(Offset(xM, yB), Offset(xM, rect.bottom), line); // bottom
    canvas.drawLine(Offset(rect.left, yM), Offset(xL, yM), line); // left band
    canvas.drawLine(Offset(xR, yM), Offset(rect.right, yM), line); // right band
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws the classic Lagna mark — a short diagonal across the box's top-left
/// corner — used to flag the ascendant sign in a South Indian chart.
class _LagnaCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB8860B)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final s = size.shortestSide * 0.34;
    canvas.drawLine(Offset(0, s), Offset(s, 0), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
