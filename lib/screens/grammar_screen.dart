// Grammar lessons screen (v5.7, Phase 4 skill 2): course-scoped list →
// lesson reader (contrastive bullets vs Arabic) → drill cards (MCQ) with
// per-drill Arabic explanations. Content is machine-authored and flagged
// "needs human review" in docs/CONTENT_AUDIT.md — the engine (grammar.dart)
// is pure data + helpers and fully unit-tested.
import 'package:flutter/material.dart';

import '../grammar.dart';
import '../scope.dart';
import '../theme.dart';

class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseId = AppScope.of(context).courseId;
    final lessons = GrammarCatalog.forCourse(courseId);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('grammarTitle'))),
      body: lessons.isEmpty
          ? Center(child: Text(context.tr('grammarNone')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in lessons) _LessonCard(lesson: l),
              ],
            ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final GrammarLesson lesson;
  const _LessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.line, width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(lesson.titleAr,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(lesson.level,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(lesson.titleEn,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedText, fontSize: 12)),
                ),
              ],
            ),
          ),
          children: [
            for (final p in lesson.pointsAr)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.green)),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            for (var i = 0; i < lesson.drills.length; i++)
              _DrillCard(drill: lesson.drills[i], index: i),
          ],
        ),
      ),
    );
  }
}

class _DrillCard extends StatefulWidget {
  final GrammarDrill drill;
  final int index;
  const _DrillCard({required this.drill, required this.index});

  @override
  State<_DrillCard> createState() => _DrillCardState();
}

class _DrillCardState extends State<_DrillCard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final d = widget.drill;
    final answered = _picked != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(d.prompt,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          for (var i = 0; i < d.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OptionCard(
                text: d.options[i],
                selected: _picked == i,
                correct: answered && i == d.correct,
                wrong: answered && _picked == i && i != d.correct,
                onTap: answered ? null : () => _pick(i),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 4),
            Text(d.explainAr,
                style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  /// v5.18 (Phase-2 Batch D3): grammar drills now enter the REAL stats —
  /// recordAnswer feeds accuracy/insights, a correct drill earns 1 XP (the
  /// same rate as weak-words practice). The `answered` gate above makes a
  /// drill score at most once — rebuilds and re-taps cannot double-count.
  void _pick(int i) {
    final st = AppScope.of(context);
    setState(() => _picked = i);
    st.recordAnswer(i == widget.drill.correct);
    if (i == widget.drill.correct) st.addXp(1);
  }
}
