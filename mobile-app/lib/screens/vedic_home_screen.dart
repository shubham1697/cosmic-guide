import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/vedic_mock_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';
import 'kundli_chart_screen.dart';

class VedicHomeScreen extends StatefulWidget {
  final String? birthDate;
  final String? birthTime;
  final String? birthPlace;

  const VedicHomeScreen({
    super.key,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
  });

  @override
  State<VedicHomeScreen> createState() => _VedicHomeScreenState();
}

class _VedicHomeScreenState extends State<VedicHomeScreen> {
  VedicHomeSummaryData? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant VedicHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.birthDate != oldWidget.birthDate ||
        widget.birthTime != oldWidget.birthTime ||
        widget.birthPlace != oldWidget.birthPlace) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final summary = await ApiService.getVedicHomeSummary(
      birthDate: widget.birthDate,
      birthTime: widget.birthTime,
      birthPlace: widget.birthPlace,
    );
    if (!mounted) return;
    setState(() {
      _summary = summary ?? vedicHomeMockData;
      _isLoading = false;
    });
  }

  /// Approximate Vikram Samvat year. New year starts in Chaitra (~mid-April).
  int _getSamvatYear() {
    if (_summary != null) {
      return _summary!.calendar.samvatYear;
    }
    final now = DateTime.now();
    return (now.month > 4 || (now.month == 4 && now.day >= 14))
        ? now.year + 57
        : now.year + 56;
  }

  void _openFeatureSheet(
    BuildContext context,
    String feature,
    VedicHomeSummaryData summary,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: AppColors.purple.withAlpha(77)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
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
                Text(
                  feature,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _featureIntro(feature, summary),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                ..._featureSections(feature, summary),
              ],
            ),
          );
        },
      ),
    );
  }

  String _featureIntro(String feature, VedicHomeSummaryData summary) {
    switch (feature) {
      case 'Panchang':
        return 'Daily Vedic calendar details for ${summary.location.name}. These values are calculated from the current date and location.';
      case 'Kundli Chart':
        return summary.kundli == null
            ? 'Add birth date, time, and place to unlock your personal Vedic chart summary.'
            : 'This preview shows your current chart summary based on saved birth details.';
      case 'Dasha':
        return summary.dasha == null
            ? 'Dasha requires birth details because the periods are derived from your Moon position at birth.'
            : 'Your current Vimshottari period summary based on your Kundli.';
      case 'Doshas':
        return summary.dosha == null
            ? 'Dosha detection requires Kundli calculations.'
            : 'This preview shows the major dosha signals currently detected from your chart.';
      case 'Remedies':
        return summary.remedy == null
            ? 'Traditional remedies appear after chart-based signals are available.'
            : 'These are traditional suggestions linked to your current Vedic indicators.';
      case 'Hindu Calendar':
        return 'Monthly Hindu calendar context including the current month and next observed festival.';
      case 'Muhurta':
        return 'Auspicious and inauspicious time windows for ${summary.location.name}, calculated from today\'s real sunrise and sunset.';
      default:
        return 'Vedic feature details.';
    }
  }

  List<Widget> _featureSections(String feature, VedicHomeSummaryData summary) {
    switch (feature) {
      case 'Panchang':
        return [
          _detailCard('Today', [
            'Vara: ${summary.panchang.vara} (${summary.panchang.varaRuler})',
            'Tithi: ${summary.panchang.tithi}',
            'Paksha: ${summary.panchang.paksha}',
            'Nakshatra: ${summary.panchang.nakshatra}',
            'Yoga: ${summary.panchang.yoga}',
            'Karana: ${summary.panchang.karana}',
          ]),
          _detailCard('Insight', [summary.panchang.insight]),
        ];
      case 'Kundli Chart':
        if (summary.kundli == null) {
          return [
            _detailCard('Missing Details', [
              'Birth date, time, and place are needed for accurate lagna and house-based chart calculations.',
            ]),
          ];
        }
        return [
          _detailCard('Chart Summary', [
            'Lagna: ${summary.kundli!.lagna}',
            'Moon Sign: ${summary.kundli!.moonSign}',
            'Nakshatra: ${summary.kundli!.nakshatra}',
            summary.kundli!.note,
          ]),
        ];
      case 'Dasha':
        if (summary.dasha == null) {
          return [
            _detailCard('Missing Details', [
              'Dasha periods need saved birth details to calculate your Moon-based timeline.',
            ]),
          ];
        }
        return [
          _detailCard('Current Period', [
            'Mahadasha: ${summary.dasha!.mahadasha}',
            'Antardasha: ${summary.dasha!.antardasha}',
            'Mahadasha ends on: ${summary.dasha!.mahadashaEndsOn}',
          ]),
          _detailCard('Guidance', [summary.dasha!.guidance]),
        ];
      case 'Doshas':
        if (summary.dosha == null) {
          return [
            _detailCard('Missing Details', [
              'Dosha analysis appears after the chart has enough birth inputs.',
            ]),
          ];
        }
        return [
          _detailCard('Detection Summary', [
            'Active count: ${summary.dosha!.activeCount}',
            if (summary.dosha!.topDoshas.isNotEmpty)
              'Top indicators: ${summary.dosha!.topDoshas.join(', ')}',
            summary.dosha!.summary,
          ]),
        ];
      case 'Remedies':
        if (summary.remedy == null) {
          return [
            _detailCard('Unavailable', [
              'Traditional remedy suggestions will appear once chart-based signals are available.',
            ]),
          ];
        }
        return [
          _detailCard('Suggested Remedy Focus', [
            'Focus: ${summary.remedy!.focus}',
            'Gemstone: ${summary.remedy!.gemstone}',
            'Mantra: ${summary.remedy!.mantra}',
            'Fasting day: ${summary.remedy!.fastingDay}',
          ]),
          _detailCard('Guidance', [summary.remedy!.guidance]),
        ];
      case 'Hindu Calendar':
        return [
          _detailCard('Current Month', [
            'Month: ${summary.calendar.monthName}',
            'Vikram Samvat: ${summary.calendar.samvatYear}',
          ]),
          _detailCard('Upcoming Festival', [
            '${summary.calendar.nextFestivalName} · ${summary.calendar.nextFestivalDate}',
            summary.calendar.note,
          ]),
        ];
      case 'Muhurta':
        return [
          _detailCard('Sun', [
            'Sunrise: ${summary.timings.sunrise}',
            'Sunset: ${summary.timings.sunset}',
            'Day length: ${summary.timings.dayLength}',
          ]),
          _detailCard('Auspicious Windows', [
            'Abhijit Muhurta: ${summary.timings.abhijit}',
            'Brahma Muhurta: ${summary.timings.brahmaMuhurta}',
            summary.muhurta.note,
          ]),
          _detailCard('Inauspicious — Avoid New Beginnings', [
            'Rahu Kaal: ${summary.timings.rahuKaal}',
            'Yamaganda: ${summary.timings.yamaganda}',
            'Gulika Kaal: ${summary.timings.gulika}',
          ]),
        ];
      default:
        return [
          _detailCard('Details', ['No details available yet.']),
        ];
    }
  }

  Widget _detailCard(String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Text(
              line,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary ?? vedicHomeMockData;
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
                _buildHeader(summary),
                const SizedBox(height: 24),
                _buildVaraCard(summary),
                const SizedBox(height: 28),
                _buildSectionLabel(context, "Today's Muhurat & Kaal"),
                const SizedBox(height: 14),
                _buildDailyTimings(summary),
                const SizedBox(height: 12),
                _buildPanchangBanner(context, summary),
                const SizedBox(height: 28),
                _buildSectionLabel(context, 'Personal Chart'),
                const SizedBox(height: 14),
                _buildRow(context, [
                  _VedicFeature(
                    icon: Icons.grid_on_rounded,
                    title: 'Kundli Chart',
                    subtitle: summary.kundli == null
                        ? 'Add birth details'
                        : '${summary.kundli!.lagna} Lagna · ${summary.kundli!.moonSign}',
                    details: summary.kundli?.nakshatra ?? 'Janma kundli',
                    color: AppColors.health,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KundliChartScreen(
                            birthDate: widget.birthDate,
                            birthTime: widget.birthTime,
                            birthPlace: widget.birthPlace,
                          ),
                        ),
                      );
                    },
                  ),
                  _VedicFeature(
                    icon: Icons.timeline_rounded,
                    title: 'Dasha',
                    subtitle: summary.dasha == null
                        ? 'Birth details required'
                        : '${summary.dasha!.mahadasha} / ${summary.dasha!.antardasha}',
                    details: summary.dasha?.guidance ?? 'Life periods',
                    color: Colors.deepOrange,
                  ),
                ], summary),
                const SizedBox(height: 12),
                _buildRow(context, [
                  _VedicFeature(
                    icon: Icons.warning_amber_rounded,
                    title: 'Doshas',
                    subtitle: summary.dosha == null
                        ? 'Birth details required'
                        : summary.dosha!.activeCount == 0
                        ? 'No major dosha detected'
                        : '${summary.dosha!.activeCount} active dosha(s)',
                    details: summary.dosha?.summary ?? 'Mangal, Kaal Sarp',
                    color: Colors.redAccent,
                  ),
                  _VedicFeature(
                    icon: Icons.spa_rounded,
                    title: 'Remedies',
                    subtitle: summary.remedy == null
                        ? 'Will unlock with personal chart'
                        : '${summary.remedy!.gemstone} · ${summary.remedy!.fastingDay}',
                    details: summary.remedy?.mantra ?? 'Gemstone, mantra',
                    color: AppColors.purple,
                  ),
                ], summary),
                const SizedBox(height: 28),
                _buildSectionLabel(context, 'Hindu Calendar'),
                const SizedBox(height: 14),
                _buildFeatureCard(
                  context,
                  _VedicFeature(
                    icon: Icons.calendar_month_rounded,
                    title: 'Hindu Calendar',
                    subtitle:
                        '${summary.calendar.monthName} · Samvat ${summary.calendar.samvatYear}',
                    details:
                        'Next: ${summary.calendar.nextFestivalName} · ${summary.calendar.nextFestivalDate}',
                    color: AppColors.accent,
                  ),
                  summary,
                ),
                const SizedBox(height: 28),
                _buildBirthDataStatus(summary),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VedicHomeSummaryData summary) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vedic Astrology',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.calendar.monthName} · Vikram Samvat ${_getSamvatYear()}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.health.withAlpha(80)),
          ),
          child: const Center(
            child: Text('🕉', style: TextStyle(fontSize: 24)),
          ),
        ),
      ],
    );
  }

  Widget _buildVaraCard(VedicHomeSummaryData summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A3A), Color(0xFF1E2A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.health.withAlpha(80)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Vara",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.panchang.vara,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.health,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.location.name} · Day of ${summary.panchang.varaRuler}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.panchang.tithi} · ${summary.panchang.nakshatra}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sunTime(Icons.wb_sunny_outlined, summary.timings.sunrise),
                    const SizedBox(width: 16),
                    _sunTime(
                      Icons.nights_stay_outlined,
                      summary.timings.sunset,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.health.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.health.withAlpha(60)),
            ),
            child: const Icon(
              Icons.brightness_5_rounded,
              color: AppColors.health,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sunTime(IconData icon, String time) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.health.withAlpha(210)),
        const SizedBox(width: 5),
        Text(
          time,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDailyTimings(VedicHomeSummaryData summary) {
    final t = summary.timings;
    return GestureDetector(
      onTap: () => _openFeatureSheet(context, 'Muhurta', summary),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF241C36), Color(0xFF181D38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purple.withAlpha(64)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Muhurat & Kaal',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.health.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.health.withAlpha(60)),
                  ),
                  child: Text(
                    'Day ${t.dayLength}',
                    style: const TextStyle(
                      color: AppColors.health,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Auspicious — favour meaningful action',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 14),
            _timingTile(
              Icons.auto_awesome_rounded,
              const Color(0xFF4CAF50),
              'Abhijit Muhurta',
              'Most dependable all-purpose window',
              t.abhijit,
            ),
            _timingTile(
              Icons.self_improvement_rounded,
              const Color(0xFF66BB6A),
              'Brahma Muhurta',
              'Ideal for prayer, yoga & study',
              t.brahmaMuhurta,
            ),
            Divider(color: AppColors.textMuted.withAlpha(30), height: 26),
            const Text(
              'Inauspicious — avoid new beginnings',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            _timingTile(
              Icons.block_rounded,
              const Color(0xFFEF5350),
              'Rahu Kaal',
              'Hold off on starting ventures',
              t.rahuKaal,
            ),
            _timingTile(
              Icons.warning_amber_rounded,
              const Color(0xFFFF7043),
              'Yamaganda',
              'Delay important travel & deals',
              t.yamaganda,
            ),
            _timingTile(
              Icons.remove_circle_outline_rounded,
              const Color(0xFFFFA726),
              'Gulika Kaal',
              'Keep to routine, low-stakes tasks',
              t.gulika,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timingTile(
    IconData icon,
    Color color,
    String name,
    String purpose,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  purpose,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanchangBanner(
    BuildContext context,
    VedicHomeSummaryData summary,
  ) {
    return GestureDetector(
      onTap: () => _openFeatureSheet(context, 'Panchang', summary),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.gradientGold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panchang',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.panchang.tithi} · ${summary.panchang.nakshatra} · ${summary.panchang.yoga} · ${summary.panchang.karana}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.panchang.insight,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withAlpha(80)),
              ),
              child: const Text(
                'Live',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(label, style: Theme.of(context).textTheme.titleLarge);
  }

  Widget _buildRow(
    BuildContext context,
    List<_VedicFeature> features,
    VedicHomeSummaryData summary,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _buildFeatureCard(context, features[i], summary)),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    _VedicFeature feature,
    VedicHomeSummaryData summary,
  ) {
    return GestureDetector(
      onTap:
          feature.onTap ??
          () => _openFeatureSheet(context, feature.title, summary),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: feature.color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: feature.color.withAlpha(50)),
                  ),
                  child: Icon(
                    feature.icon,
                    color: feature.color.withAlpha(180),
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    feature.onTap != null
                        ? Icons.arrow_outward_rounded
                        : Icons.chevron_right_rounded,
                    color: feature.color.withAlpha(190),
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feature.title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              feature.subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (feature.details != null && feature.details!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                feature.details!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDataStatus(VedicHomeSummaryData summary) {
    final hasBirthData =
        widget.birthDate != null && widget.birthDate!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBirthData
              ? AppColors.health.withAlpha(80)
              : AppColors.accent.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasBirthData ? Icons.check_circle_outline : Icons.info_outline,
            color: hasBirthData ? AppColors.health : AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasBirthData
                  ? 'Birth details saved for ${summary.location.name} — Vedic charts, dasha, and remedies are now personalised.'
                  : 'Add your birth date, time & place in Profile for accurate Vedic calculations.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VedicFeature {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? details;
  final Color color;
  final VoidCallback? onTap;

  const _VedicFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.details,
    required this.color,
    this.onTap,
  });
}
