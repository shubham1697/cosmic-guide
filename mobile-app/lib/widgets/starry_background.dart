import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StarryBackground extends StatefulWidget {
  final Widget child;
  const StarryBackground({super.key, required this.child});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    final random = Random();
    _stars = List.generate(
      50,
      (_) => _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 0.5,
        opacity: random.nextDouble() * 0.5 + 0.2,
        speed: random.nextDouble() * 0.5 + 0.5,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _StarPainter(_stars, _controller.value),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _Star {
  final double x, y, size, opacity, speed;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double animValue;

  _StarPainter(this.stars, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final opacity =
          (star.opacity *
                  (0.5 + 0.5 * (animValue * star.speed).clamp(0.0, 1.0)))
              .clamp(0.0, 1.0);
      final paint = Paint()
        ..color = AppColors.starYellow.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}
