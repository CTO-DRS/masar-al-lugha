// F1.1 — confusion-driven distractors + exercise balancing.
//
// Covers the plan's acceptance criteria:
//  1. >= 40% of a confused learner's distractors trace back to their own
//     confusion pairs (Distractors.confusionShare on a real generated plan).
//  2. No lesson breaks the 40% per-type cap — sampled across all four
//     courses in all three modes.
//  3. Same inputs + same seed ⇒ same outputs (determinism).
//  4. No content/JSON change was needed — the pre-existing content tests
//     stay green (they run in the same suite).
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/distractors.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/insights.dart';
import 'package:masar_al_lugha/models.dart';

// Assets read via dart:io instead of rootBundle — inside a widget test the
// asset channel never completes outside tester.runAsync() (see
// weak_practice_test.dart for the original investigation).
Course loadCourse(String id) {
  final raw = File('assets/data/course_$id.json').readAsStringSync();
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Vocab _v(String id, String target, String ar, {String? emoji}) =>
    Vocab(id: id, target: target, translationAr: ar, emoji: emoji);

Lesson _lesson(List<Vocab> vocab, {String id = 't1'}) =>
    Lesson(id: id, titleAr: 'درس', titleEn: 'Lesson', vocab: vocab);

void main() {
  group('Distractors.pick — the four priorities', () {
    final pool = [
      _v('w1', 'cat', 'قط'),
      _v('w2', 'dog', 'كلب'),
      _v('w3', 'cart', 'عربة'),
      _v('w4', 'bird', 'طائر'),
      _v('w5', 'house', 'بيت'),
    ];

    test('priority 1: the learner\u2019s own confusion partner comes first',
        () {
      final picks = Distractors.pick(
        target: pool[0], // cat
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {Insights.confusionKey('w1', 'w3'): 4}, // cat<->cart
        random: Random(1),
      );
      expect(picks, isNotEmpty);
      expect(picks.first.option, 'cart');
      expect(picks.first.source, DistractorSource.learnerConfusion);
      expect(picks.first.vocabId, 'w3');
    });

    test('priority 1 works on the meaning field too (mcq options)', () {
      final picks = Distractors.pick(
        target: pool[0], // cat / قط
        pool: pool,
        fieldOf: (v) => v.translationAr,
        confusionPairs: {Insights.confusionKey('w1', 'w3'): 2},
        random: Random(1),
      );
      expect(picks.first.option, 'عربة'); // cart's Arabic meaning
      expect(picks.first.source, DistractorSource.learnerConfusion);
    });

    test('stronger pairs outrank weaker pairs (sorted by miss count)', () {
      final picks = Distractors.pick(
        target: pool[0], // cat
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {
          Insights.confusionKey('w1', 'w4'): 1, // bird, weaker
          Insights.confusionKey('w1', 'w3'): 5, // cart, stronger
        },
        random: Random(1),
      );
      expect(picks.first.option, 'cart');
      expect(picks[1].option, 'bird');
    });

    test('priority 2: profile-level confusable words fill remaining slots', () {
      final picks = Distractors.pick(
        target: pool[4], // house — no direct pairs
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {
          Insights.confusionKey('w2', 'w3'): 6, // dog<->cart, evidence >= 2
        },
        random: Random(1),
      );
      final sources = picks.map((p) => p.source).toSet();
      expect(sources, contains(DistractorSource.profileConfusion));
      final firstIndirect = picks
          .firstWhere((p) => p.source == DistractorSource.profileConfusion);
      expect({'w2', 'w3'}, contains(firstIndirect.vocabId));
    });

    test('priority 2 requires evidence (count >= 2) — single misses ignored',
        () {
      final picks = Distractors.pick(
        target: pool[4], // house
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {Insights.confusionKey('w2', 'w3'): 1},
        random: Random(7),
      );
      expect(
        picks.map((p) => p.source),
        isNot(contains(DistractorSource.profileConfusion)),
      );
    });

    test('priority 3: look-alikes (shared prefix) beat random fill', () {
      final picks = Distractors.pick(
        target: pool[0], // cat
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: const {},
        random: Random(1),
      );
      expect(picks.map((p) => p.source), contains(DistractorSource.similarity));
      // "cart" shares "ca" with "cat" — it must be among the picks.
      expect(picks.map((p) => p.option), contains('cart'));
    });

    test('never includes the tested word and never duplicates options', () {
      for (var seed = 0; seed < 20; seed++) {
        final picks = Distractors.pick(
          target: pool[0],
          pool: pool,
          fieldOf: (v) => v.target,
          confusionPairs: {Insights.confusionKey('w1', 'w2'): 3},
          random: Random(seed),
        );
        expect(picks.length, 3);
        final options = picks.map((p) => p.option).toList();
        expect(options.toSet().length, options.length, reason: 'seed $seed');
        expect(options, isNot(contains('cat')));
      }
    });

    test('tiny 4-word lesson still yields 3 distinct distractors', () {
      final tiny = [
        _v('a1', 'sun', 'شمس'),
        _v('a2', 'moon', 'قمر'),
        _v('a3', 'star', 'نجم'),
        _v('a4', 'sky', 'سماء'),
      ];
      final picks = Distractors.pick(
        target: tiny[0],
        pool: tiny,
        fieldOf: (v) => v.target,
        random: Random(3),
      );
      expect(picks.length, 3);
      expect(picks.map((p) => p.option).toSet().length, 3);
    });

    test('pool smaller than the count pads from the real-word reserve', () {
      final two = [_v('r1', 'sun', 'شمس'), _v('r2', 'moon', 'قمر')];
      final picks = Distractors.pick(
        target: two[0],
        pool: two,
        fieldOf: (v) => v.target,
        random: Random(3),
        reserve: ExerciseGen.realWordReserve,
      );
      expect(picks.length, 3);
      expect(picks.last.source, DistractorSource.reserve);
      expect(picks.last.vocabId, '');
      // Reserve words are real words, never "___" placeholders.
      expect(picks.map((p) => p.option), everyElement(isNot('___')));
    });

    test('fewer than 3 confusion pairs degrades gracefully down the ladder',
        () {
      final picks = Distractors.pick(
        target: pool[0],
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {Insights.confusionKey('w1', 'w4'): 9}, // only one
        random: Random(2),
      );
      expect(picks.length, 3);
      expect(picks.first.option, 'bird');
      expect(picks.first.source, DistractorSource.learnerConfusion);
      final rest = picks.sublist(1).map((p) => p.source);
      expect(rest, everyElement(isNot(DistractorSource.learnerConfusion)));
    });
  });

  group('Distractors.pick — determinism (plan acceptance #3)', () {
    test('same inputs + same seed ⇒ identical picks', () {
      final pool = [
        _v('d1', 'write', 'يكتب'),
        _v('d2', 'right', 'صحيح'),
        _v('d3', 'read', 'يقرأ'),
        _v('d4', 'road', 'طريق'),
        _v('d5', 'pen', 'قلم'),
      ];
      List<String> run(int seed) => Distractors.pick(
            target: pool[0],
            pool: pool,
            fieldOf: (v) => v.target,
            confusionPairs: {
              Insights.confusionKey('d1', 'd3'): 2,
              Insights.confusionKey('d2', 'd4'): 4,
            },
            random: Random(seed),
          ).map((p) => '${p.option}:${p.source.name}').toList();

      expect(run(42), run(42));
      expect(run(42), run(42), reason: 'determinism must hold across calls');
    });
  });

  group('Acceptance #1 — >= 40% of session distractors from learner pairs', () {
    test('a confused learner\u2019s plan measures above the threshold', () {
      final lesson = _lesson([
        _v('en_w1', 'cat', 'قط'),
        _v('en_w2', 'dog', 'كلب'),
        _v('en_w3', 'cart', 'عربة'),
        _v('en_w4', 'bird', 'طائر'),
        _v('en_w5', 'house', 'بيت'),
        _v('en_w6', 'water', 'ماء'),
      ]);

      // Simulated error log: the learner repeatedly mixes up most of this
      // lesson's words (as AppState.recordConfusion would have recorded).
      final confusions = {
        Insights.confusionKey('en_w1', 'en_w3'): 5, // cat <-> cart
        Insights.confusionKey('en_w2', 'en_w4'): 4, // dog <-> bird
        Insights.confusionKey('en_w5', 'en_w6'): 3, // house <-> water
      };

      final plan = ExerciseGen.forLesson(lesson, confusions: confusions);
      final share = Distractors.confusionShare(
        exercises: plan,
        pool: lesson.vocab,
        confusionPairs: confusions,
      );
      expect(share, greaterThanOrEqualTo(0.40),
          reason:
              'distractor-from-confusion KPI: got ${(share * 100).toStringAsFixed(1)}%');
    });

    test('an empty confusion log measures exactly zero', () {
      final lesson = _lesson([
        _v('z1', 'cat', 'قط'),
        _v('z2', 'dog', 'كلب'),
        _v('z3', 'bird', 'طائر'),
        _v('z4', 'house', 'بيت'),
      ]);
      final plan = ExerciseGen.forLesson(lesson);
      expect(
        Distractors.confusionShare(
          exercises: plan,
          pool: lesson.vocab,
          confusionPairs: const {},
        ),
        0.0,
      );
    });
  });

  group('Acceptance #2 — the 40% per-type cap holds across the corpus', () {
    test('no sampled lesson exceeds the cap in any mode (4 courses)', () {
      const langs = ['en', 'fr', 'ur', 'de'];
      const cap = 0.40;
      var sampled = 0;
      final offenders = <String>[];

      for (final lang in langs) {
        final course = loadCourse(lang);
        final lessons = course.allLessons;
        // Spread across the ladder: every 7th lesson reaches ~25+ per
        // course while staying inside the test budget.
        final sample = <Lesson>[];
        for (var i = 0; i < lessons.length; i += 7) {
          sample.add(lessons[i]);
        }
        sample.add(lessons.last);

        for (final mode in LessonMode.values) {
          for (final lesson in sample) {
            sampled++;
            final plan = ExerciseGen.forLesson(lesson, mode: mode);
            expect(plan, isNotEmpty,
                reason: '$lang ${lesson.id}/$mode empty plan');
            final counts = <ExerciseType, int>{};
            for (final e in plan) {
              counts[e.type] = (counts[e.type] ?? 0) + 1;
            }
            counts.forEach((t, c) {
              final ratio = c / plan.length;
              if (ratio > cap + 1e-9) {
                offenders.add(
                    '$lang ${lesson.id}/$mode: $t ${(ratio * 100).toStringAsFixed(0)}%');
              }
            });
            // Audio-first invariant survives balancing: every non-match
            // round keeps audio, and no mcq ever appears.
            if (mode == LessonMode.audio) {
              for (final e in plan) {
                if (e.type == ExerciseType.match) continue;
                expect(e.audioText, isNotEmpty,
                    reason: '$lang ${lesson.id} ${e.type} lost audio');
              }
              expect(plan.map((e) => e.type), isNot(contains(ExerciseType.mcq)),
                  reason: '$lang ${lesson.id} audio plan gained mcq');
            }
          }
        }
      }
      expect(sampled, greaterThan(100),
          reason: 'the sample must cover 100+ lesson/mode combinations');
      expect(offenders, isEmpty, reason: 'cap violations: $offenders');
    });
  });

  group('Production floor (CEFR A2+)', () {
    test('A2 audio lesson gains a production round; A1 does not force one', () {
      // Bare 2-char words: physically UNBUILDABLE and UNDICTATABLE — the
      // floor must convert or fall back without breaking the plan.
      final lesson = _lesson([
        _v('p1', 'go', 'اذهب'),
        _v('p2', 'be', 'كن'),
        _v('p3', 'do', 'افعل'),
        _v('p4', 'say', 'قل'),
        _v('p5', 'see', 'ار'),
      ], id: 'floor1');

      // 'go','be','do' are 2 chars — undictatable; 'say','see' are 3.
      final a2 =
          ExerciseGen.forLesson(lesson, mode: LessonMode.audio, cefr: 'A2');
      final a2Production = a2
          .where((e) =>
              e.type == ExerciseType.build || e.type == ExerciseType.dictation)
          .length;
      expect(a2Production, greaterThanOrEqualTo(1),
          reason: 'A2 lesson must contain a production round');

      final a1 = ExerciseGen.forLesson(lesson, mode: LessonMode.audio);
      expect(a1, isNotEmpty); // A1: no floor requirement, plan still playable
    });

    test('floor conversion keeps the plan valid (answer in options)', () {
      final lesson = _lesson([
        _v('q1', 'open', 'افتح'),
        _v('q2', 'close', 'أغلق'),
        _v('q3', 'send', 'أرسل'),
        _v('q4', 'read', 'اقرأ'),
      ], id: 'floor2');
      final plan =
          ExerciseGen.forLesson(lesson, mode: LessonMode.audio, cefr: 'B1');
      for (final e in plan) {
        if (e.type == ExerciseType.match || e.type == ExerciseType.dictation) {
          continue;
        }
        if (e.options.isNotEmpty) {
          expect(e.options.contains(e.answer), isTrue,
              reason: '${e.type} lost its answer after floor conversion');
        }
        if (e.type == ExerciseType.build) {
          expect(e.tiles.join(' ').toUpperCase().replaceAll(' ', ''),
              e.answer.toUpperCase().replaceAll(' ', ''));
        }
      }
    });
  });

  group('Regression — legacy invariants hold with empty confusions', () {
    test('classic plan: match boss last, mcq present, snappy length', () {
      final lesson = _lesson([
        _v('g1', 'book', 'كتاب', emoji: '📕'),
        _v('g2', 'pen', 'قلم', emoji: '🖊️'),
        _v('g3', 'door', 'باب', emoji: '🚪'),
        _v('g4', 'key', 'مفتاح', emoji: '🔑'),
        _v('g5', 'chair', 'كرسي', emoji: '🪑'),
        _v('g6', 'desk', 'مكتب', emoji: '🛠️'),
      ]);
      final plan = ExerciseGen.forLesson(lesson);
      expect(plan, isNotEmpty);
      expect(plan.last.type, ExerciseType.match);
      expect(plan.map((e) => e.type), contains(ExerciseType.mcq));
      expect(plan.length, lessThanOrEqualTo(14));
      for (final e in plan) {
        if (e.options.isNotEmpty &&
            e.type != ExerciseType.truefalse &&
            e.type != ExerciseType.match) {
          expect(e.options.contains(e.answer), isTrue,
              reason: '${e.type} missing answer');
          expect(e.options.toSet().length, e.options.length,
              reason: '${e.type} duplicate options');
        }
      }
    });

    test('determinism at plan level: same lesson ⇒ same plan', () {
      final lesson = _lesson([
        _v('s1', 'morning', 'صباح'),
        _v('s2', 'evening', 'مساء'),
        _v('s3', 'night', 'ليل'),
        _v('s4', 'noon', 'ظهر'),
        _v('s5', 'today', 'اليوم'),
      ], id: 'seeded-lesson');
      List<String> fingerprint() => ExerciseGen.forLesson(lesson)
          .map((e) => '${e.type.name}|${e.answer}|${e.options.join(",")}')
          .toList();
      expect(fingerprint(), fingerprint());
    });
  });
}
