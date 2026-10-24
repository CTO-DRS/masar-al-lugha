// Rafiq & Friends — companion widgets (v4.5).
//
// The shape-drawn companions get their personality from lib/mascot.dart
// (engine: cast, unlocks, lines). This file only renders:
//   * Mascot        — a character body reacting to a mood
//   * MascotBubble  — companion + speech bubble for engine lines
//
// Back-compat: `MascotMood` is re-exported from the engine, and Mascot
// defaults to `rafiq`, so every pre-4.5 call site keeps compiling.
import 'package:flutter/material.dart';

import '../mascot.dart' show MascotMood, mascotById;
import '../theme.dart';

export '../mascot.dart' show MascotMood;

class _Palette {
  final Color body;
  final Color shadow;
  final Color belly;
  final Color ear;
  final Color accent; // beak / nose
  final bool hasBeak;

  const _Palette({
    required this.body,
    required this.shadow,
    required this.belly,
    required this.ear,
    required this.accent,
    required this.hasBeak,
  });
}

const _purpleDark = Color(0xFFB05EE0);
const _purpleLight = Color(0xFFF1E4FF);
const _orangeDark = Color(0xFFE07C00);

_Palette _paletteFor(String id) {
  switch (id) {
    case 'farah':
      return const _Palette(
        body: AppColors.orange,
        shadow: _orangeDark,
        belly: AppColors.yellow,
        ear: _orangeDark,
        accent: AppColors.yellowDark,
        hasBeak: true,
      );
    case 'nur':
      return const _Palette(
        body: AppColors.blue,
        shadow: AppColors.blueDark,
        belly: AppColors.blueLight,
        ear: AppColors.blueDark,
        accent: AppColors.ink,
        hasBeak: false,
      );
    case 'zayd':
      return const _Palette(
        body: AppColors.yellow,
        shadow: AppColors.yellowDark,
        belly: AppColors.bg,
        ear: AppColors.yellowDark,
        accent: AppColors.ink,
        hasBeak: false,
      );
    case 'salma':
      return const _Palette(
        body: AppColors.purple,
        shadow: _purpleDark,
        belly: _purpleLight,
        ear: _purpleDark,
        accent: AppColors.ink,
        hasBeak: false,
      );
    default: // rafiq
      return const _Palette(
        body: AppColors.green,
        shadow: AppColors.greenDark,
        belly: AppColors.greenLight,
        ear: AppColors.green,
        accent: AppColors.orange,
        hasBeak: true,
      );
  }
}

class Mascot extends StatelessWidget {
  final double size;
  final MascotMood mood;
  final String characterId;

  const Mascot({
    super.key,
    this.size = 120,
    this.mood = MascotMood.happy,
    this.characterId = 'rafiq',
  });

  @override
  Widget build(BuildContext context) {
    final p = _paletteFor(mascotById(characterId).id);
    final eyeOffset = mood == MascotMood.sad ? 2.0 : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ears / crest behind the body
          ..._ears(size, p),
          // body
          Container(
            width: size,
            height: size * 0.92,
            decoration: BoxDecoration(
              color: p.body,
              borderRadius: BorderRadius.circular(size * 0.42),
              boxShadow: [
                BoxShadow(
                    color: p.shadow, offset: const Offset(0, 4), blurRadius: 0),
              ],
            ),
          ),
          // belly
          Positioned(
            bottom: size * 0.06,
            child: Container(
              width: size * 0.55,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: p.belly,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(size * 0.3)),
              ),
            ),
          ),
          // wings (birds)
          if (p.hasBeak) ...[
            Positioned(
              left: -size * 0.02,
              top: size * 0.34,
              child: _wing(size, p.shadow),
            ),
            Positioned(
              right: -size * 0.02,
              top: size * 0.34,
              child: _wing(size, p.shadow),
            ),
          ],
          // eyes
          Positioned(
            top: size * 0.18,
            child: Row(
              children: [
                _eye(size, eyeOffset),
                SizedBox(width: size * 0.10),
                _eye(size, eyeOffset),
              ],
            ),
          ),
          // beak (birds) or nose (furry)
          Positioned(
            top: p.hasBeak ? size * 0.44 : size * 0.46,
            child: Container(
              width: p.hasBeak ? size * 0.16 : size * 0.10,
              height: p.hasBeak ? size * 0.13 : size * 0.08,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(size * 0.1),
                  bottomRight: Radius.circular(size * 0.1),
                  topLeft: Radius.circular(size * 0.05),
                  topRight: Radius.circular(size * 0.05),
                ),
              ),
            ),
          ),
          if (mood == MascotMood.celebrate)
            Positioned(
              top: -size * 0.02,
              right: size * 0.02,
              child: Text('⭐', style: TextStyle(fontSize: size * 0.22)),
            ),
        ],
      ),
    );
  }

  List<Widget> _ears(double size, _Palette p) {
    final id = mascotById(characterId).id;
    switch (id) {
      case 'farah': // single crest
        return [
          Positioned(
            top: 0,
            child: Container(
              width: size * 0.12,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: p.ear,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(size * 0.06)),
              ),
            ),
          ),
        ];
      case 'nur': // two small triangle ears
      case 'zayd': // two larger triangle ears
        final w = id == 'zayd' ? 0.18 : 0.14;
        final h = id == 'zayd' ? 0.22 : 0.16;
        return [
          Positioned(
            top: 0,
            left: size * 0.16,
            child: _triangle(size * w, size * h, p.ear),
          ),
          Positioned(
            top: 0,
            right: size * 0.16,
            child: _triangle(size * w, size * h, p.ear),
          ),
        ];
      case 'salma': // two long rounded bunny ears
        return [
          Positioned(
            top: -size * 0.10,
            left: size * 0.24,
            child: Container(
              width: size * 0.13,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: p.ear,
                borderRadius: BorderRadius.circular(size * 0.07),
              ),
            ),
          ),
          Positioned(
            top: -size * 0.10,
            right: size * 0.24,
            child: Container(
              width: size * 0.13,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: p.ear,
                borderRadius: BorderRadius.circular(size * 0.07),
              ),
            ),
          ),
        ];
      default: // rafiq: owl tufts
        return [
          Positioned(
            top: 0,
            left: size * 0.22,
            child: _tuft(size, p.body),
          ),
          Positioned(
            top: 0,
            right: size * 0.22,
            child: _tuft(size, p.body),
          ),
        ];
    }
  }

  Widget _triangle(double w, double h, Color c) => CustomPaint(
        size: Size(w, h),
        painter: _TrianglePainter(c),
      );

  Widget _wing(double size, Color c) => Container(
        width: size * 0.16,
        height: size * 0.34,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(size * 0.1),
        ),
      );

  Widget _tuft(double size, Color c) => Container(
        width: size * 0.10,
        height: size * 0.14,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(size * 0.06),
          ),
        ),
      );

  Widget _eye(double size, double sadOffset) {
    return Container(
      width: size * 0.22,
      height: size * 0.22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: sadOffset * (size / 120)),
        child: Container(
          width: size * 0.10,
          height: size * 0.10,
          decoration: BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Companion + speech bubble. The text comes from MascotEngine lines.
/// Entrance: gentle scale+fade (skipped when [animate] is false so
/// reduce-motion settings can disable it).
class MascotBubble extends StatelessWidget {
  final String characterId;
  final MascotMood mood;
  final String text;
  final double size;
  final bool animate;

  /// v4.5: set false when a large companion is already visible next to the
  /// bubble (result screens) — renders the bubble text only.
  final bool showAvatar;

  const MascotBubble({
    super.key,
    required this.characterId,
    required this.mood,
    required this.text,
    this.size = 96,
    this.animate = true,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) ...[
          Mascot(size: size, mood: mood, characterId: characterId),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.line, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: context.line,
                        offset: const Offset(0, 3),
                        blurRadius: 0),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: context.bodyText,
                  ),
                ),
              ),
              // bubble tail pointing at the companion
              Positioned(
                top: 2,
                left: -5,
                child: Transform.rotate(
                  angle: 3.14159 / 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: context.card,
                      border: Border(
                        left: BorderSide(color: context.line, width: 2),
                        top: BorderSide(color: context.line, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!animate) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child)),
      child: body,
    );
  }
}
