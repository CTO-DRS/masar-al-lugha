// Common small widgets: stat chip, hearts row, progress ring, top bar.
// v4.0: dark-mode-aware surfaces; min 48dp touch targets (a11y).
// v5.11: MemoryHintLine — one rule-based memory hint under a card back.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../insights.dart';
import '../models.dart';
import '../scope.dart';
import '../theme.dart';

class StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.line, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.bodyText)),
        ],
      ),
    );
  }
}

class HeartsRow extends StatelessWidget {
  final int hearts;
  const HeartsRow({super.key, required this.hearts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Semantics(
            label: '${i < hearts ? hearts : 0} hearts left',
            excludeSemantics: true,
            child: Icon(
              i < hearts ? Icons.favorite : Icons.favorite_border,
              color: i < hearts ? AppColors.red : context.lockedText,
              size: 22,
            ),
          ),
        );
      }),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.stroke = 12,
    this.color,
    this.track,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              color: color ?? AppColors.green,
              track: track ?? context.line,
              stroke: stroke,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      // v5.17 (Phase-1 audit L-3): the track was not compared, so a
      // dark-mode flip with unchanged progress kept the old track color.
      old.track != track;
}

/// v5.11: one personalized memory hint, rendered under a card's back side
/// when [Insights.memoryHint] fires for it. The rules are documented next
/// to the engine; this widget only renders the localized template with its
/// params. When no rule matches (or the card is unseen) it renders
/// nothing — silence beats noise.
class MemoryHintLine extends StatelessWidget {
  final CardData? card;

  const MemoryHintLine({super.key, this.card});

  @override
  Widget build(BuildContext context) {
    if (card == null || card!.reps == 0) return const SizedBox.shrink();
    final tip = Insights.memoryHint(card!);
    if (tip == null) return const SizedBox.shrink();
    // Engine-only params (confusion ids) never carry display text.
    final params = <String, String>{...tip.params}
      ..remove('idA')
      ..remove('idB');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 14, color: context.mutedText),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              context.trF(tip.key, params),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
