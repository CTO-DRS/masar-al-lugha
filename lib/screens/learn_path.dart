// Learn path: Duolingo-style winding lesson path with units.
// v4.0: "continue where you left off" hero card (M4), placement-test entry
// (M9), stable node sides (M7), and a weak-words practice launcher (H4).
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../insights.dart';
import '../models.dart';
import '../next_action.dart';
import '../path.dart';
import '../scope.dart';
import '../theme.dart';
import '../warmup.dart';
import '../widgets/mascot.dart';
import 'grammar_screen.dart';
import 'conversation_screen.dart';
import 'reading_screen.dart';
import 'home_shell.dart';
import 'lesson_screen.dart';
import 'path_setup_screen.dart';
import 'placement_screen.dart';
import 'quick_review_screen.dart';
import 'weak_words_screen.dart';

class LearnPath extends StatelessWidget {
  final void Function(int tab)? openTab;
  const LearnPath({super.key, this.openTab});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final course = st.course;

    // v5.15 (F3.4): warm up the next lesson's plan in a background
    // isolate while the learner is still looking at the path — the tap
    // then starts the first round instantly. Fire-and-forget; the lesson
    // screen falls back to a synchronous build on any mismatch.
    final warmAction = _nextActionFor(st);
    if (warmAction.lessonFlat != null) {
      final lesson = course.allLessons[warmAction.lessonFlat!];
      LessonWarmup.warm(WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr:
            course.units[_unitIndexOfFlat(course, warmAction.lessonFlat!)].cefr,
        confusions: st.confusionPairs,
      ));
    }

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
          // v5.15 (F3.2): ONE next-best-action card answers "what do I do
          // now?" — the rich path below it stays browsable, never decisive.
          _NextActionCard(action: _nextActionFor(st), openTab: openTab),
          // v5.15 (F3.2) banner budget: at most TWO secondary banners stay
          // visible (quick review when live + ONE rotating skill); the rest
          // wait in the "more" sheet — nothing is hidden from the learner,
          // only prioritized.
          if (_nextActionFor(st).kind != 'review') _QuickReviewBanner(),
          _SkillBanner(
            icon: _rotatingSkillIcon(),
            labelKey: _rotatingSkillKey(),
            builder: _rotatingSkillScreen,
          ),
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

  // v5.15 (F3.2) helpers for the banner budget + the action card.
  static int _dueCount(AppState st) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var n = 0;
    for (final l in st.course.allLessons) {
      if (!st.lessonStars.containsKey(l.id)) continue;
      for (final v in l.vocab) {
        final c = st.cardFor(v.id);
        if (c != null && c.dueEpochMs <= now) n++;
      }
    }
    return n;
  }

  static int _remediationCount(AppState st) {
    try {
      return st.remediationVocab(st.course).length;
    } catch (_) {
      return 0;
    }
  }

  // The visible skill banner rotates by epoch-day so the path stays fresh
  // without crowding it — the other two skills are one tap away in the
  // "more" sheet.
  static int get _skillSlot =>
      DateTime.now().millisecondsSinceEpoch ~/ 86400000 % 3;

  static IconData _rotatingSkillIcon() => const [
        Icons.school,
        Icons.menu_book,
        Icons.forum,
      ][_skillSlot];

  static String _rotatingSkillKey() =>
      const ['grammarTitle', 'readingTitle', 'conversationTitle'][_skillSlot];

  static Widget _rotatingSkillScreen(BuildContext _) {
    switch (_skillSlot) {
      case 0:
        return const GrammarScreen();
      case 1:
        return const ReadingScreen();
      default:
        return const ConversationScreen();
    }
  }

  /// The ONE recommended next step for the current course state (F3.2).
  static NextAction _nextActionFor(AppState st) {
    final course = st.course;
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
    // Lessons remaining in the NEXT lesson's unit (the "current" unit).
    var remaining = 0;
    if (next != null) {
      final unit = course.units[_unitIndexOfFlat(course, flat)];
      remaining =
          unit.lessons.where((l) => !st.lessonStars.containsKey(l.id)).length;
    }
    return NextBestAction.fromCounts(
      dueCount: _dueCount(st),
      remediationCount: _remediationCount(st),
      remainingInCurrentUnit: remaining,
      nextLessonFlat: next != null ? flat : null,
    );
  }

  static int _unitIndexOfFlat(Course course, int flat) {
    var acc = 0;
    for (var u = 0; u < course.units.length; u++) {
      acc += course.units[u].lessons.length;
      if (flat < acc) return u;
    }
    return course.units.length - 1;
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

// v5.15 (F3.2): the next-best-action card. The engine picked ONE lane;
// this card shows it with its WHY (the explained algorithm) and a start
// button, plus a "something else" row that opens the full lane sheet —
// nothing is hidden, only prioritized.
class _NextActionCard extends StatelessWidget {
  final NextAction action;
  final void Function(int tab)? openTab;

  const _NextActionCard({required this.action, this.openTab});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final title = context.trF(action.titleKey, action.params);
    final why = context.trF(action.whyKey, action.params);
    final accent = switch (action.kind) {
      'remediation' => AppColors.red,
      'review' => AppColors.blue,
      'unitFinish' => AppColors.yellow,
      _ => AppColors.green,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: context.line, offset: const Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_iconOf(action.kind), color: accent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16.5)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(why,
                style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.35)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    key: const ValueKey('nbaStart'),
                    label: context.tr('start'),
                    icon: Icons.play_arrow,
                    height: 46,
                    onPressed: () => _start(context, st),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChunkyButton(
                    key: const ValueKey('nbaMore'),
                    label: context.tr('nbaMore'),
                    color: Colors.transparent,
                    colorDark: Colors.transparent,
                    textColor: context.mutedText,
                    height: 46,
                    onPressed: () => _openMoreSheet(context, st),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(String kind) => switch (kind) {
        'remediation' => Icons.healing,
        'review' => Icons.bolt,
        'unitFinish' => Icons.flag,
        _ => Icons.play_lesson,
      };

  void _start(BuildContext context, AppState st) {
    final course = st.course;
    switch (action.kind) {
      case 'remediation':
        final pool = st.remediationVocab(course);
        if (pool.isNotEmpty) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                WeakWordsScreen(fixedPool: pool, titleKey: 'remediationTitle'),
          ));
        } else {
          // The window self-cleaned between pick and tap — safe fallback.
          _pushNextLesson(context, st);
        }
      case 'review':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const QuickReviewScreen(),
        ));
      case 'unitFinish':
      case 'lesson':
        _pushNextLesson(context, st);
    }
  }

  void _pushNextLesson(BuildContext context, AppState st) {
    final course = st.course;
    for (var i = 0; i < course.allLessons.length; i++) {
      if (st.isLessonUnlocked(i) &&
          !st.lessonStars.containsKey(course.allLessons[i].id)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LessonScreen(lesson: course.allLessons[i]),
        ));
        return;
      }
    }
    // Course complete or nothing unlocked: fall back to the Cards tab,
    // where review/smart-session lanes live (safe fallback, F3.2).
    openTab?.call(1);
  }

  // Every alternative is two taps away: card -> "something else" -> lane.
  void _openMoreSheet(BuildContext context, AppState st) {
    final due = LearnPath._dueCount(st);
    final rows = <_MoreRow>[
      if (action.kind != 'lesson')
        _MoreRow(Icons.play_lesson, 'nbaLessonTitle',
            () => _pushNextLesson(context, st)),
      if (action.kind != 'review' && due > 0)
        _MoreRow(Icons.bolt, 'quickReviewTitle', () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuickReviewScreen()));
        }),
      _MoreRow(Icons.school, 'grammarTitle', () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GrammarScreen()));
      }),
      _MoreRow(Icons.menu_book, 'readingTitle', () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ReadingScreen()));
      }),
      _MoreRow(Icons.forum, 'conversationTitle', () {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConversationScreen()));
      }),
      _MoreRow(Icons.fitness_center, 'weakPracticeTitle', () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const WeakWordsScreen()));
      }),
      _MoreRow(Icons.alt_route, 'pathSetupBtn', () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PathSetupScreen()));
      }),
      if (st.placementDone[st.courseId] == true)
        _MoreRow(Icons.refresh, 'placementRetest', () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PlacementScreen()));
        })
      else if (st.lessonsCompleted == 0)
        _MoreRow(Icons.quiz, 'placementTitle', () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PlacementScreen()));
        }),
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.tr('nbaMoreSheet'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in rows)
                      ListTile(
                        leading:
                            Icon(r.icon, color: AppColors.blueText, size: 22),
                        title: Text(ctx.tr(r.labelKey),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14.5)),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          r.onTap();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow {
  final IconData icon;
  final String labelKey;
  final VoidCallback onTap;
  const _MoreRow(this.icon, this.labelKey, this.onTap);
}

// v5.11: quick review launcher. Shows the LIVE due count (cards the FSRS
// schedule says are due right now) as a badge; the screen itself stays
// honest with an empty state when the queue turns out empty (e.g. another
// session drained it seconds ago).
class _QuickReviewBanner extends StatelessWidget {
  const _QuickReviewBanner();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final due = Insights.dueWithinDays(st.cards, 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QuickReviewScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 20, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('quickReviewTitle'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13.5)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: due > 0 ? AppColors.blue : context.softBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.trF('quickReviewDueBadge', {'n': '$due'}),
                    style: TextStyle(
                      color: due > 0 ? Colors.white : context.mutedText,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            // v5.15 (F3.2): the action rows moved to the next-best-action
            // card at the top of the path (and its "more" sheet) — the hero
            // keeps identity: plan, companion, progress. One decision per
            // screen instead of five competing buttons.
          ],
        ),
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
    final st = AppScope.of(context);
    // v4.0 fix (audit M7): node side comes from the stable flat index — the
    // old formula used lessonStars.length so nodes jumped sides each lesson.
    final isEven = flatIndex.isEven;

    return Align(
      alignment: isEven ? const Alignment(-0.25, 0) : const Alignment(0.25, 0),
      child: Column(
        children: [
          if (isCurrent) _startBubble(context),
          // v5.15 (F3.3): every path node reads as ONE sentence for screen
          // readers — what it is, which lesson, and its state — instead of
          // an unlabeled 74x70 grey circle.
          Semantics(
            button: unlocked,
            enabled: unlocked,
            label: context.tr(unlocked ? 'semStart' : 'semLocked'),
            value: '${st.uiLocale == 'ar' ? lesson.titleAr : lesson.titleEn}'
                '${stars != null ? ' · $stars/3' : ''}',
            excludeSemantics: true,
            child: GestureDetector(
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
                                // v5.15 (F3.3): INK on the yellow fill — the
                                // white star/count pair was 1.55:1, ink is
                                // 7.1:1.
                                const Icon(Icons.star,
                                    color: AppColors.ink, size: 30),
                                const SizedBox(height: 2),
                                Text(
                                  '$stars/3',
                                  style: const TextStyle(
                                    color: AppColors.ink,
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

/// v5.7/v5.8: shared slim banner entry for the skill screens.
class _SkillBanner extends StatelessWidget {
  final IconData icon;
  final String labelKey;
  final WidgetBuilder builder;
  const _SkillBanner(
      {required this.icon, required this.labelKey, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: builder)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr(labelKey),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13.5)),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
