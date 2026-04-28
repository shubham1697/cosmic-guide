import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Zodiac Match',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select two signs to check compatibility',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildSignPicker(
                  'Your Sign',
                  _sign1,
                  (v) => setState(() => _sign1 = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.favorite, color: AppColors.love, size: 32),
              ),
              Expanded(
                child: _buildSignPicker(
                  'Their Sign',
                  _sign2,
                  (v) => setState(() => _sign2 = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
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

  Widget _buildSignPicker(
    String label,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected != null
              ? AppColors.love.withAlpha(128)
              : AppColors.textMuted.withAlpha(51),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (selected != null) ...[
            Text(
              zodiacSigns.firstWhere((z) => z.name == selected).symbol,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 4),
          ],
          DropdownButton<String>(
            value: selected,
            hint: const Text(
              'Select',
              style: TextStyle(color: AppColors.textMuted),
            ),
            dropdownColor: AppColors.card,
            isExpanded: true,
            underline: const SizedBox(),
            items: zodiacSigns.map((sign) {
              return DropdownMenuItem(
                value: sign.name,
                child: Text(
                  '${sign.symbol} ${sign.name}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
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
            border: Border.all(color: AppColors.love.withAlpha(77)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    zodiacSigns.firstWhere((z) => z.name == _sign1).symbol,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.love,
                      size: 28,
                    ),
                  ),
                  Text(
                    zodiacSigns.firstWhere((z) => z.name == _sign2).symbol,
                    style: const TextStyle(fontSize: 36),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '${result.score}%',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: result.score >= 80
                      ? AppColors.health
                      : result.score >= 60
                      ? AppColors.accent
                      : AppColors.love,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.score >= 80
                    ? 'Excellent Match!'
                    : result.score >= 60
                    ? 'Promising Match'
                    : 'Challenging Match',
                style: TextStyle(
                  color: result.score >= 80
                      ? AppColors.health
                      : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
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
