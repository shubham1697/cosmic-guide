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
            : 'Your current Vimshottari period summary based on your birth chart.';
      case 'Doshas':
        return summary.dosha == null
            ? 'Dosha detection requires birth chart calculations.'
            : 'This preview shows the major dosha signals currently detected from your chart.';
      case 'Remedies':
        return summary.remedy == null
            ? 'Traditional remedies appear after chart-based signals are available.'
            : 'These are traditional suggestions linked to your current Vedic indicators.';
      case 'Hindu Calendar':
        return 'Monthly Hindu calendar context including the current month and next observed festival.';
      case 'Muhurta':
        return 'A preview of a favorable daily time window based on the current day context.';
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
          _detailCard('Recommended Window', [
            summary.muhurta.label,
            '${summary.muhurta.startsAt} - ${summary.muhurta.endsAt}',
            summary.muhurta.note,
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
                _buildSectionLabel(context, 'Daily & Calendar'),
                const SizedBox(height: 14),
                _buildPanchangBanner(context, summary),
                const SizedBox(height: 12),
                _buildRow(context, [
                  _VedicFeature(
                    icon: Icons.calendar_month_rounded,
                    title: 'Hindu Calendar',
                    subtitle:
                        '${summary.calendar.monthName} ${summary.calendar.samvatYear}',
                    details:
                        '${summary.calendar.nextFestivalName} · ${summary.calendar.nextFestivalDate}',
                    color: AppColors.accent,
                  ),
                  _VedicFeature(
                    icon: Icons.access_time_rounded,
                    title: 'Muhurta',
                    subtitle: summary.muhurta.label,
                    details:
                        '${summary.muhurta.startsAt} - ${summary.muhurta.endsAt}',
                    color: Colors.teal,
                  ),
                ], summary),
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
          Column(
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
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: Text(
                  '${summary.panchang.tithi} · ${summary.panchang.nakshatra}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Preview',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
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
            const SizedBox(height: 8),
            Text(
              'Tap for detail view',
              style: TextStyle(
                color: feature.color.withAlpha(180),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
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
