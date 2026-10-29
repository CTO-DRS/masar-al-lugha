import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/reading.dart';
import 'package:masar_al_lugha/grammar.dart';
import 'package:masar_al_lugha/conversation.dart';

/// Phase-3 Batch C regression pins.
///
/// Locks the three content defects found by the phase-3 audit so they cannot
/// return silently:
///   1. correct-answer position must not be guessable (no dominant index);
///   2. a conversation scenario's own sample reply must always satisfy its
///      acceptAny rule — the shown hint can never be rejected;
///   3. structural integrity of every question/drill (in-range indexes,
///      distinct non-empty options).
void main() {
  group('phase3 content integrity (batch C)', () {
    test('reading questions: in-range, distinct options, spread positions', () {
      final counts = <int, int>{};
      for (final t in ReadingCatalog.texts) {
        final perText = <int>{};
        for (final q in t.questions) {
          expect(q.options.length, greaterThanOrEqualTo(2));
          expect(q.correct, inInclusiveRange(0, q.options.length - 1));
          final lowered = q.options.map((o) => o.trim().toLowerCase()).toList();
          expect(lowered.toSet().length, lowered.length,
              reason: 'duplicate options in ${t.id}');
          counts[q.correct] = (counts[q.correct] ?? 0) + 1;
          perText.add(q.correct);
        }
        // the two questions of one text must not share a position
        expect(perText.length, t.questions.length,
            reason: 'same correct position twice in ${t.id}');
      }
      const total = 32;
      for (final e in counts.entries) {
        expect(e.value / total, lessThanOrEqualTo(0.55),
            reason: 'position ${e.key} dominates: $counts');
      }
    });

    test('grammar drills: in-range, distinct options, spread positions', () {
      final counts = <int, int>{};
      var total = 0;
      for (final l in GrammarCatalog.lessons) {
        for (final d in l.drills) {
          total++;
          expect(d.correct, inInclusiveRange(0, d.options.length - 1));
          final lowered = d.options.map((o) => o.trim().toLowerCase()).toList();
          expect(lowered.toSet().length, lowered.length,
              reason: 'duplicate options in ${l.id}');
          expect(d.explainAr.trim(), isNotEmpty);
          counts[d.correct] = (counts[d.correct] ?? 0) + 1;
        }
      }
      expect(total, 64);
      for (final e in counts.entries) {
        expect(e.value / total, lessThanOrEqualTo(0.55),
            reason: 'position ${e.key} dominates: $counts');
      }
    });

    test('conversation: every sample reply satisfies its own acceptAny', () {
      for (final s in ConversationCatalog.scenarios) {
        for (final step in s.steps) {
          expect(step.acceptAny, isNotEmpty,
              reason: '${s.id} step without accept rule');
          for (final g in step.acceptAny) {
            expect(g, isNotEmpty);
            for (final k in g) {
              expect(k.trim(), isNotEmpty, reason: '${s.id} empty keyword');
            }
          }
          final reply = ConversationTrainer.normalize(step.sampleReply);
          final ok = step.acceptAny.any((g) =>
              g.every((k) => reply.contains(ConversationTrainer.normalize(k))));
          expect(ok, isTrue,
              reason: '${s.id} sample reply would be rejected by its own rule '
                  '→ «${step.sampleReply}»');
        }
      }
    });
  });
}
