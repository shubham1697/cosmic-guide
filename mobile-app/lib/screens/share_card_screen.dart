import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/zodiac_signs_data.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shareable_chart_card.dart';
import '../widgets/starry_background.dart';

/// Preview + share flow for the user's "cosmic blueprint" card. Resolves the
/// Big 3 (Sun / Moon / Rising) from birth details when available — otherwise
/// estimates Moon & Rising from the Sun sign — then captures the card as a PNG
/// and opens the native share sheet.
class ShareCardScreen extends StatefulWidget {
  final String sunSign;
  final String? birthDate;
  final String? birthTime;
  final String? birthPlace;

  /// Reading tradition; when 'vedic' the ascendant is labelled "Lagna".
  final String? tradition;

  const ShareCardScreen({
    super.key,
    required this.sunSign,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.tradition,
  });

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  String _name = 'Stargazer';
  String _moonSign = '';
  String _risingSign = '';
  bool _isEstimated = true;
  bool _loading = true;
  bool _sharing = false;

  bool get _isVedic => widget.tradition == 'vedic';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName') ?? '';

    // Fallback estimation from the Sun sign (matches the Chart screen: Moon at
    // +4 signs, Rising at +8) so the card is always complete.
    final sunIdx = zodiacSigns.indexWhere((z) => z.name == widget.sunSign);
    var moon = sunIdx >= 0
        ? zodiacSigns[(sunIdx + 4) % 12].name
        : widget.sunSign;
    var rising = sunIdx >= 0
        ? zodiacSigns[(sunIdx + 8) % 12].name
        : widget.sunSign;
    var estimated = true;

    if ((widget.birthDate ?? '').isNotEmpty) {
      final chart = await ApiService.getBirthChart(
        birthDate: widget.birthDate!,
        birthTime: widget.birthTime,
        birthPlace: widget.birthPlace,
      );
      if (chart != null) {
        if (chart.big3.moonSign.isNotEmpty) moon = chart.big3.moonSign;
        if (chart.big3.risingSign.isNotEmpty) rising = chart.big3.risingSign;
        estimated = chart.big3.risingIsEstimated;
      }
    }

    if (!mounted) return;
    setState(() {
      _name = name.isNotEmpty ? name : 'Stargazer';
      _moonSign = moon;
      _risingSign = rising;
      _isEstimated = estimated;
      _loading = false;
    });
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    final ok = await ShareService.shareBoundary(
      _cardKey,
      text: _shareText(),
      subject: 'My Cosmic Blueprint',
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not prepare the card. Please try again.'),
        ),
      );
    }
  }

  String _shareText() {
    final rising = _isVedic ? 'Lagna' : 'Rising';
    return '✨ My Cosmic Blueprint ✨\n'
        'Sun in ${widget.sunSign} · Moon in $_moonSign · $rising in $_risingSign\n'
        'Discover yours on CosmicGuide 🔮';
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Share Your Stars', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: ShareableChartCard(
                              name: _name,
                              sunSign: widget.sunSign,
                              moonSign: _moonSign,
                              risingSign: _risingSign,
                              isEstimated: _isEstimated,
                              isVedic: _isVedic,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        'Post it to your story and pull your friends into the cosmos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted.withAlpha(200),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sharing ? null : _share,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(Icons.ios_share),
                          label: Text(_sharing ? 'Preparing…' : 'Share Card'),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
