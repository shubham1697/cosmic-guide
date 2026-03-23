import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

class CompatibilityScreen extends StatefulWidget {
  const CompatibilityScreen({super.key});

  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  String? _sign1;
  String? _sign2;
  dynamic _result;
  bool _isChecking = false;

  Future<void> _checkCompatibility() async {
    if (_sign1 == null || _sign2 == null) return;
    setState(() => _isChecking = true);
    final result = await ApiService.checkCompatibility(_sign1!, _sign2!);
    if (mounted) {
      setState(() {
        _result = result;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Compatibility', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
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
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.love,
                      size: 32,
                    ),
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
              if (_result != null) _buildResultCard(),
            ],
          ),
        ),
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
              MockData.zodiacSigns.firstWhere((z) => z.name == selected).symbol,
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
            items: MockData.zodiacSigns.map((sign) {
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
                    MockData.zodiacSigns
                        .firstWhere((z) => z.name == _sign1)
                        .symbol,
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
                    MockData.zodiacSigns
                        .firstWhere((z) => z.name == _sign2)
                        .symbol,
                    style: const TextStyle(fontSize: 36),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '${_result.score}%',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _result.score >= 80
                      ? AppColors.health
                      : _result.score >= 60
                      ? AppColors.accent
                      : AppColors.love,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _result.score >= 80
                    ? 'Excellent Match!'
                    : _result.score >= 60
                    ? 'Promising Match'
                    : 'Challenging Match',
                style: TextStyle(
                  color: _result.score >= 80
                      ? AppColors.health
                      : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _result.description,
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
          _result.loveAdvice,
          Icons.favorite,
          AppColors.love,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Strengths Together',
          _result.strengthsTogether,
          Icons.flash_on,
          AppColors.accent,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Challenges',
          _result.challenges,
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
