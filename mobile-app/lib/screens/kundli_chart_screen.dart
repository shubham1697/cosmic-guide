import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

enum _KundliChartStyle { north, south, east }

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
    final data = await ApiService.getBirthChart(
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

  int _houseFromPlanet(PlanetPosition planet) {
    if (_chart == null || _chart!.houses.isEmpty) {
      final ascSign = (_chart?.ascendantLongitude ?? 0) ~/ 30 % 12;
      final planetSign = planet.longitude ~/ 30 % 12;
      return ((planetSign - ascSign + 12) % 12) + 1;
    }

    final planetLon = planet.longitude;
    final houses = _chart!.houses;

    for (int i = 0; i < 12; i++) {
      final currentCusp = houses[i].cuspLongitude;
      final nextCusp = houses[(i + 1) % 12].cuspLongitude;

      bool isInHouse;
      if (currentCusp < nextCusp) {
        isInHouse = planetLon >= currentCusp && planetLon < nextCusp;
      } else {
        isInHouse = planetLon >= currentCusp || planetLon < nextCusp;
      }

      if (isInHouse) {
        return i + 1;
      }
    }

    return 1;
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
      result[house]!.add(planet.symbol);
    }
    return result;
  }

  String _styleLabel(_KundliChartStyle style) {
    switch (style) {
      case _KundliChartStyle.north:
        return 'North';
      case _KundliChartStyle.south:
        return 'South';
      case _KundliChartStyle.east:
        return 'East';
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
                  _buildChartDiagram(byHouse),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.health.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chart Summary',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.health,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lagna: ${c.big3.risingSign}   Moon: ${c.big3.moonSign}   Nakshatra: ${c.moonNakshatra.name} (${c.moonNakshatra.pada})',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartDiagram(Map<int, List<String>> byHouse) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth.clamp(280.0, 400.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.purple.withAlpha(100),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withAlpha(30),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: switch (_style) {
                            _KundliChartStyle.north => _NorthChartPainter(),
                            _KundliChartStyle.south => _SouthChartPainter(),
                            _KundliChartStyle.east => _EastChartPainter(),
                          },
                        ),
                      ),
                      ..._houseWidgets(byHouse),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _houseWidgets(Map<int, List<String>> byHouse) {
    final alignments = switch (_style) {
      _KundliChartStyle.north => const <int, Alignment>{
        1: Alignment(0, -0.84),
        2: Alignment(0.42, -0.68),
        3: Alignment(0.72, -0.38),
        4: Alignment(0.84, 0),
        5: Alignment(0.72, 0.38),
        6: Alignment(0.42, 0.68),
        7: Alignment(0, 0.84),
        8: Alignment(-0.42, 0.68),
        9: Alignment(-0.72, 0.38),
        10: Alignment(-0.84, 0),
        11: Alignment(-0.72, -0.38),
        12: Alignment(-0.42, -0.68),
      },
      _KundliChartStyle.south => const <int, Alignment>{
        1: Alignment(-0.66, -0.83),
        2: Alignment(-0.22, -0.83),
        3: Alignment(0.22, -0.83),
        4: Alignment(0.66, -0.83),
        5: Alignment(0.83, -0.3),
        6: Alignment(0.83, 0.05),
        7: Alignment(0.66, 0.83),
        8: Alignment(0.22, 0.83),
        9: Alignment(-0.22, 0.83),
        10: Alignment(-0.66, 0.83),
        11: Alignment(-0.83, 0.05),
        12: Alignment(-0.83, -0.3),
      },
      _KundliChartStyle.east => const <int, Alignment>{
        1: Alignment(0, -0.74),
        2: Alignment(0.38, -0.62),
        3: Alignment(0.67, -0.37),
        4: Alignment(0.74, 0),
        5: Alignment(0.67, 0.37),
        6: Alignment(0.38, 0.62),
        7: Alignment(0, 0.74),
        8: Alignment(-0.38, 0.62),
        9: Alignment(-0.67, 0.37),
        10: Alignment(-0.74, 0),
        11: Alignment(-0.67, -0.37),
        12: Alignment(-0.38, -0.62),
      },
    };

    return List.generate(12, (i) {
      final house = i + 1;
      final planets = byHouse[house] ?? const [];
      final text = planets.isEmpty ? '' : planets.join(' ');

      String? houseSign;
      if (_chart != null &&
          _chart!.houses.isNotEmpty &&
          i < _chart!.houses.length) {
        houseSign = _chart!.houses[i].sign;
      }

      return Align(
        alignment: alignments[house]!,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 56,
            maxWidth: 80,
            minHeight: 40,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.secondary.withAlpha(180),
                AppColors.secondary.withAlpha(120),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.accent.withAlpha(80),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$house',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (houseSign != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      houseSign.substring(0, 2),
                      style: TextStyle(
                        color: AppColors.textMuted.withAlpha(180),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
              ],
            ],
          ),
        ),
      );
    });
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
}

class _NorthChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.accent.withAlpha(100)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(rect, p);

    final c = rect.center;
    final top = Offset(c.dx, rect.top);
    final right = Offset(rect.right, c.dy);
    final bottom = Offset(c.dx, rect.bottom);
    final left = Offset(rect.left, c.dy);

    canvas.drawLine(top, right, p);
    canvas.drawLine(right, bottom, p);
    canvas.drawLine(bottom, left, p);
    canvas.drawLine(left, top, p);

    canvas.drawLine(Offset(c.dx, rect.top), Offset(c.dx, rect.bottom), p);
    canvas.drawLine(Offset(rect.left, c.dy), Offset(rect.right, c.dy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SouthChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.accent.withAlpha(100)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(rect, p);

    final x1 = rect.left + rect.width / 4;
    final x2 = rect.left + rect.width / 2;
    final x3 = rect.left + rect.width * 3 / 4;
    final y1 = rect.top + rect.height / 4;
    final y2 = rect.top + rect.height / 2;
    final y3 = rect.top + rect.height * 3 / 4;

    canvas.drawLine(Offset(x1, rect.top), Offset(x1, rect.bottom), p);
    canvas.drawLine(Offset(x2, rect.top), Offset(x2, rect.bottom), p);
    canvas.drawLine(Offset(x3, rect.top), Offset(x3, rect.bottom), p);
    canvas.drawLine(Offset(rect.left, y1), Offset(rect.right, y1), p);
    canvas.drawLine(Offset(rect.left, y2), Offset(rect.right, y2), p);
    canvas.drawLine(Offset(rect.left, y3), Offset(rect.right, y3), p);

    final blank = Rect.fromCenter(
      center: rect.center,
      width: rect.width / 2,
      height: rect.height / 2,
    );
    final eraser = Paint()..color = AppColors.card;
    canvas.drawRect(blank, eraser);
    canvas.drawRect(blank, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EastChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.accent.withAlpha(100)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(rect, p);
    canvas.drawLine(rect.topLeft, rect.bottomRight, p);
    canvas.drawLine(rect.topRight, rect.bottomLeft, p);

    final cx = rect.center.dx;
    final cy = rect.center.dy;
    canvas.drawLine(Offset(cx, rect.top), Offset(cx, rect.bottom), p);
    canvas.drawLine(Offset(rect.left, cy), Offset(rect.right, cy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
