// v4.6 exercise tests: dictation (hear -> type) and listening
// comprehension (hear sentence -> pick the Arabic meaning), plus the
// tolerant answer normalizer that grades typed answers.
//
// Verified here:
// - normalizeTyped: case / punctuation / diacritics / tatweel / whitespace
// - dictation exercises carry audio == answer and a meaning hint
// - listenComp exercises offer 4 unique real meanings, answer included
// - corpus-wide: every generated plan (3 modes x 4 courses sample) keeps
//   the invariants and stays playable
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';

Lesson _richLesson() {
  // 2 words with examples, 2 multi-word sentences, 2 plain words.
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
  // No examples, no sentences — dictation must fall back to single words.
  const vocab = [
    Vocab(id: 'b1', target: 'Red', translationAr: 'أحمر'),
    Vocab(id: 'b2', target: 'Blue', translationAr: 'أزرق'),
    Vocab(id: 'b3', target: 'Green', translationAr: 'أخضر'),
    Vocab(id: 'b4', target: 'White', translationAr: 'أبيض'),
  ];
  return const Lesson(id: 'lb', titleAr: 'ب', titleEn: 'B', vocab: vocab);
}

Future<Course> _load(String lang) async {
  final raw = await rootBundle.loadString('assets/data/course_$lang.json');
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeTyped (tolerant grading)', () {
    test('case-insensitive', () {
      expect(ExerciseGen.normalizeTyped('Hello'), 'hello');
      expect(ExerciseGen.normalizeTyped('HELLO WORLD'), 'hello world');
    });

    test('punctuation and symbols are ignored', () {
      expect(ExerciseGen.normalizeTyped('Hello, World!'), 'hello world');
      expect(ExerciseGen.normalizeTyped('well-known'), 'well known');
      expect(ExerciseGen.normalizeTyped("it's a cat..."), 'it s a cat');
    });

    test('Arabic diacritics and tatweel are stripped', () {
      expect(ExerciseGen.normalizeTyped('مَدْرَسَةٌ'), 'مدرسة');
      expect(ExerciseGen.normalizeTyped('مـــدرسة'), 'مدرسة');
      expect(ExerciseGen.normalizeTyped('كِتَاب'), 'كتاب');
    });

    test('whitespace collapses', () {
      expect(ExerciseGen.normalizeTyped('  the   cat  '), 'the cat');
      expect(ExerciseGen.normalizeTyped('the\tcat\n'), 'the cat');
    });

    test('normalization is idempotent', () {
      const samples = ['Hello, World!', 'مَدْرَسَةٌ', '  x  y  '];
      for (final s in samples) {
        expect(ExerciseGen.normalizeTyped(ExerciseGen.normalizeTyped(s)),
            ExerciseGen.normalizeTyped(s));
      }
    });
  });

  group('dictation exercises', () {
    test('classic plan: one dictation, audio IS the answer', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.classic);
      final dicts =
          plan.where((e) => e.type == ExerciseType.dictation).toList();
      expect(dicts.length, 1, reason: 'exactly one typing round per classic');
      for (final d in dicts) {
        expect(d.audioText, d.answer);
        expect(d.options, isEmpty); // typed, not picked
        expect(d.tiles, isEmpty);
        expect(d.hint, isNotEmpty); // the Arabic meaning
        expect(ExerciseGen.normalizeTyped(d.answer), isNotEmpty);
      }
    });

    test('audio-first plan: up to two dictations, all TTS-led', () {
      final plan = ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);
      final dicts =
          plan.where((e) => e.type == ExerciseType.dictation).toList();
      expect(dicts.length, inInclusiveRange(1, 2));
      for (final d in dicts) {
        expect(d.audioText, d.answer);
        expect(d.hint, isNotEmpty);
      }
    });

    test('bare lesson: dictation falls back to single words', () {
      final plan =
          ExerciseGen.forLesson(_bareLesson(), mode: LessonMode.classic);
      final dicts =
          plan.where((e) => e.type == ExerciseType.dictation).toList();
      expect(dicts, isNotEmpty);
      final d = dicts.first;
      expect(d.answer.length, inInclusiveRange(3, 12));
      expect(d.answer, d.vocab.target);
      expect(d.hint, d.vocab.translationAr);
    });

    test('dictation answers grade true against tolerant variants', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.classic);
      final d = plan.firstWhere((e) => e.type == ExerciseType.dictation);
      final words = d.answer.trim().split(RegExp(r'\s+'));
      final sloppy = '  ${words.join(' , ')}  !'; // punctuation + padding noise
      expect(ExerciseGen.normalizeTyped(sloppy),
          ExerciseGen.normalizeTyped(d.answer));
    });
  });

  group('listening comprehension', () {
    test('sentence-mining plan: 4 unique Arabic meanings, answer included', () {
      final plan =
          ExerciseGen.forLesson(_richLesson(), mode: LessonMode.sentences);
      final comps =
          plan.where((e) => e.type == ExerciseType.listenComp).toList();
      expect(comps, isNotEmpty);
      for (final c in comps) {
        expect(c.options.length, 4);
        expect(c.options.toSet().length, 4, reason: 'no duplicate options');
        expect(c.options.contains(c.answer), isTrue);
        expect(c.audioText, isNotEmpty);
        expect(c.audioText, isNot(c.answer),
            reason: 'heard sentence (target lang) != picked meaning (Arabic)');
        // All options are Arabic meanings of real lesson material.
        for (final o in c.options) {
          expect(o.contains(RegExp(r'[\u0600-\u06FF]')), isTrue,
              reason: '"$o" must be an Arabic meaning');
        }
      }
    });

    test('audio-first plan: comprehension rides after recognition', () {
      final plan = ExerciseGen.forLesson(_richLesson(), mode: LessonMode.audio);
      final comps =
          plan.where((e) => e.type == ExerciseType.listenComp).toList();
      expect(comps.length, 1);
      expect(comps.first.options.length, 4);
    });

    test('bare lesson: no comprehension without sentence material', () {
      final plan = ExerciseGen.forLesson(_bareLesson(), mode: LessonMode.audio);
      expect(plan.where((e) => e.type == ExerciseType.listenComp), isEmpty);
    });
  });

  group('corpus-wide plan validity (sampled real lessons)', () {
    test('every sampled lesson keeps v4.6 invariants in all three modes',
        () async {
      for (final lang in ['en', 'fr', 'ur', 'de']) {
        final course = await _load(lang);
        // First, middle and last lesson of the course — a cheap but real
        // sweep across the CEFR ladder.
        final lessons = course.allLessons;
        final sample = [
          lessons.first,
          lessons[lessons.length ~/ 2],
          lessons.last,
        ];
        for (final mode in LessonMode.values) {
          for (final lesson in sample) {
            final plan = ExerciseGen.forLesson(lesson, mode: mode);
            expect(plan, isNotEmpty,
                reason: '$lang ${lesson.id}/$mode produced an empty plan');
            for (final e in plan) {
              switch (e.type) {
                case ExerciseType.dictation:
                  expect(e.audioText, e.answer,
                      reason: '$lang ${lesson.id}/$mode dictation audio');
                  expect(e.hint, isNotEmpty,
                      reason: '$lang ${lesson.id}/$mode dictation hint');
                  expect(e.options, isEmpty);
                  break;
                case ExerciseType.listenComp:
                  expect(e.options.length, 4);
                  expect(e.options.toSet().length, 4);
                  expect(e.options.contains(e.answer), isTrue);
                  expect(e.audioText, isNotEmpty);
                  break;
                default:
                  break;
              }
            }
            if (plan.last.type == ExerciseType.match) {
              expect(plan.last.matchLeft.length, inInclusiveRange(3, 4));
            }
          }
        }
      }
    });

    test('dictation answer normalizes back to the lesson material', () async {
      final course = await _load('en');
      final lesson = course.allLessons[course.allLessons.length ~/ 2];
      final plan = ExerciseGen.forLesson(lesson, mode: LessonMode.audio);
      for (final d in plan.where((e) => e.type == ExerciseType.dictation)) {
        final vocabText = d.vocab.isSentence
            ? d.vocab.target
            : (d.vocab.exampleTarget ?? d.vocab.target);
        expect(ExerciseGen.normalizeTyped(d.answer),
            ExerciseGen.normalizeTyped(vocabText));
      }
    });
  });
}
