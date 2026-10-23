// Celebratory confetti burst for lesson success (v2.0).
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class ConfettiBurst extends StatefulWidget {
  final int count;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    this.count = 70,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  final double startX; // 0..1
  final double fallSpeed; // screen heights per run
  final double drift;
  final double size;
  final Color color;
  final double spin;
  final bool isCircle;

  _Particle(Random rng)
      : startX = rng.nextDouble(),
        fallSpeed = 0.7 + rng.nextDouble() * 0.6,
        drift = (rng.nextDouble() - 0.5) * 0.25,
        size = 5 + rng.nextDouble() * 7,
        color = [
          AppColors.green,
          AppColors.blue,
          AppColors.yellow,
          AppColors.orange,
          AppColors.red,
          AppColors.purple,
        ][rng.nextInt(6)],
        spin = (rng.nextDouble() - 0.5) * 6,
        isCircle = rng.nextBool();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(widget.count, (_) => _Particle(rng));
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (_ctrl.isCompleted) return const SizedBox.shrink();
        return CustomPaint(
          painter: _ConfettiPainter(_particles, _ctrl.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1

  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final y = (p.fallSpeed * t) * size.height;
      final x = (p.startX + p.drift * t) * size.width;
      // Fade out in the last 25%.
      final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 2 * pi);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
