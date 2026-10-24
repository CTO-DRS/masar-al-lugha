// Learn path: Duolingo-style winding lesson path with units.
// v4.0: "continue where you left off" hero card (M4), placement-test entry
// (M9), stable node sides (M7), and a weak-words practice launcher (H4).
import 'package:flutter/material.dart';

import '../models.dart';
import '../path.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'home_shell.dart';
import 'lesson_screen.dart';
import 'path_setup_screen.dart';
import 'placement_screen.dart';

class LearnPath extends StatelessWidget {
  final void Function(int tab)? openTab;
  const LearnPath({super.key, this.openTab});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final course = st.course;

    // v4.11: when a path plan is active, its units lead the list in
    // pedagogical order; the remaining units follow a divider (never
    // hidden — the plan re-orders, it does not lock).
    final plan = st.activePathPlan;
    final entries = <Object>[]; // int = unit index, String = divider marker
    if (plan == null || plan.unitIndices.isEmpty) {
      for (var i = 0; i < course.units.length; i++) {
        entries.add(i);
      }
    } else {
      final planSet = plan.unitIndices.toSet();
      var otherCount = 0;
      for (var i = 0; i < course.units.length; i++) {
        if (!planSet.contains(i)) otherCount++;
      }
      for (final ui in plan.unitIndices) {
        entries.add(ui);
      }
      if (otherCount > 0) {
        entries.add('divider');
        for (var i = 0; i < course.units.length; i++) {
          if (!planSet.contains(i)) entries.add(i);
        }
      }
    }

    return Scaffold(
      body: Column(
        children: [
          const TopStatsBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: entries.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _HomeHero(openTab: openTab);
                }
                final e = entries[i - 1];
                if (e is String) {
                  return _OtherUnitsDivider(
                      count: _othersAfterDivider(entries));
                }
                final ui = e as int;
                return UnitSection(
                  unit: course.units[ui],
                  unitIndex: ui,
                  flatStart: _flatStart(course, ui),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _othersAfterDivider(List<Object> entries) {
    final idx = entries.indexOf('divider');
    if (idx < 0) return 0;
    var n = 0;
    for (var i = idx + 1; i < entries.length; i++) {
      if (entries[i] is int) n++;
    }
    return n;
  }

  static int _flatStart(Course course, int unitIndex) =>
      course.units.take(unitIndex).fold(0, (n, u) => n + u.lessons.length);
}

// v4.11: divider between the learner's planned units and the rest of the
// course — the plan re-orders the path, it never hides content.
class _OtherUnitsDivider extends StatelessWidget {
  final int count;
  const _OtherUnitsDivider({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz, size: 16, color: context.mutedText),
                const SizedBox(width: 5),
                Text(
                  '${context.tr('pathOtherUnits')} ($count)',
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// v4.11: compact banner of the active path plan — field emoji + name, the
// (effective) tier, plan size, and edit/remove actions.
class _PlanBanner extends StatelessWidget {
  final PathPlan plan;
  const _PlanBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final domainName = context.tr(pathDomainL10nKey(plan.domain));
    final tierName = context.tr(pathTierL10nKey(plan.effectiveTier));
    final stats = context.trF('pathPlanStats',
        {'u': '${plan.unitIndices.length}', 'l': '${plan.lessonCount}'});

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(pathDomainEmoji(plan.domain),
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('pathPlanBanner')}: $domainName · $tierName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    Text(
                      stats,
                      style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('pathEditPlan'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, size: 18),
                color: AppColors.green,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PathSetupScreen(),
                  ));
                },
              ),
              IconButton(
                tooltip: context.tr('pathClearPlan'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                color: context.mutedText,
                onPressed: () => st.clearPathPlan(st.courseId),
              ),
            ],
          ),
          if (plan.tierRelaxed)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
              child: Text(
                context.tr('tierRelaxedNote'),
                style: TextStyle(
                    color: context.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// v4.0 hero: points straight at the next learning step (audit M4).
class _HomeHero extends StatelessWidget {
  final void Function(int tab)? openTab;
  const _HomeHero({this.openTab});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final course = st.course;
    final plan = st.activePathPlan; // v4.11

    // Next lesson = first unlocked, not-yet-completed lesson.
    Lesson? next;
    var flat = 0;
    for (var i = 0; i < course.allLessons.length; i++) {
      if (st.isLessonUnlocked(i) &&
          !st.lessonStars.containsKey(course.allLessons[i].id)) {
        next = course.allLessons[i];
        flat = i;
        break;
      }
    }
    // Due reviews among unlocked vocab.
    final now = DateTime.now().millisecondsSinceEpoch;
    var dueCount = 0;
    for (final l in course.allLessons) {
      if (!st.lessonStars.containsKey(l.id)) continue;
      for (final v in l.vocab) {
        final c = st.cardFor(v.id);
        if (c != null && c.dueEpochMs <= now) dueCount++;
      }
    }
    final lessonsDone = st.lessonsCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.line, width: 2),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // v4.11: the active path plan — field × level with edit/remove.
            if (plan != null) ...[
              _PlanBanner(plan: plan),
              const SizedBox(height: 12),
            ],
            // v4.9: the companion greets you on the home path (time of day),
            // taps → fresh encouragement, mouth synced to the typewriter.
            _HomeCompanion(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(tr('continueLearning'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                Text(
                  '${tr('unitProgress')} $lessonsDone/${course.allLessons.length}',
                  style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (next != null) ...[
              Text(
                '${tr('unit')} ${_unitNoOf(course, flat)} · ${st.uiLocale == 'ar' ? next.titleAr : next.titleEn}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: tr('start'),
                      icon: Icons.play_arrow,
                      height: 46,
                      fontSize: 15,
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LessonScreen(lesson: next!),
                        ));
                      },
                    ),
                  ),
                  if (dueCount > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChunkyButton(
                        label: '$dueCount · ${tr('startReview')}',
                        color: AppColors.blue,
                        colorDark: AppColors.blueDark,
                        height: 46,
                        fontSize: 14,
                        onPressed: () => openTab?.call(1),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Text('🎉 ${tr('goalDone')}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ],
            // v4.11: path setup — always available, plan or not.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PathSetupScreen(),
                ));
              },
              child: Row(
                children: [
                  Icon(Icons.alt_route, size: 18, color: context.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tr('pathSetupBtn'),
                        style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: context.mutedText),
                ],
              ),
            ),
            // Placement entry: only when this course is still untouched.
            if (lessonsDone == 0 &&
                (st.placementDone[st.courseId] != true)) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PlacementScreen(),
                  ));
                },
                child: Row(
                  children: [
                    Icon(Icons.quiz, size: 18, color: context.mutedText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(tr('placementTitle'),
                          style: TextStyle(
                              color: context.mutedText,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: context.mutedText),
                  ],
                ),
              ),
            ],
            // v4.1 (ROADMAP item 4): re-test lane for returning users who
            // feel misplaced. Confirming a result overwrites placementSkip;
            // completed lessons keep their stars either way.
            if (st.placementDone[st.courseId] == true) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PlacementScreen(),
                  ));
                },
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18, color: context.mutedText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(tr('placementRetest'),
                          style: TextStyle(
                              color: context.mutedText,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: context.mutedText),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _unitNoOf(Course course, int flat) {
    var acc = 0;
    for (var u = 0; u < course.units.length; u++) {
      acc += course.units[u].lessons.length;
      if (flat < acc) return u + 1;
    }
    return course.units.length;
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
    final done =
        unit.lessons.where((l) => st.lessonStars.containsKey(l.id)).length;
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
                  color: unitColor.withValues(alpha: 0.55),
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
                        color: Colors.white.withValues(alpha: 0.85),
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
                  color: Colors.white.withValues(alpha: 0.25),
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
              const SizedBox(width: 8),
              // v4.2: self-referenced CEFR tag on every unit banner
              // (docs/CONTENT_AUDIT.md — not an official certification).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unit.cefr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13),
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
            flatIndex: flat,
            color: unitColor,
            unlocked: unlocked,
            stars: stars,
            isCurrent: unlocked && stars == null,
            onTap: unlocked ? () => _openLesson(context, lesson) : null,
          );
        }),
      ],
    );
  }

  void _openLesson(BuildContext context, Lesson lesson) {
    // v4.3: pick a lesson style — classic mixed drills, sentence mining or
    // audio-first listening. All three run on the same corpus and progress.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        String tr(String k) => sheetCtx.tr(k);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('lessonModes'),
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                _modeTile(
                  sheetCtx,
                  tr,
                  Icons.menu_book,
                  AppColors.green,
                  'modeClassic',
                  'modeClassicSub',
                  () => _pushLesson(
                      context, sheetCtx, lesson, LessonMode.classic),
                ),
                const SizedBox(height: 10),
                _modeTile(
                  sheetCtx,
                  tr,
                  Icons.notes,
                  AppColors.blue,
                  'modeSentences',
                  'modeSentencesSub',
                  () => _pushLesson(
                      context, sheetCtx, lesson, LessonMode.sentences),
                ),
                const SizedBox(height: 10),
                _modeTile(
                  sheetCtx,
                  tr,
                  Icons.headphones,
                  AppColors.yellowDark,
                  'modeAudio',
                  'modeAudioSub',
                  () =>
                      _pushLesson(context, sheetCtx, lesson, LessonMode.audio),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pushLesson(BuildContext pageCtx, BuildContext sheetCtx, Lesson lesson,
      LessonMode mode) {
    Navigator.of(sheetCtx).pop();
    Navigator.of(pageCtx).push(MaterialPageRoute(
      builder: (_) => LessonScreen(lesson: lesson, mode: mode),
    ));
  }

  Widget _modeTile(
    BuildContext ctx,
    String Function(String) tr,
    IconData icon,
    Color color,
    String titleKey,
    String subKey,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ctx.softBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ctx.line, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(titleKey),
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(tr(subKey),
                      style: TextStyle(color: ctx.mutedText, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ctx.mutedText),
          ],
        ),
      ),
    );
  }
}

class PathNode extends StatelessWidget {
  final Lesson lesson;
  final int flatIndex;
  final Color color;
  final bool unlocked;
  final int? stars;
  final bool isCurrent;
  final VoidCallback? onTap;

  const PathNode({
    super.key,
    required this.lesson,
    required this.flatIndex,
    required this.color,
    required this.unlocked,
    this.stars,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // v4.0 fix (audit M7): node side comes from the stable flat index — the
    // old formula used lessonStars.length so nodes jumped sides each lesson.
    final isEven = flatIndex.isEven;

    return Align(
      alignment: isEven ? const Alignment(-0.25, 0) : const Alignment(0.25, 0),
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
                    : context.lockedFill,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: unlocked
                        ? (stars != null
                            ? AppColors.yellowDark
                            : color.withValues(alpha: 0.6))
                        : context.line,
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
                    : Icon(Icons.lock, color: context.lockedText, size: 28),
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
        color: context.card,
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

// v4.9: the home-screen companion greets by time of day and replies to
// taps. v4.10: it now NEVER goes quiet — LiveCompanion speaks a fresh
// motivation line every 24–36 s while the path stays open, replies on
// every tap, pauses in the background and greets again on resume.
class _HomeCompanion extends StatefulWidget {
  @override
  State<_HomeCompanion> createState() => _HomeCompanionState();
}

class _HomeCompanionState extends State<_HomeCompanion> {
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return LiveCompanion(
      characterId: st.mascotId,
      facts: st.mascotFacts,
      locale: st.uiLocale,
      size: 56,
      reduceMotion: st.reduceMotion,
      salt: DateTime.now().day,
    );
  }
}
