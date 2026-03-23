import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

class FortuneScreen extends StatefulWidget {
  final String userSign;
  const FortuneScreen({super.key, required this.userSign});

  @override
  State<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends State<FortuneScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedTopic;
  String? _selectedMood;
  String? _fortune;
  bool _isGenerating = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _generateFortune() async {
    if (_selectedTopic == null || _selectedMood == null) return;
    setState(() => _isGenerating = true);
    final fortune = await ApiService.generateFortune(
      widget.userSign,
      _selectedTopic!,
      _selectedMood!,
    );
    if (mounted) {
      setState(() {
        _fortune = fortune;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Fortune Generator',
            style: GoogleFonts.playfairDisplay(),
          ),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildCrystalBall(),
              const SizedBox(height: 32),
              _buildTopicSelector(),
              const SizedBox(height: 20),
              _buildMoodSelector(),
              const SizedBox(height: 32),
              _buildGenerateButton(),
              const SizedBox(height: 24),
              if (_fortune != null) _buildFortuneCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrystalBall() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.purple.withAlpha(
                  (128 + 77 * _glowController.value).toInt(),
                ),
                AppColors.deepPurple.withAlpha(
                  (77 + 51 * _glowController.value).toInt(),
                ),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withAlpha(
                  (77 + 51 * _glowController.value).toInt(),
                ),
                blurRadius: 30 + 10 * _glowController.value,
                spreadRadius: 5 + 5 * _glowController.value,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, size: 56, color: AppColors.accent),
          ),
        );
      },
    );
  }

  Widget _buildTopicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Topic',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: MockData.fortuneTopics.map((topic) {
            final isSelected = _selectedTopic == topic;
            return GestureDetector(
              onTap: () => setState(() => _selectedTopic = topic),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.gradientPurple : null,
                  color: isSelected ? null : AppColors.card,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.purple
                        : AppColors.textMuted.withAlpha(77),
                  ),
                ),
                child: Text(
                  topic,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Mood',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: MockData.moods.map((mood) {
            final isSelected = _selectedMood == mood;
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.gradientGold : null,
                  color: isSelected ? null : AppColors.card,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textMuted.withAlpha(77),
                  ),
                ),
                child: Text(
                  mood,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
            (_selectedTopic != null && _selectedMood != null && !_isGenerating)
            ? _generateFortune
            : null,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isGenerating ? 'Consulting the Stars...' : 'Generate Fortune',
        ),
      ),
    );
  }

  Widget _buildFortuneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(38),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
          const SizedBox(height: 16),
          Text(
            _fortune!,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              color: AppColors.textPrimary,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
