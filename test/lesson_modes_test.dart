// v4.3 lesson-style tests: the same corpus must produce three different,
// each individually playable, exercise plans — classic (unchanged mix),
// sentence-mining (cloze-first) and audio-first (everything TTS-led).
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';

Lesson _richLesson() {
  // 2 words with examples, 2 multi-word sentences, 2 plain words —
  // a realistic mix of sentence material and bare vocabulary.
  const vocab = [
    Vocab(
        id: 's1',
        target: 'Cat',
        translationAr: 'قط',
        exampleTarget: 'The cat sleeps all day',
        exampleAr: 'القط نائم طوال اليوم'),
    Vocab(
        id: 's2',
        target: 'Dog',
        translationAr: 'كلب',
        exampleTarget: 'My dog runs fast',
        exampleAr: 'كلبي يجري بسرعة'),
    Vocab(id: 's3', target: 'I love my cat', translationAr: 'أحب قطتي'),
    Vocab(
        id: 's4',
        target: 'Time flies so fast',
        translationAr: 'الوقت يمر بسرعة'),
    Vocab(id: 's5', target: 'Bird', translationAr: 'طائر'),
    Vocab(id: 's6', target: 'Fish', translationAr: 'سمكة'),
  ];
  return const Lesson(id: 'ls', titleAr: 'ج', titleEn: 'S', vocab: vocab);
}

Lesson _bareLesson() {
  // No examples, no sentences — worst-case material for both new modes.
  const vocab = [
    Vocab(id: 'b1', target: 'Red', translationAr: 'أحمر'),
    Vocab(id: 'b2', target: 'Blue', translationAr: 'أزرق'),
    Vocab(id: 'b3', target: 'Green', translationAr: 'أخضر'),
    Vocab(id: 'b4', target: 'White', translationAr: 'أبيض'),
  ];
  return const Lesson(id: 'lb', titleAr: 'ب', titleEn: 'B', vocab: vocab);
}

void main() {
  group('classic mode (regression)', () {
    test('default and explicit classic produce the same exercise types', () {
      final def = ExerciseGen.forLesson(_richLesson());
      final classic =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.classic);
      for (final plan in [def, classic]) {
        expect(plan, isNotEmpty);
        final types = plan.map((e) => e.type).toSet();
        expect(types.contains(ExerciseType.mcq), isTrue);
        expect(types.contains(ExerciseType.match), isTrue);
        expect(plan.last.type, ExerciseType.match); // boss stays last
        expect(plan.length, lessThanOrEqualTo(14)); // snappy cap
      }
    });
  });

  group('sentence-mining mode', () {
    test('cloze-first: fillblank exercises open the plan and stay valid', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.sentences);
      expect(plan, isNotEmpty);

      final firstBlank =
          plan.indexWhere((e) => e.type == ExerciseType.fillblank);
      expect(firstBlank, inInclusiveRange(0, 5),
          reason: 'cloze rounds must come first');

      for (final b in plan.where((e) => e.type == ExerciseType.fillblank)) {
        expect(b.prompt.contains('______'), isTrue,
            reason: 'blank marker in "${b.prompt}"');
        expect(b.prompt, isNot(contains(b.answer)));
        expect(b.options.length, greaterThanOrEqualTo(2));
        expect(b.options.contains(b.answer), isTrue);
        expect(b.audioText, isNotEmpty); // sentence audio for feedback
      }
    });

    test('build rounds reconstruct real lesson sentences', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.sentences);
      final builds = plan.where((e) => e.type == ExerciseType.build).toList();
      expect(builds, isNotEmpty);
      for (final b in builds) {
        final rebuilt = b.tiles.join(' ');
        expect(rebuilt, b.answer); // tiles are the answer's words
        expect(rebuilt.trim().split(' ').length, inInclusiveRange(3, 8));
        expect(b.audioText, b.answer);
      }
    });

    test('listen rounds offer whole sentences as options', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.sentences);
      final listens = plan.where((e) => e.type == ExerciseType.listen).toList();
      expect(listens, isNotEmpty);
      for (final l in listens) {
        expect(l.options.length, inInclusiveRange(2, 3));
        expect(l.options.contains(l.answer), isTrue);
        for (final o in l.options) {
          expect(o.trim().contains(' '), isTrue,
              reason: 'sentence options, not words: "$o"');
        }
        expect(l.audioText, l.answer);
      }
    });

    test('bare lesson (no sentence material) still yields a playable plan', () {
      final plan =
          ExerciseGen.forLesson(_bareLesson(), mode: LessonMode.sentences);
      expect(plan.length, inInclusiveRange(4, 14));
      // Top-up drills cover every bare word and stay valid.
      final choice = plan
          .where((e) =>
              e.type == ExerciseType.mcq || e.type == ExerciseType.reverse)
          .toList();
      expect(choice.length, 4,
          reason: 'all 4 bare words get a fallback reverse/mcq drill');
      for (final e in choice) {
        expect(e.options.contains(e.answer), isTrue);
      }
      // The match boss may still close the plan.
      if (plan.last.type == ExerciseType.match) {
        expect(plan.last.matchLeft.length, 4);
      }
    });
  });

  group('audio-first mode', () {
    test('opens with a listening exercise (ears first)', () {
      final plan = ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);
      expect(plan.first.type, ExerciseType.listen);
      final planB =
          ExerciseGen.forLesson(_bareLesson(), mode: LessonMode.audio);
      expect(planB.first.type, ExerciseType.listen);
    });

    test('every exercise is TTS-led (match boss is tap-to-speak)', () {
      for (final lesson in [_richLesson(), _bareLesson()]) {
        final plan = ExerciseGen.forLesson(lesson, mode: LessonMode.audio);
        expect(plan, isNotEmpty);
        for (final e in plan) {
          if (e.type == ExerciseType.match) {
            expect(e.matchLeft.length, 4); // tap-to-hear column
            continue;
          }
          expect(e.audioText, isNotEmpty,
              reason: '${e.type} must carry audio in audio-first mode');
        }
      }
    });

    test('hears-a-word and hears-meaning variants both appear', () {
      final plan = ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);
      final listens = plan.where((e) => e.type == ExerciseType.listen).toList();
      expect(listens.length, greaterThanOrEqualTo(4));
      final wordPicks = listens.where((e) => e.answer == e.vocab.target).length;
      final meaningPicks =
          listens.where((e) => e.answer == e.vocab.translationAr).length;
      expect(wordPicks, greaterThanOrEqualTo(2));
      expect(meaningPicks, greaterThanOrEqualTo(2));
      for (final l in listens) {
        expect(l.options.contains(l.answer), isTrue);
        expect(l.options.toSet().length, l.options.length);
      }
    });

    test('audio build carries the spoken sentence', () {
      final plan = ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);
      final builds = plan.where((e) => e.type == ExerciseType.build).toList();
      expect(builds, isNotEmpty);
      for (final b in builds) {
        expect(b.audioText, b.tiles.join(' '));
      }
    });
  });

  group('modes differ', () {
    test('the three plans are distinct mixes of the same corpus', () {
      final classic =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.classic);
      final sentences =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.sentences);
      final audio =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);

      expect(classic.first.type, isNot(ExerciseType.listen),
          reason: 'classic opens with reverse/mcq/build cycle');
      expect(sentences.first.type, ExerciseType.fillblank,
          reason: 'sentence mining is cloze-first');
      expect(audio.first.type, ExerciseType.listen,
          reason: 'audio-first opens with listening');

      final audioTypes = audio.map((e) => e.type).toSet();
      expect(audioTypes, isNot(contains(ExerciseType.mcq)),
          reason: 'no reading-first mcq in an audio lesson');
    });
  });
}
