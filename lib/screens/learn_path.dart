// Learn path: Duolingo-style winding lesson path with units.
import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'lesson_screen.dart';

class LearnPath extends StatelessWidget {
  const LearnPath({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final course = st.course;

    return Scaffold(
      body: Column(
        children: [
          const TopStatsBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: course.units.length,
              itemBuilder: (context, ui) {
                final unit = course.units[ui];
                final beforeUnits = course.units
                    .take(ui)
                    .expand((u) => u.lessons)
                    .length;
                return UnitSection(
                  unit: unit,
                  unitIndex: ui,
                  flatStart: beforeUnits,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UnitSection extends StatelessWidget {
  final Unit unit;
  final int unitIndex;
  final int flatStart;

  const UnitSection({
    super.key,
    required this.unit,
    required this.unitIndex,
    required this.flatStart,
  });

  Color get unitColor => _hexToColor(unit.colorHex);

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final done = unit.lessons
        .where((l) => st.lessonStars.containsKey(l.id))
        .length;
    final title = st.uiLocale == 'ar' ? unit.titleAr : unit.titleEn;

    return Column(
      children: [
        // Unit banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 18, 16, 22),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: unitColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: unitColor.withOpacity(0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('unit')} ${unitIndex + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$done/${unit.lessons.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        // Lesson nodes
        ...List.generate(unit.lessons.length, (li) {
          final lesson = unit.lessons[li];
          final flat = flatStart + li;
          final unlocked = st.isLessonUnlocked(flat);
          final stars = st.lessonStars[lesson.id];
          return PathNode(
            lesson: lesson,
            color: unitColor,
            unlocked: unlocked,
            stars: stars,
            isCurrent: unlocked && stars == null,
            onTap: unlocked
                ? () => _openLesson(context, lesson)
                : null,
          );
        }),
      ],
    );
  }

  void _openLesson(BuildContext context, Lesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)),
    );
  }
}

class PathNode extends StatelessWidget {
  final Lesson lesson;
  final Color color;
  final bool unlocked;
  final int? stars;
  final bool isCurrent;
  final VoidCallback? onTap;

  const PathNode({
    super.key,
    required this.lesson,
    required this.color,
    required this.unlocked,
    this.stars,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    // Winding path offsets (in an RTL-friendly way, alternate sides).
    final isEven = (st.lessonStars.length * 7 + lesson.id.hashCode) % 2 == 0;

    return Align(
      alignment:
          isEven ? Alignment(-0.25, 0) : Alignment(0.25, 0),
      child: Column(
        children: [
          if (isCurrent) _startBubble(context),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 74,
              height: 70,
              margin: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: unlocked
                    ? (stars != null ? AppColors.yellow : color)
                    : AppColors.locked,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: unlocked
                        ? (stars != null
                            ? AppColors.yellowDark
                            : color.withOpacity(0.6))
                        : AppColors.lockedDark,
                    offset: const Offset(0, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: unlocked
                    ? (stars != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.white, size: 30),
                              const SizedBox(height: 2),
                              Text(
                                '$stars/3',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : const Icon(Icons.play_arrow,
                            color: Colors.white, size: 34))
                    : const Icon(Icons.lock,
                        color: AppColors.lockedDark, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        context.tr('start'),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
