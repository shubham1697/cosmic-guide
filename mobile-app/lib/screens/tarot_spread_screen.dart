import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

class TarotSpreadScreen extends StatefulWidget {
  const TarotSpreadScreen({super.key});

  @override
  State<TarotSpreadScreen> createState() => _TarotSpreadScreenState();
}

class _TarotSpreadScreenState extends State<TarotSpreadScreen>
    with TickerProviderStateMixin {
  final List<TarotCard?> _cards = [null, null, null];
  final List<bool> _reversed = [false, false, false];
  final List<bool> _revealed = [false, false, false];
  final List<AnimationController> _flipControllers = [];
  bool _isDrawing = false;
  bool _allDrawn = false;

  static const _labels = ['Past', 'Present', 'Future'];
  static const _icons = [Icons.history, Icons.circle, Icons.auto_awesome];
  static const _colors = [
    AppColors.textMuted,
    AppColors.accent,
    AppColors.purple,
  ];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _flipControllers.add(
        AnimationController(
          duration: const Duration(milliseconds: 700),
          vsync: this,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _flipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _drawSpread() async {
    setState(() {
      _isDrawing = true;
      _allDrawn = false;
      for (var i = 0; i < 3; i++) {
        _cards[i] = null;
        _revealed[i] = false;
        _flipControllers[i].reset();
      }
    });

    for (var i = 0; i < 3; i++) {
      final result = await ApiService.drawTarotCard();
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _cards[i] = result.card;
          _reversed[i] = result.isReversed;
        });
      }
      if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isDrawing = false;
      _allDrawn = _cards.every((c) => c != null);
    });
  }

  void _revealCard(int index) {
    if (_cards[index] == null || _revealed[index]) return;
    _flipControllers[index].forward();
    setState(() => _revealed[index] = true);
  }

  void _revealAll() {
    for (var i = 0; i < 3; i++) {
      if (!_revealed[i] && _cards[i] != null) {
        Future.delayed(Duration(milliseconds: i * 200), () {
          if (mounted) _revealCard(i);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Three-Card Spread',
            style: GoogleFonts.playfairDisplay(),
          ),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Past • Present • Future',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reveal the timeline of your journey',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) => _buildSpreadCard(i)),
              ),
              const SizedBox(height: 24),
              if (_allDrawn && !_revealed.every((r) => r))
                TextButton.icon(
                  onPressed: _revealAll,
                  icon: const Icon(Icons.visibility, color: AppColors.accent),
                  label: const Text(
                    'Reveal All',
                    style: TextStyle(color: AppColors.accent),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isDrawing ? null : _drawSpread,
                icon: _isDrawing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.style),
                label: Text(
                  _isDrawing
                      ? 'Drawing...'
                      : (_allDrawn ? 'Draw Again' : 'Draw Three Cards'),
                ),
              ),
              const SizedBox(height: 32),
              ..._buildInterpretations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpreadCard(int index) {
    final card = _cards[index];
    final width = (MediaQuery.of(context).size.width - 60) / 3 - 8;
    final height = width * 1.55;

    return Column(
      children: [
        Text(
          _labels[index],
          style: TextStyle(
            color: _colors[index],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          height: height,
          child: card == null
              ? _buildEmptySlot(width, height, index)
              : GestureDetector(
                  onTap: () => _revealCard(index),
                  child: AnimatedBuilder(
                    animation: _flipControllers[index],
                    builder: (context, child) {
                      final value = _flipControllers[index].value;
                      final isBack = value < 0.5;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(value * pi),
                        child: isBack
                            ? _buildMiniCardBack(width, height)
                            : _buildMiniCardFace(index, width, height),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySlot(double width, double height, int index) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colors[index].withAlpha(77),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Icon(
          _icons[index],
          color: _colors[index].withAlpha(100),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMiniCardBack(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.gradientPurple,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withAlpha(77),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, color: AppColors.accent, size: 24),
      ),
    );
  }

  Widget _buildMiniCardFace(int index, double width, double height) {
    final card = _cards[index]!;
    final isRev = _reversed[index];
    final borderColor = isRev ? const Color(0xFFE53935) : AppColors.accent;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isRev
                ? [const Color(0xFF3E1A1A), const Color(0xFF1A1A2E)]
                : [const Color(0xFF2D1B69), const Color(0xFF1A1A2E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Transform.rotate(
          angle: isRev ? pi : 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.number,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
              const SizedBox(height: 4),
              Text(
                card.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInterpretations() {
    final widgets = <Widget>[];
    for (var i = 0; i < 3; i++) {
      if (_revealed[i] && _cards[i] != null) {
        final card = _cards[i]!;
        final isRev = _reversed[i];
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colors[i].withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icons[i], color: _colors[i], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_labels[i]} — ${card.name}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colors[i],
                      ),
                    ),
                    if (isRev) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Rev',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isRev && card.reversedInterpretation.isNotEmpty
                      ? card.reversedInterpretation
                      : card.interpretation,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
