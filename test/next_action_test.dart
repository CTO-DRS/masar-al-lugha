// Next-best-action engine tests (v5.15, plan F3.2).
//
// The plan's acceptance: the selection algorithm is tested on 8+ state
// combinations, and the safe fallback always resolves to a lane the
// learner can actually start.
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/next_action.dart';

void main() {
  group('NextBestAction priority ladder', () {
    test('1. remediation beats everything — a live trap waits for nobody', () {
      final a = NextBestAction.fromCounts(
        dueCount: 30,
        remediationCount: 3,
        remainingInCurrentUnit: 1,
        nextLessonFlat: 5,
      );
      expect(a.kind, 'remediation');
      expect(a.params['n'], '3');
      expect(a.titleKey, 'nbaRemediationTitle');
      expect(a.whyKey, 'nbaRemediationWhy');
    });

    test('2. review takes over when the backlog is real (>= 8 due)', () {
      final a = NextBestAction.fromCounts(
        dueCount: 8,
        remediationCount: 0,
        remainingInCurrentUnit: 1,
        nextLessonFlat: 5,
      );
      expect(a.kind, 'review');
      expect(a.params['n'], '8');
    });

    test('2b. a SMALL due count does not hijack the card (below threshold)',
        () {
      final a = NextBestAction.fromCounts(
        dueCount: 7, // 7 < 8 — forward progress stays the answer
        remediationCount: 0,
        remainingInCurrentUnit: 2,
        nextLessonFlat: 5,
      );
      expect(a.kind, isNot('review'));
    });

    test('3. unit-finish momentum fires when one lesson remains', () {
      final a = NextBestAction.fromCounts(
        dueCount: 2,
        remediationCount: 0,
        remainingInCurrentUnit: 1,
        nextLessonFlat: 5,
      );
      expect(a.kind, 'unitFinish');
      expect(a.lessonFlat, 5);
    });

    test('3b. unit-finish needs an actual next lesson (never null-derefs)', () {
      final a = NextBestAction.fromCounts(
        dueCount: 2,
        remediationCount: 0,
        remainingInCurrentUnit: 1,
        nextLessonFlat: null, // weird state: unit "remaining" but no lesson
      );
      expect(a.kind, 'lesson');
    });

    test('4. the default lane is the next lesson', () {
      final a = NextBestAction.fromCounts(
        dueCount: 0,
        remediationCount: 0,
        remainingInCurrentUnit: 4,
        nextLessonFlat: 0,
      );
      expect(a.kind, 'lesson');
      expect(a.lessonFlat, 0);
      expect(a.titleKey, 'nbaLessonTitle');
    });

    test('5. SAFE FALLBACK: empty/odd state still yields a startable lane', () {
      // Everything zero/null (e.g. a fresh profile before content loads):
      // the engine still answers 'lesson' and the caller resolves the
      // empty case — the card can never dead-end.
      final a = NextBestAction.fromCounts(
        dueCount: 0,
        remediationCount: 0,
        remainingInCurrentUnit: 0,
        nextLessonFlat: null,
      );
      expect(a.kind, 'lesson');
    });

    test('6. precedence: remediation > review > unitFinish > lesson', () {
      NextAction pick(
              {int due = 0, int rem = 0, int remain = 9, int? flat = 0}) =>
          NextBestAction.fromCounts(
            dueCount: due,
            remediationCount: rem,
            remainingInCurrentUnit: remain,
            nextLessonFlat: flat,
          );
      expect(pick(due: 10, rem: 2).kind, 'remediation');
      expect(pick(due: 10, rem: 0, remain: 1).kind, 'review');
      expect(pick(due: 3, rem: 0, remain: 1).kind, 'unitFinish');
      expect(pick(due: 3, rem: 0, remain: 3).kind, 'lesson');
    });

    test('7. l10n keys derive mechanically for every kind', () {
      for (final k in ['remediation', 'review', 'unitFinish', 'lesson']) {
        final a = NextAction(k);
        expect(a.titleKey, 'nba${k[0].toUpperCase()}${k.substring(1)}Title');
        expect(a.whyKey, 'nba${k[0].toUpperCase()}${k.substring(1)}Why');
      }
    });
  });
}
