// F1.2 unit tests — the instant micro-repair engine (pure logic):
//  - first-mistake trigger rule (once per word per session)
//  - requeue spacing (>= 3 rounds, plan acceptance 2)
//  - plan building: re-rolled question with different distractors, 2-option
//    quick pick, dictation/listenComp hint-then-retry exception
//  - hint selection ladder: confusion pair -> memory hint -> generic
//  - repair state machine: 2 cycles max, then continue without embarrassment
//  - seeded determinism (same seed => same plan)
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/distractors.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/repair.dart';

const _pool = [
  Vocab(
      id: 'w1',
      target: 'Cat',
      translationAr: 'قط',
      emoji: '🐱',
      exampleTarget: 'The cat is small',
      exampleAr: 'القط صغير'),
  Vocab(id: 'w2', target: 'Dog', translationAr: 'كلب', emoji: '🐶'),
  Vocab(id: 'w3', target: 'Bird', translationAr: 'طائر', emoji: '🐦'),
  Vocab(id: 'w4', target: 'Fish', translationAr: 'سمكة', emoji: '🐟'),
  Vocab(id: 'w5', target: 'Bread', translationAr: 'خبز', emoji: '🍞'),
  Vocab(id: 'w6', target: 'Tree', translationAr: 'شجرة', emoji: '🌳'),
];

Exercise _mcqOnCat() => Exercise(
      type: ExerciseType.mcq,
      prompt: 'Cat',
      answer: 'قط',
      options: const ['قط', 'كلب', 'طائر', 'خبز'],
      vocab: _pool[0],
      audioText: 'Cat',
    );

Exercise _dictationOnCat() => Exercise(
      type: ExerciseType.dictation,
      prompt: '',
      answer: 'Cat',
      vocab: _pool[0],
      audioText: 'Cat',
    );

void main() {
  group('first-mistake trigger rule', () {
    test('first mistake on a word opens the repair', () {
      final seen = <String>{};
      expect(RepairEngine.isFirstMistake('w1', seen), isTrue);
    });

    test('a second mistake on the same word does not re-open it', () {
      final seen = <String>{};
      expect(RepairEngine.isFirstMistake('w1', seen), isTrue);
      expect(RepairEngine.isFirstMistake('w1', seen), isFalse);
    });

    test('a different word still triggers', () {
      final seen = <String>{'w1'};
      expect(RepairEngine.isFirstMistake('w2', seen), isTrue);
    });
  });

  group('requeue spacing (acceptance: not re-asked immediately)', () {
    test('the failed question returns at least 3 rounds later', () {
      // Leaving index 2 -> slots 3, 4, 5 must be other rounds -> insert at 6.
      expect(RepairEngine.minReaskGap, 3);
      expect(RepairEngine.requeueIndex(justLeft: 2, length: 10), 6);
      expect(RepairEngine.requeueIndex(justLeft: 0, length: 10), 4);
    });

    test('clamps to the end when the lesson is almost over', () {
      expect(RepairEngine.requeueIndex(justLeft: 8, length: 10), 10);
      expect(RepairEngine.requeueIndex(justLeft: 9, length: 10), 10);
    });
  });

  group('plan building — option rounds', () {
    final plan = RepairEngine.buildPlan(
      original: _mcqOnCat(),
      word: _pool[0],
      pool: _pool,
      confusions: const {},
      random: Random(7),
    );

    test('re-ask keeps the word and the correct answer', () {
      expect(plan.reask.vocab.id, 'w1');
      expect(plan.reask.answer, 'قط');
      expect(plan.reask.type, ExerciseType.mcq);
    });

    test('re-ask uses DIFFERENT distractors than the failed round', () {
      final oldDistractors =
          _mcqOnCat().options.where((o) => o != 'قط').toSet();
      final newDistractors = plan.reask.options.where((o) => o != 'قط').toSet();
      expect(newDistractors, isNot(oldDistractors),
          reason: 'the learner must never face the same decoys twice');
    });

    test('quick pick is a 2-option round containing the correct answer', () {
      expect(plan.quickPick, isNotNull);
      expect(plan.quickPick!.options.length, 2);
      expect(plan.quickPick!.options, contains('قط'));
      // two DISTINCT options — a real choice, not a gift
      expect(plan.quickPick!.options.toSet().length, 2);
    });

    test('retryOriginalOnly is false for mcq', () {
      expect(plan.retryOriginalOnly, isFalse);
    });

    test('example from the corpus rides along', () {
      expect(plan.exampleTarget, 'The cat is small');
      expect(plan.exampleAr, 'القط صغير');
    });
  });

  group('plan building — dictation exception', () {
    final plan = RepairEngine.buildPlan(
      original: _dictationOnCat(),
      word: _pool[0],
      pool: _pool,
      confusions: const {},
      random: Random(7),
    );

    test('dictation repairs by hint + retrying the SAME question', () {
      expect(plan.retryOriginalOnly, isTrue);
      expect(identical(plan.reask, plan.original), isTrue,
          reason: 'no re-rolled typing');
      expect(plan.quickPick, isNull);
      expect(plan.requeue, same(plan.original));
    });
  });

  group('hint selection ladder', () {
    test('a recorded confusion partner becomes the pair distinction', () {
      final plan = RepairEngine.buildPlan(
        original: _mcqOnCat(),
        word: _pool[0],
        pool: _pool,
        confusions: const {},
        confusedWithId: 'w2',
        random: Random(1),
      );
      expect(plan.hintKey, 'repairHintPair');
      expect(plan.hintArgs['a'], 'Cat');
      expect(plan.hintArgs['am'], 'قط');
      expect(plan.hintArgs['b'], 'Dog');
      expect(plan.hintArgs['bm'], 'كلب');
    });

    test('without a partner, the card memory-hint rule fires next', () {
      final card = CardData(ease: 2.5, intervalDays: 1, dueEpochMs: 0)
        ..lapses = 4;
      final plan = RepairEngine.buildPlan(
        original: _mcqOnCat(),
        word: _pool[0],
        pool: _pool,
        confusions: const {},
        card: card,
        random: Random(1),
      );
      expect(plan.hintKey, 'hintLapses');
      expect(plan.hintArgs['n'], '4');
    });

    test('with neither, the generic look-again hint is used', () {
      final plan = RepairEngine.buildPlan(
        original: _mcqOnCat(),
        word: _pool[0],
        pool: _pool,
        confusions: const {},
        random: Random(1),
      );
      expect(plan.hintKey, 'repairHintGeneric');
      expect(plan.hintArgs, isEmpty);
    });
  });

  group('repair state machine (max 2 cycles)', () {
    test('success at step 2 finishes immediately', () {
      final s = RepairSession(RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(3)));
      expect(s.hintDone(), RepairAction.toReask);
      expect(s.answerReask(true), RepairAction.success);
      expect(s.finished, isTrue);
      expect(s.succeeded, isTrue);
    });

    test('step-2 miss drops to the easier quick pick', () {
      final s = RepairSession(RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(3)));
      s.hintDone();
      expect(s.answerReask(false), RepairAction.toQuickPick);
      expect(s.step, RepairStep.quickPick);
      expect(s.cycle, 1);
    });

    test('quick-pick success also finishes', () {
      final s = RepairSession(RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(3)));
      s.hintDone();
      s.answerReask(false);
      expect(s.answerQuick(true), RepairAction.success);
      expect(s.succeeded, isTrue);
    });

    test('failure returns to the hint, hard stop after 2 cycles', () {
      final s = RepairSession(RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(3)));
      // cycle 1: miss both questions -> back to hint
      s.hintDone();
      s.answerReask(false);
      expect(s.answerQuick(false), RepairAction.toHint);
      expect(s.cycle, 2);
      expect(s.step, RepairStep.hint);
      // cycle 2: miss again -> give up, lesson continues
      s.hintDone();
      s.answerReask(false);
      expect(s.answerQuick(false), RepairAction.giveUp);
      expect(s.finished, isTrue);
      expect(s.succeeded, isFalse);
    });

    test('dictation variant: retry, fail, retry, give up — no quick pick', () {
      final s = RepairSession(RepairEngine.buildPlan(
          original: _dictationOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(3)));
      expect(s.hintDone(), RepairAction.toReask);
      // wrong retry -> straight to cycle 2 hint (no quickPick step)
      expect(s.answerReask(false), RepairAction.toHint);
      expect(s.cycle, 2);
      expect(s.step, RepairStep.hint);
      s.hintDone();
      expect(s.answerReask(false), RepairAction.giveUp);
    });
  });

  group('match-boss repairs', () {
    test('requeue the re-rolled recognition round, not the whole boss', () {
      final match = Exercise(
        type: ExerciseType.match,
        prompt: '',
        answer: '',
        vocab: _pool[0],
        audioText: '',
      );
      final plan = RepairEngine.buildPlan(
        original: match,
        word: _pool[0],
        pool: _pool,
        confusions: const {},
        forMatch: true,
        random: Random(5),
      );
      expect(plan.reask.type, ExerciseType.mcq);
      expect(plan.reask.vocab.id, 'w1');
      expect(plan.requeue, same(plan.reask));
      expect(plan.requeue.type, isNot(ExerciseType.match));
    });
  });

  group('determinism', () {
    test('same seed -> identical re-rolled plan', () {
      final a = RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(11));
      final b = RepairEngine.buildPlan(
          original: _mcqOnCat(),
          word: _pool[0],
          pool: _pool,
          confusions: const {},
          random: Random(11));
      expect(a.reask.options, b.reask.options);
      expect(a.quickPick!.options, b.quickPick!.options);
    });

    test('same lesson+word seed function is stable', () {
      expect(RepairEngine.seedFor('ls', 'w1', 0),
          RepairEngine.seedFor('ls', 'w1', 0));
      expect(RepairEngine.seedFor('ls', 'w1', 0),
          isNot(RepairEngine.seedFor('ls', 'w2', 0)));
    });
  });

  group('ExerciseGen.remake (re-roll mechanics)', () {
    test('remake drops banned distractor sources from the pool', () {
      final remade = ExerciseGen.remake(
        _pool[0],
        ExerciseType.mcq,
        _pool,
        const {},
        avoid: const ['كلب', 'طائر', 'خبز'], // the failed round's decoys
        seed: 3,
      );
      expect(remade.answer, 'قط');
      for (final o in remade.options) {
        if (o == 'قط') continue;
        expect(const ['كلب', 'طائر', 'خبز'], isNot(contains(o)),
            reason: 'old decoy "$o" survived the re-roll');
      }
    });

    test('remake keeps the target word itself in the plan', () {
      final remade = ExerciseGen.remake(
          _pool[1], ExerciseType.reverse, _pool, const {},
          seed: 3);
      expect(remade.vocab.id, 'w2');
      expect(remade.answer, 'Dog');
    });
  });

  group('confusion-driven quick pick preference', () {
    test('the recorded confusion partner is the quick-pick decoy', () {
      final plan = RepairEngine.buildPlan(
        original: _mcqOnCat(),
        word: _pool[0],
        pool: _pool,
        // the learner confuses Cat with Dog — priority-1 decoy for step 3
        confusions: const {'w1|w2': 3},
        random: Random(2),
      );
      expect(plan.quickPick!.options, contains('كلب'));
      expect(plan.quickPick!.options, contains('قط'));
    });
  });

  test('DistractorSource enum stays exhaustive for provenance audits', () {
    expect(DistractorSource.values.length, 5);
  });
}
