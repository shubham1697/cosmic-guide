import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';
import '../widgets/score_ring.dart';

class CompatibilityScreen extends StatefulWidget {
  final bool embedded;

  const CompatibilityScreen({super.key, this.embedded = false});

  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  String? _sign1;
  String? _sign2;
  CompatibilityResult? _result;
  bool _isChecking = false;
  String? _errorMessage;

  Future<void> _checkCompatibility() async {
    if (_sign1 == null || _sign2 == null) return;
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    final result = await ApiService.checkCompatibility(_sign1!, _sign2!);
    if (mounted) {
      setState(() {
        _result = result;
        _isChecking = false;
        _errorMessage = result == null
            ? 'Could not fetch compatibility right now. Check backend connectivity and try again.'
            : null;
      });
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compatibility check failed. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Text(
            'Select two signs to reveal your cosmic chemistry',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildSignSelector(
                    'Your Sign',
                    _sign1,
                    () => _showSignPicker(
                      'Choose your sign',
                      _sign1,
                      (v) => setState(() => _sign1 = v),
                    ),
                  ),
                ),
                _buildHeartConnector(),
                Expanded(
                  child: _buildSignSelector(
                    'Their Sign',
                    _sign2,
                    () => _showSignPicker(
                      'Choose their sign',
                      _sign2,
                      (v) => setState(() => _sign2 = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_sign1 != null && _sign2 != null && !_isChecking)
                  ? _checkCompatibility
                  : null,
              icon: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.favorite),
              label: Text(
                _isChecking ? 'Matching Stars...' : 'Check Compatibility',
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.love, fontSize: 13),
              ),
            ),
          if (_result != null) _buildResultCard(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent(context);
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Compatibility', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: _buildContent(context),
      ),
    );
  }

  Color _elementColor(String element) {
    switch (element) {
      case 'Fire':
        return const Color(0xFFFF7043);
      case 'Earth':
        return const Color(0xFF66BB6A);
      case 'Air':
        return const Color(0xFF4FC3F7);
      case 'Water':
        return AppColors.mysticTeal;
      default:
        return AppColors.accent;
    }
  }

  IconData _elementIcon(String element) {
    switch (element) {
      case 'Fire':
        return Icons.local_fire_department;
      case 'Earth':
        return Icons.landscape;
      case 'Air':
        return Icons.air;
      case 'Water':
        return Icons.water_drop;
      default:
        return Icons.auto_awesome;
    }
  }

  String _elementHarmony(String e1, String e2) {
    if (e1 == e2) return 'Same element \u2014 deep, intuitive harmony';
    final pair = {e1, e2};
    if (pair.containsAll({'Fire', 'Air'})) {
      return 'Fire & Air \u2014 passion fuels ideas';
    }
    if (pair.containsAll({'Earth', 'Water'})) {
      return 'Earth & Water \u2014 grounded and nurturing';
    }
    if (pair.containsAll({'Fire', 'Water'})) {
      return 'Fire & Water \u2014 opposites that test each other';
    }
    if (pair.containsAll({'Air', 'Earth'})) {
      return 'Air & Earth \u2014 dreamer meets realist';
    }
    if (pair.containsAll({'Fire', 'Earth'})) {
      return 'Fire & Earth \u2014 drive meets stability';
    }
    if (pair.containsAll({'Air', 'Water'})) {
      return 'Air & Water \u2014 mind meets emotion';
    }
    return 'A unique blend of cosmic energies';
  }

  Widget _buildSignSelector(
    String label,
    String? selected,
    VoidCallback onTap,
  ) {
    final sign = selected != null
        ? zodiacSigns.firstWhere((z) => z.name == selected)
        : null;
    final active = sign != null;
    final elementColor = active
        ? _elementColor(sign.element)
        : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? elementColor.withAlpha(150)
                : AppColors.textMuted.withAlpha(45),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: elementColor.withAlpha(40),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (active) ...[
              Text(
                sign.symbol,
                style: TextStyle(fontSize: 44, color: elementColor),
              ),
              const SizedBox(height: 8),
              Text(
                sign.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sign.element,
                style: TextStyle(
                  color: elementColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.add_circle_outline,
                color: AppColors.textMuted,
                size: 44,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to select',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                'a zodiac sign',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeartConnector() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradientGold,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.favorite, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignPicker(
    String title,
    String? current,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AppColors.gradientCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(90),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                children: zodiacSigns.map((sign) {
                  final selected = sign.name == current;
                  final color = _elementColor(sign.element);
                  return GestureDetector(
                    onTap: () {
                      onSelected(sign.name);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? color.withAlpha(38) : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? color
                              : AppColors.textMuted.withAlpha(38),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            sign.symbol,
                            style: TextStyle(fontSize: 30, color: color),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sign.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sign.element,
                            style: TextStyle(
                              color: color.withAlpha(210),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final sign1 = zodiacSigns.firstWhere((z) => z.name == _sign1);
    final sign2 = zodiacSigns.firstWhere((z) => z.name == _sign2);
    final scoreColor = result.score >= 80
        ? AppColors.health
        : result.score >= 60
        ? AppColors.accent
        : AppColors.love;
    final matchLabel = result.score >= 80
        ? 'Excellent Match'
        : result.score >= 60
        ? 'Promising Match'
        : 'Challenging Match';
    final loveAdvice = result.loveAdvice.trim().isNotEmpty
        ? result.loveAdvice
        : 'No love advice available for this pair yet.';
    final strengths = result.strengthsTogether.trim().isNotEmpty
        ? result.strengthsTogether
        : 'Strength insights are still being prepared.';
    final challenges = result.challenges.trim().isNotEmpty
        ? result.challenges
        : 'Challenge insights are still being prepared.';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.gradientCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scoreColor.withAlpha(77)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPairSign(sign1),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.love,
                      size: 26,
                    ),
                  ),
                  _buildPairSign(sign2),
                ],
              ),
              const SizedBox(height: 24),
              ScoreRing(
                value: result.score / 100,
                label: '${result.score}%',
                color: scoreColor,
                size: 150,
              ),
              const SizedBox(height: 12),
              Text(
                matchLabel,
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 18),
              _buildElementHarmony(sign1, sign2),
              const SizedBox(height: 18),
              Text(
                result.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          'Love Advice',
          loveAdvice,
          Icons.favorite,
          AppColors.love,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Strengths Together',
          strengths,
          Icons.flash_on,
          AppColors.accent,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Challenges',
          challenges,
          Icons.warning_amber,
          AppColors.career,
        ),
      ],
    );
  }

  Widget _buildPairSign(ZodiacSign sign) {
    final color = _elementColor(sign.element);
    return Column(
      children: [
        Text(sign.symbol, style: TextStyle(fontSize: 40, color: color)),
        const SizedBox(height: 4),
        Text(
          sign.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _elementChip(String element) {
    final color = _elementColor(element);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_elementIcon(element), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            element,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementHarmony(ZodiacSign s1, ZodiacSign s2) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _elementChip(s1.element),
            const SizedBox(width: 10),
            const Icon(Icons.add, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 10),
            _elementChip(s2.element),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _elementHarmony(s1.element, s2.element),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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
