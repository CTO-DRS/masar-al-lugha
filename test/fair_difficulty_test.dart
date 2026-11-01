// F1.1b — fair-difficulty challenge mode (v5.20, 12-month plan Q1 closure).
//
// Covers the plan acceptance criteria:
//  1. challengePool assembles SEEN vocab from PRIOR nearby-domain units
//     only — new material never leaks, higher bands never leak;
//  2. challenge-mode plans actually CONTAIN prior-unit decoys (the local
//     KPI: Distractors.challengeShare > 0), while normal mode stays
//     byte-identical (share == 0, options ⊆ pool ∪ reserve);
//  3. fairness: no UNSEEN corpus word ever appears in any option;
//  4. same inputs + same seed ⇒ same plan (determinism, challenge too);
//  5. the sequential match-boss repair chain (v5.13 remainder) picks
//     words in board order and stops when the board is treated;
//  6. the warmup fingerprint covers the challenge corpus — a stale plan
//     built for the other difficulty mode is never served;
//  7. the setting round-trips through the schema-2 payload (additive,
//     default off — old payloads keep behaving exactly as before).
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/distractors.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/insights.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/repair.dart';
import 'package:masar_al_lugha/warmup.dart';

Course loadCourse(String id) {
  final raw = File('assets/data/course_$id.json').readAsStringSync();
  return Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Vocab _v(String id, String target, String ar) =>
    Vocab(id: id, target: target, translationAr: ar);

Lesson _lesson(List<Vocab> vocab, {String id = 't1'}) =>
    Lesson(id: id, titleAr: 'درس', titleEn: 'Lesson', vocab: vocab);

void main() {
  group('Distractors.challengePool — fairness invariants', () {
    // A tiny synthetic course: u0 (food, A1) -> u1 (food, A2) -> u2
    // (travel, A1) -> u3 (food, B1, the lesson's own unit).
    Course tinyCourse() {
      Unit unit(String id, String ar, String en, String cefr,
              List<Vocab> vocab) =>
          Unit(
            id: id,
            titleAr: ar,
            titleEn: en,
            colorHex: '#000000',
            lessons: [
              Lesson(
                  id: '${id}_l1',
                  titleAr: 'درس',
                  titleEn: 'Lesson',
                  vocab: vocab)
            ],
            cefr: cefr,
          );
      return Course(
        id: 'tt',
        nameAr: 'تجربة',
        nameEn: 'Test',
        flag: '🏳️',
        ttsLang: 'en-US',
        units: [
          unit('u0', 'الطعام', 'Food', 'A1', [
            _v('a1', 'cheese', 'جبن'), // collides with lesson d4 -> dropped
            _v('a2', 'bread', 'خبز'),
          ]),
          unit('u1', 'الطعام الصحي', 'Healthy food', 'A2', [
            _v('b1', 'apple', 'تفاح'),
            _v('b2', 'salad', 'سلطة'),
            _v('b3', 'unseen-word', 'كلمة-غير-مروية'),
          ]),
          unit('u2', 'السفر', 'Travel', 'A1', [
            _v('c1', 'train', 'قطار'),
          ]),
          unit('u3', 'المطعم', 'Restaurant', 'B1', [
            _v('d1', 'menu', 'قائمة'),
            _v('d2', 'waiter', 'نادل'),
            _v('d3', 'bill', 'فاتورة'),
            _v('d4', 'cheese', 'جبن'), // target-string collision with a1
          ]),
        ],
      );
    }

    test('seen-only: a word without a card is never offered', () {
      final course = tinyCourse();
      final pool = Distractors.challengePool(
        course: course,
        lessonId: 'u3_l1',
        seenIds: {'a1', 'a2', 'b1', 'b2', 'c1'}, // b3 unseen
      );
      final ids = pool.map((v) => v.id).toSet();
      expect(ids, containsAll({'a2', 'b1', 'b2'}));
      expect(ids, isNot(contains('b3')), reason: 'unseen = unfair');
      expect(ids, isNot(contains('a1')),
          reason: 'string collision with the lesson = ambiguous option');
    });

    test('prior-only: current-unit words and later units never enter', () {
      final course = tinyCourse();
      final pool = Distractors.challengePool(
        course: course,
        lessonId: 'u3_l1',
        seenIds: {'a1', 'b1', 'c1', 'd2'}, // d2 lives in the lesson's unit
      );
      final ids = pool.map((v) => v.id).toSet();
      expect(ids, isNot(contains('d2')), reason: 'lesson vocab is the pool');
      expect(ids, isNot(contains('d1')));
      expect(ids, isNot(contains('d3')));
    });

    test('string collisions with the lesson are dropped (both fields)', () {
      final course = tinyCourse();
      final pool = Distractors.challengePool(
        course: course,
        lessonId: 'u3_l1',
        seenIds: {'a1', 'a2', 'b1', 'b2', 'c1'},
      );
      // a1 'cheese' collides with lesson d4 'cheese' -> dropped.
      expect(pool.map((v) => v.id), isNot(contains('a1')));
      expect(pool.map((v) => v.id), contains('a2'));
    });

    test('same-domain pass first, relax pass never goes above the band', () {
      final course = tinyCourse();
      final full = Distractors.challengePool(
        course: course,
        lessonId: 'u3_l1',
        seenIds: {'a1', 'a2', 'b1', 'b2', 'c1'},
        cap: 24,
      );
      // The lesson unit is B1 food; the relax pass admits prior units with
      // cefr rank <= B1 — travel A1 (c1) qualifies; nothing higher exists.
      expect(full.map((v) => v.id), contains('c1'));
      // With a tight cap the SAME-DOMAIN rows win first (course order).
      final tight = Distractors.challengePool(
        course: course,
        lessonId: 'u3_l1',
        seenIds: {'a1', 'a2', 'b1', 'b2', 'c1'},
        cap: 2,
      );
      expect(tight.length, 2);
      expect(tight.map((v) => v.id), everyElement(isIn({'a2', 'b1', 'b2'})));
    });

    test('deterministic: same inputs, same corpus, course order', () {
      final course = tinyCourse();
      final seen = {'a1', 'a2', 'b1', 'b2', 'c1'};
      final p1 = Distractors.challengePool(
          course: course, lessonId: 'u3_l1', seenIds: seen);
      final p2 = Distractors.challengePool(
          course: course, lessonId: 'u3_l1', seenIds: seen);
      expect(p1.map((v) => v.id).toList(), p2.map((v) => v.id).toList());
    });

    test('degenerate inputs yield the empty corpus', () {
      final course = tinyCourse();
      expect(
        Distractors.challengePool(
            course: course, lessonId: 'nope', seenIds: {'a1'}),
        isEmpty,
      );
      expect(
        Distractors.challengePool(
            course: course, lessonId: 'u0_l1', seenIds: {'a1'}),
        isEmpty,
        reason: 'first unit has no prior units',
      );
      expect(
        Distractors.challengePool(
            course: course, lessonId: 'u3_l1', seenIds: const {}),
        isEmpty,
      );
    });

    test('REAL course smoke: prior seen vocab of unit 3+ feeds the pool', () {
      final course = loadCourse('en');
      // Seen = every vocab row of the first three units.
      final seen = <String>{
        for (final u in course.units.take(3))
          for (final l in u.lessons)
            for (final v in l.vocab) v.id,
      };
      // The 4th unit's first lesson gets a real challenge corpus.
      final lesson = course.units[3].lessons.first;
      final pool = Distractors.challengePool(
        course: course,
        lessonId: lesson.id,
        seenIds: seen,
      );
      expect(pool, isNotEmpty);
      expect(pool.length, lessThanOrEqualTo(24));
      for (final v in pool) {
        expect(seen, contains(v.id), reason: '${v.id} must be seen');
      }
    });
  });

  group('Distractors.pick — extraPool (challenge random fill)', () {
    final pool = [
      _v('w1', 'cat', 'قط'),
      _v('w2', 'dog', 'كلب'),
      _v('w3', 'sun', 'شمس'),
      _v('w4', 'bird', 'طائر'),
    ];
    final extras = [
      _v('x1', 'lion', 'أسد'),
      _v('x2', 'tiger', 'نمر'),
      _v('x3', 'bear', 'دب'),
    ];

    test('challenge mode: random slots come from the seen prior corpus', () {
      final picks = Distractors.pick(
        target: pool[0], // cat — no confusion data, no look-alikes needed
        pool: pool,
        fieldOf: (v) => v.target,
        random: Random(7),
        extraPool: extras,
      );
      expect(picks.length, 3);
      expect(
        picks.every((p) => p.source == DistractorSource.priorUnit),
        true,
        reason: 'extras are drawn before the lesson pool',
      );
      expect(picks.map((p) => p.option), containsAll(['lion', 'tiger']));
    });

    test('confusion priority 1 is never displaced by extras', () {
      final picks = Distractors.pick(
        target: pool[0],
        pool: pool,
        fieldOf: (v) => v.target,
        confusionPairs: {Insights.confusionKey('w1', 'w3'): 4}, // cat<->sun
        random: Random(7),
        extraPool: extras,
      );
      expect(picks.first.option, 'sun');
      expect(picks.first.source, DistractorSource.learnerConfusion);
    });

    test('normal mode (empty extras) never emits priorUnit sources', () {
      final picks = Distractors.pick(
        target: pool[0],
        pool: pool,
        fieldOf: (v) => v.target,
        random: Random(7),
      );
      expect(
        picks.every((p) => p.source != DistractorSource.priorUnit),
        true,
      );
    });

    test('same seed ⇒ same challenge pick (determinism)', () {
      List<String> run() => Distractors.pick(
            target: pool[1],
            pool: pool,
            fieldOf: (v) => v.target,
            random: Random(42),
            extraPool: extras,
          ).map((p) => p.option).toList();
      expect(run(), run());
    });
  });

  group('ExerciseGen — challenge plans and normal-mode identity', () {
    final course = loadCourse('en');
    // A mid-course lesson: prior units hold seen material.
    final lesson = course.units[4].lessons.first;
    final seen = <String>{
      for (final u in course.units.take(4))
        for (final l in u.lessons)
          for (final v in l.vocab) v.id,
    };
    final extras = Distractors.challengePool(
      course: course,
      lessonId: lesson.id,
      seenIds: seen,
    );

    test('the local KPI: challengeShare > 0 in challenge mode', () {
      expect(extras, isNotEmpty, reason: 'fixture must provide prior vocab');
      final plan = ExerciseGen.forLesson(
        lesson,
        confusions: const {},
        cefr: course.units[4].cefr,
        challengePool: extras,
      );
      expect(
          Distractors.challengeShare(
            exercises: plan,
            pool: lesson.vocab,
            extraPool: extras,
          ),
          greaterThan(0));
    });

    test('normal mode: challengeShare is exactly 0 (byte-identical plans)', () {
      final plan = ExerciseGen.forLesson(
        lesson,
        confusions: const {},
        cefr: course.units[4].cefr,
      );
      expect(
          Distractors.challengeShare(
            exercises: plan,
            pool: lesson.vocab,
            extraPool: const [],
          ),
          0);
    });

    test('FAIRNESS: no unseen corpus word ever appears in any option', () {
      final corpus = course.allVocab;
      final lessonIds = lesson.vocab.map((v) => v.id).toSet();
      // "Unseen" = neither in the seen set NOR in the lesson itself (the
      // lesson's own words ARE the pool — they are being taught now).
      final unseen = corpus
          .where((v) => !seen.contains(v.id) && !lessonIds.contains(v.id))
          .toSet();
      final unseenStrings = <String>{
        for (final v in unseen) v.target,
        for (final v in unseen) v.translationAr,
      };
      final challenge = ExerciseGen.forLesson(
        lesson,
        confusions: const {},
        cefr: course.units[4].cefr,
        challengePool: extras,
      );
      final normal = ExerciseGen.forLesson(
        lesson,
        confusions: const {},
        cefr: course.units[4].cefr,
      );
      for (final ex in [...challenge, ...normal]) {
        for (final o in ex.options) {
          expect(unseenStrings, isNot(contains(o)),
              reason: 'unseen "$o" leaked into a ${ex.type.name} round');
        }
      }
    });

    test('same seed ⇒ same challenge plan (determinism)', () {
      List<List<String>> run() => ExerciseGen.forLesson(
            lesson,
            confusions: const {},
            cefr: course.units[4].cefr,
            challengePool: extras,
          ).map((e) => [...e.options, ...e.tiles]).toList();
      expect(run(), run());
    });
  });

  group('RepairEngine.nextMatchRepairWord — sequential board repairs', () {
    test('board order, first-mistake rule, completion', () {
      final missed = <String>{'m3', 'm1', 'm2'}; // insertion order kept
      final repaired = <String>{};
      expect(RepairEngine.nextMatchRepairWord(missed, repaired), 'm3');
      repaired.add('m3');
      expect(RepairEngine.nextMatchRepairWord(missed, repaired), 'm1');
      repaired
        ..add('m1')
        ..add('m2');
      expect(RepairEngine.nextMatchRepairWord(missed, repaired), isNull);
    });

    test('already-repaired words from earlier boards are skipped', () {
      final missed = <String>{'m1', 'm2'};
      expect(RepairEngine.nextMatchRepairWord(missed, {'m1'}), 'm2');
      expect(RepairEngine.nextMatchRepairWord(missed, {'m1', 'm2'}), isNull);
    });

    test('empty mistake set is immediately done', () {
      expect(RepairEngine.nextMatchRepairWord(const {}, const {}), isNull);
    });
  });

  group('WarmupRequest fingerprint — the challenge corpus is an input', () {
    final lesson = _lesson([_v('w1', 'cat', 'قط')]);
    final extrasA = [_v('x1', 'lion', 'أسد')];
    final extrasB = [_v('x2', 'tiger', 'نمر')];

    test('different corpus ⇒ different fingerprint', () {
      final a = WarmupRequest(
          lessonId: 'l',
          lesson: lesson,
          mode: LessonMode.classic,
          cefr: 'A1',
          confusions: const {},
          challengePool: extrasA);
      final b = WarmupRequest(
          lessonId: 'l',
          lesson: lesson,
          mode: LessonMode.classic,
          cefr: 'A1',
          confusions: const {},
          challengePool: extrasB);
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('same corpus (any order) ⇒ same fingerprint', () {
      WarmupRequest req(List<Vocab> pool) => WarmupRequest(
            lessonId: 'l',
            lesson: lesson,
            mode: LessonMode.classic,
            cefr: 'A1',
            confusions: const {},
            challengePool: pool,
          );
      expect(
          req(extrasA).fingerprint, req(extrasA.reversed.toList()).fingerprint);
      expect(req(const []).fingerprint, isNot(req(extrasA).fingerprint),
          reason: 'mode flip must invalidate');
    });
  });

  group('challengeMode setting — additive schema-2 round-trip', () {
    test('defaults off; survives save/load; old payloads unaffected', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      expect(st.challengeMode, isFalse, reason: 'additive, off by default');

      st.setChallengeMode(true);
      expect(st.challengeMode, isTrue);
      await st.save(); // the setter's save is fire-and-forget — flush it

      final st2 = AppState();
      await st2.load();
      expect(st2.challengeMode, isTrue);

      // A payload written BEFORE v5.20 (no challengeMode key) keeps the
      // default — the byte-compat contract of additive settings.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'progress_json_v1': jsonEncode(<String, Object>{
          'schema': 2,
          'xp': 12,
          'settings': <String, Object>{'darkMode': true},
        }),
      });
      final st3 = AppState();
      await st3.load();
      expect(st3.challengeMode, isFalse);
      expect(st3.darkMode, isTrue);
    });
  });
}
