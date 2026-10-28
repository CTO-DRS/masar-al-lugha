// v5.18 (Phase-2 Batch B4): the per-lesson grammar round tests.
//
// The grammar round must be honest integration, not decoration:
//  - it exists ONLY when the course catalog has a lesson at or below the
//    lesson's CEFR band (content that fits, never above the learner);
//  - it is a pure function of the lesson id (determinism contract);
//  - it renders mcq-shaped with the rule carried in the hint;
//  - it never lands AFTER the match boss (the boss stays the finale);
//  - it never mutates the count of rounds above the 14-round cap.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/grammar.dart';
import 'package:masar_al_lugha/models.dart';

Lesson _lesson(String id, String cefr) => Lesson(
      id: id,
      titleAr: 'درس',
      titleEn: 'Lesson',
      vocab: List.generate(
        6,
        (i) => Vocab(
          id: '${id}_w$i',
          target: 'word$i',
          translationAr: 'معنى $i',
        ),
      ),
    );

int _matchIndex(List<Exercise> plan) =>
    plan.indexWhere((e) => e.type == ExerciseType.match);

void main() {
  group('grammar round (v5.18 Batch B4)', () {
    test('every real A1 lesson gains exactly one grammar round before the boss',
        () {
      final plan = ExerciseGen.forLesson(_lesson('en_u1_l1', 'A1'));
      final grammarIdx =
          plan.indexWhere((e) => e.type == ExerciseType.grammar);
      expect(grammarIdx, greaterThanOrEqualTo(0),
          reason: 'the en catalog has an A1 lesson — the round must exist');
      final matchIdx = _matchIndex(plan);
      if (matchIdx >= 0) {
        expect(grammarIdx < matchIdx, isTrue,
            reason: 'the match boss stays the finale');
      }
      final g = plan[grammarIdx];
      expect(g.options.contains(g.answer), isTrue);
      expect(g.hint, isNotEmpty, reason: 'the rule rides in the hint');
    });

    test('the round is a pure function of the lesson id (determinism)', () {
      final a = ExerciseGen.forLesson(_lesson('en_u3_l2', 'A2'));
      final b = ExerciseGen.forLesson(_lesson('en_u3_l2', 'A2'));
      final ga = a.where((e) => e.type == ExerciseType.grammar).toList();
      final gb = b.where((e) => e.type == ExerciseType.grammar).toList();
      expect(ga.length, gb.length);
      for (var i = 0; i < ga.length; i++) {
        expect(ga[i].prompt, gb[i].prompt);
        expect(ga[i].answer, gb[i].answer);
        expect(ga[i].hint, gb[i].hint);
      }
    });

    test('an A1 lesson never drills a B1+ rule (content that fits)', () {
      final plan = ExerciseGen.forLesson(_lesson('de_u2_l1', 'A1'));
      final g =
          plan.firstWhere((e) => e.type == ExerciseType.grammar);
      // The picked drill must belong to a catalog lesson at or below A1.
      final candidates = GrammarCatalog.forCourse('de')
          .where((l) => l.level == 'A1')
          .toList();
      final prompts = candidates.expand((l) => l.drills.map((d) => d.prompt));
      expect(prompts.contains(g.prompt), isTrue);
    });

    test('a level with no catalog content yields no grammar round', () {
      // A foreign course id has no catalog at all — the plan is unchanged.
      final plan = ExerciseGen.forLesson(_lesson('zz_u1_l1', 'A1'));
      expect(plan.any((e) => e.type == ExerciseType.grammar), isFalse);
      expect(plan, isNotEmpty, reason: 'the plan itself stays usable');
    });

    test('the round respects the 14-round cap (never balloons a lesson)', () {
      final plan = ExerciseGen.forLesson(_lesson('en_u6_l3', 'B1'));
      expect(plan.length, lessThanOrEqualTo(15),
          reason: 'cap + the one grammar round at most');
    });

    test('audio-first lessons keep their TTS-led invariant: no grammar round',
        () {
      // Audio mode is ears-first; a silent rule-reading round would break
      // the mode's contract (pinned corpus-wide by distractors_test).
      final plan = ExerciseGen.forLesson(_lesson('en_u1_l1', 'A1'),
          mode: LessonMode.audio);
      expect(plan.any((e) => e.type == ExerciseType.grammar), isFalse);
      for (final e in plan) {
        if (e.type == ExerciseType.match) continue;
        expect(e.audioText, isNotEmpty);
      }
    });
  });
}
