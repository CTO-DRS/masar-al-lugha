// Error-analysis screen (v4.1, ROADMAP item 3 / MASTER PROMPT Wave 4+8):
// overall accuracy plus the top-20 most-missed words of the current course,
// with a one-tap path into the tough-words practice lane. All numbers come
// from persisted state (totalAnswers/correctAnswers/wordMistakes) — no
// invented analytics.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../remediation.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'weak_words_screen.dart';

class ErrorAnalysisScreen extends StatelessWidget {
  const ErrorAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final weak = st.weakestVocab(st.course).take(20).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr('errorAnalysis'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          // ---- accuracy card ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.line, width: 2),
              boxShadow: [
                BoxShadow(
                    color: context.line,
                    offset: const Offset(0, 4),
                    blurRadius: 0),
              ],
            ),
            child: Row(
              children: [
                ProgressRing(
                  progress: st.accuracyPct / 100,
                  size: 92,
                  stroke: 10,
                  color: st.accuracyPct >= 80
                      ? AppColors.green
                      : st.accuracyPct >= 50
                          ? AppColors.orange
                          : AppColors.red,
                  center: Text(
                    '${st.accuracyPct}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: context.bodyText,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('accuracyOverall'),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: context.bodyText)),
                      const SizedBox(height: 4),
                      Text(
                        '${st.correctAnswers}/${st.totalAnswers} ${tr('answersTracked')}',
                        style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(tr('accuracyNote'),
                          style: TextStyle(
                              color: context.mutedText, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---- practice CTA ----
          ChunkyButton(
            label: weak.isEmpty ? tr('noWeakWords') : tr('practiceWeak'),
            icon: Icons.fitness_center,
            color: AppColors.red,
            colorDark: AppColors.redDark,
            disabled: weak.isEmpty,
            onPressed: weak.isEmpty ? null : () => _openPractice(context),
          ),
          const SizedBox(height: 20),
          // ---- top-20 mistake list ----
          Text(tr('topMistakes'),
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: context.bodyText)),
          const SizedBox(height: 10),
          if (weak.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.line, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sentiment_satisfied,
                      color: AppColors.green, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr('noWeakWords'),
                        style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                ],
              ),
            )
          else
            ...weak.indexed.map((e) {
              final (i, v) = e;
              final n = st.wordMistakes[v.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.line, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: context.mutedText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _speak(context, v.target),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.target,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: context.bodyText)),
                              const SizedBox(height: 2),
                              Text(
                                '${v.translationAr}${v.phonetic == null ? '' : '  ·  ${v.phonetic}'}',
                                style: TextStyle(
                                    color: context.mutedText, fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '✗ $n',
                          style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            st.course.id == 'en'
                ? tr('analysisCourseEn')
                : tr('analysisCourseOther'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 11.5),
          ),
          const SizedBox(height: 20),
          // ---- v5.18 (Batch C): error patterns by exercise kind ----
          Text(tr('errorPatterns'),
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: context.bodyText)),
          const SizedBox(height: 4),
          Text(tr('errorPatternsHint'),
              style: TextStyle(color: context.mutedText, fontSize: 12)),
          const SizedBox(height: 10),
          ..._patternRows(context, st, tr),
        ],
      ),
    );
  }

  /// v5.18 (Batch C): the mistake-kind breakdown, built ONLY from recorded
  /// scored mistakes (errorKinds). A kind is labelled recurring when at
  /// least one word missed by that kind is inside the live 7-day
  /// remediation window — otherwise transient (a past blip that healed).
  /// Copy stays neutral and encouraging: patterns to practise, never
  /// verdicts about the learner.
  List<Widget> _patternRows(
      BuildContext context, AppState st, String Function(String) tr) {
    final kinds = st.errorKindTotals();
    if (kinds.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.line, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('errorPatternsEmpty'),
                    style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      ];
    }
    final rows = <Widget>[];
    final vocabById = {for (final v in st.course.allVocab) v.id: v};
    for (final row in kinds) {
      final kind = row.key;
      final total = row.value;
      // The most-missed word of this kind + whether the pattern is live.
      String? topWord;
      var recurring = false;
      var topCount = 0;
      st.errorKinds.forEach((vocabId, byKind) {
        final n = byKind[kind] ?? 0;
        if (n <= 0) return;
        final v = vocabById[vocabId];
        if (v == null) return;
        if (Remediation.isTarget(st.lapseLog, vocabId)) recurring = true;
        if (n > topCount) {
          topCount = n;
          topWord = v.target;
        }
      });
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.line, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                recurring ? Icons.repeat : Icons.check_circle_outline,
                color: recurring ? AppColors.orange : AppColors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(kindLabelKey(kind)),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: context.bodyText)),
                    if (topWord != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tr('errorPatternTopWord')
                              .replaceFirst('{w}', topWord!),
                          style:
                              TextStyle(color: context.mutedText, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: (recurring ? AppColors.orange : AppColors.green)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tr(recurring ? 'errorRecurring' : 'errorTransient'),
                      style: TextStyle(
                          color: recurring ? AppColors.orange : AppColors.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✗ $total',
                    style: TextStyle(
                        color: context.mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return rows;
  }

  void _openPractice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeakWordsScreen()),
    );
  }

  Future<void> _speak(BuildContext context, String text) async {
    final st = AppScope.of(context);
    final tts = AppScope.ttsOf(context);
    await tts.setLanguage(st.course.ttsLang);
    await tts.speak(text);
  }
}
