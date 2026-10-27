// Warmup engine tests (v5.15, plan F3.4).
//
// Acceptance: the lesson-open path starts the first round <= 400ms after
// warmup — verified here by proving the cache hit path does NO generation
// work at tap time (the plan object is pre-built and taken atomically).
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/warmup.dart';

Lesson _lesson(String id) => Lesson(
      id: id,
      titleAr: 'درس',
      titleEn: 'Lesson',
      vocab: List.generate(
        6,
        (i) => Vocab(
          id: '${id}_w$i',
          target: 'word$i',
          translationAr: 'كلمة$i',
          emoji: '📘',
          exampleTarget: 'word$i example sentence here',
          exampleAr: 'مثال للكلمة $i هنا',
        ),
      ),
    );

void main() {
  tearDown(LessonWarmup.clear);

  group('LessonWarmup', () {
    test('warm -> take returns the SAME plan and drains the cache', () async {
      // Test seam: synchronous "isolate" so the future resolves in-turn.
      LessonWarmup.computeFn = (req) async => ExerciseGen.forLesson(
            req.lesson,
            mode: req.mode,
            confusions: req.confusions,
            cefr: req.cefr,
          );
      final lesson = _lesson('warm1');
      final req = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: 'A1',
        confusions: const {},
      );

      LessonWarmup.warm(req);
      await Future<void>.delayed(Duration.zero); // let the seam resolve
      expect(LessonWarmup.hasCachedEntry, isTrue);

      final warm = LessonWarmup.take(req);
      expect(warm, isNotNull);
      expect(warm!.length, greaterThan(0));
      // Same plan the lesson screen would have built synchronously.
      final sync = ExerciseGen.forLesson(lesson,
          mode: LessonMode.classic, confusions: const {}, cefr: 'A1');
      expect(warm.length, sync.length);
      expect(warm.map((e) => e.type), sync.map((e) => e.type));
      // Taken atomically — a second take misses.
      expect(LessonWarmup.take(req), isNull);
    });

    test('fingerprint mismatch NEVER serves a stale plan', () async {
      LessonWarmup.computeFn = (req) async => ExerciseGen.forLesson(
            req.lesson,
            mode: req.mode,
            confusions: req.confusions,
            cefr: req.cefr,
          );
      final lesson = _lesson('warm2');
      final req = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: 'A1',
        confusions: const {},
      );
      LessonWarmup.warm(req);
      await Future<void>.delayed(Duration.zero);

      // The learner recorded a confusion pair since the warmup -> the
      // fingerprint changes -> take() misses and the screen rebuilds.
      final stale = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: 'A1',
        confusions: const {'warm2_w1': 2},
      );
      expect(LessonWarmup.take(stale), isNull);
      // And the ORIGINAL fingerprint still hits.
      expect(LessonWarmup.take(req), isNotNull);
    });

    test('a warmup failure never throws and never poisons the cache', () async {
      LessonWarmup.computeFn = (req) async => throw StateError('isolate died');
      final lesson = _lesson('warm3');
      final req = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: 'A1',
        confusions: const {},
      );
      LessonWarmup.warm(req); // must not throw synchronously
      await Future<void>.delayed(Duration.zero);
      expect(LessonWarmup.hasCachedEntry, isFalse);
    });

    test('warming the same lesson twice keeps only the newest entry', () async {
      var calls = 0;
      LessonWarmup.computeFn = (req) async {
        calls++;
        return ExerciseGen.forLesson(req.lesson,
            mode: req.mode, confusions: req.confusions, cefr: req.cefr);
      };
      final lesson = _lesson('warm4');
      final base = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: 'A1',
        confusions: const {},
      );
      LessonWarmup.warm(base);
      LessonWarmup.warm(base); // same fingerprint -> no recompute
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      LessonWarmup.warm(base.copyWithConfusions(const {'warm4_w2': 1}));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      // The old fingerprint was evicted (one entry per lesson id).
      expect(LessonWarmup.take(base), isNull);
      expect(
          LessonWarmup.take(
            WarmupRequest(
              lessonId: lesson.id,
              lesson: lesson,
              mode: LessonMode.classic,
              cefr: 'A1',
              confusions: const {'warm4_w2': 1},
            ),
          ),
          isNotNull);
    });
  });
}

extension on WarmupRequest {
  WarmupRequest copyWithConfusions(Map<String, int> confusions) =>
      WarmupRequest(
        lessonId: lessonId,
        lesson: lesson,
        mode: mode,
        cefr: cefr,
        confusions: confusions,
      );
}
