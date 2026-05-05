import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';
import 'tarot_spread_screen.dart';

class TarotScreen extends StatefulWidget {
  const TarotScreen({super.key});

  @override
  State<TarotScreen> createState() => _TarotScreenState();
}

class _TarotScreenState extends State<TarotScreen>
    with SingleTickerProviderStateMixin {
  TarotCard? _drawnCard;
  bool _isRevealed = false;
  bool _isReversed = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _drawCard() async {
    final result = await ApiService.drawTarotCard();
    if (result == null) return;
    setState(() {
      _drawnCard = result.card;
      _isRevealed = false;
      _isReversed = result.isReversed;
    });
    _flipController.reset();
  }

  void _revealCard() {
    _flipController.forward();
    setState(() => _isRevealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Tarot Reading', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Draw Your Card',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the card to reveal your destiny',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 40),
                _buildCard(),
                const SizedBox(height: 32),
                if (_drawnCard != null && _isRevealed && _isReversed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE53935).withAlpha(128),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync,
                          color: Color(0xFFE53935),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reversed',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_drawnCard != null && _isRevealed) _buildInterpretation(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _drawCard,
                  icon: const Icon(Icons.style),
                  label: Text(
                    _drawnCard == null ? 'Draw a Card' : 'Draw Again',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TarotSpreadScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.view_column, color: AppColors.purple),
                  label: const Text(
                    'Three-Card Spread',
                    style: TextStyle(color: AppColors.purple),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.purple),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    if (_drawnCard == null) {
      return _buildCardBack();
    }

    return GestureDetector(
      onTap: _isRevealed ? null : _revealCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isBack = _flipAnimation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * pi),
            child: isBack ? _buildCardBack() : _buildCardFace(),
          );
        },
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 220,
      height: 340,
      decoration: BoxDecoration(
        gradient: AppColors.gradientPurple,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withAlpha(102),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Tap to\nReveal',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    if (_drawnCard == null) return const SizedBox();
    final borderColor = _isReversed
        ? const Color(0xFFE53935)
        : AppColors.accent;
    final glowColor = _isReversed
        ? const Color(0xFFE53935).withAlpha(77)
        : AppColors.accent.withAlpha(77);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: 220,
        height: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isReversed
                ? [const Color(0xFF3E1A1A), const Color(0xFF1A1A2E)]
                : [const Color(0xFF2D1B69), const Color(0xFF1A1A2E)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Transform.rotate(
          angle: _isReversed ? pi : 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _drawnCard!.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _drawnCard!.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _drawnCard!.meaning,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterpretation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isReversed ? Icons.sync : Icons.auto_awesome,
                color: _isReversed ? const Color(0xFFE53935) : AppColors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isReversed ? 'Reversed Reading' : 'Interpretation',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isReversed
                      ? const Color(0xFFE53935)
                      : AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isReversed && _drawnCard!.reversedInterpretation.isNotEmpty
                ? _drawnCard!.reversedInterpretation
                : _drawnCard!.interpretation,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
