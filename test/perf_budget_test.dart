// Frame & open budget gate (v5.15, plan F3.4).
//
// The plan asks for two budgets: p95 frame time <= 16ms and lesson-open
// <= 400ms after warmup, enforced in CI.
//
// HONEST ENGINEERING NOTE (proven by probe): the flutter tester runs in a
// FakeAsync zone whose clock is FAKE — a Stopwatch constructed inside a
// widget test reads 0 microseconds even across a million-iteration busy
// loop, and `pump()` costs are therefore unmeasurable. A "p95 = 0.00ms"
// pass would be a lie, not a gate. So the CI gate enforces what a fake
// clock CAN honestly judge — the REAL-WALL-CLOCK cost of the work the
// frame/open path performs, measured in a plain (non-FakeAsync) test:
//
//   1. LESSON-OPEN budget (<= 400ms, plan F3.4): the synchronous
//      worst-case open path — building a full lesson plan — plus the
//      warmup cache-hit path. The learn path warms this in a background
//      isolate (LessonWarmup), so a warm open is O(cache take).
//   2. ENGINE p95 (<= 16ms): per-lesson plan generation across the REAL
//      four courses — the per-frame-equivalent work the path screen and
//      warmup add to a frame; regressions here are what jank feels like.
//
// True on-device frame timing stays a documented manual/device-lab task
// (recorded in ROADMAP honest remainders) — the tester simply cannot
// produce that number, and pretending otherwise would be dishonest.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/warmup.dart';

Future<List<Course>> _realCourses() async {
  // Real course fixtures via dart:io (the rootBundle channel is not
  // available in a plain test() — the documented house pattern).
  final courses = <Course>[];
  for (final id in ['en', 'ur', 'fr', 'de']) {
    final raw = File('assets/data/course_$id.json').readAsStringSync();
    courses.add(Course.fromJson(jsonDecode(raw)));
  }
  return courses;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Course> courses;

  setUpAll(() async {
    courses = await _realCourses();
  });

  group('lesson-open budget (F3.4, <= 400ms)', () {
    test('worst-case synchronous plan build stays far under 400ms', () {
      var worst = 0.0;
      for (final course in courses) {
        final lesson = course.allLessons.first;
        final sw = Stopwatch()..start();
        final plan = ExerciseGen.forLesson(
          lesson,
          mode: LessonMode.classic,
          confusions: const {},
          cefr: course.units.first.cefr,
        );
        sw.stop();
        expect(plan.length, greaterThan(0));
        if (sw.elapsedMilliseconds > worst) {
          worst = sw.elapsedMilliseconds.toDouble();
        }
      }
      // ignore: avoid_print
      print('PERF worst synchronous plan build = ${worst}ms (budget 400ms)');
      expect(worst, lessThan(400.0));
    });

    test('warm cache-hit path (the warm open) is effectively instant',
        () async {
      final course = courses.first;
      final lesson = course.allLessons.first;
      final req = WarmupRequest(
        lessonId: lesson.id,
        lesson: lesson,
        mode: LessonMode.classic,
        cefr: course.units.first.cefr,
        confusions: const {},
      );
      // The warm-open measurement: fill the cache through the seam with a
      // synchronous injector (the real-isolate round trip is proven in
      // warmup_test.dart; what the OPEN pays is the cache take below).
      LessonWarmup.computeFn = (r) async => LessonWarmup.buildPlan(r);
      LessonWarmup.warm(req);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(LessonWarmup.hasCachedEntry, isTrue,
          reason: 'the seam finished and the plan is cached');

      // The warm open cost = warm(seam) -> take(). take() DRAINS the
      // entry (one-shot), so the honest measurement is 1000 full
      // warm-open cycles — each must fit a fraction of the 400ms budget.
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        LessonWarmup.warm(req);
        // Let the (synchronous-injected) seam resolve, as it already has
        // in production by the time the learner taps.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final warm = LessonWarmup.take(req);
        expect(warm, isNotNull);
      }
      sw.stop();
      final perOpenMs = sw.elapsedMicroseconds / 1000 / 1000.0;
      // ignore: avoid_print
      print('PERF 1000 warm-open cycles = ${sw.elapsedMilliseconds}ms total '
          '= ${perOpenMs.toStringAsFixed(3)}ms per open');
      expect(perOpenMs, lessThan(4.0),
          reason: 'one warm open must cost a fraction of the 16ms frame '
              'budget (4ms guard) — CI runners are slower than dev boxes, '
              'so the budget is per-open, never per-1000');
    });
  });

  group('engine p95 budget (F3.4, <= 16ms per lesson plan)', () {
    test('plan generation across all four real courses', () {
      final samples = <double>[];
      for (final course in courses) {
        for (var i = 0; i < 12 && i < course.allLessons.length; i++) {
          final lesson = course.allLessons[i];
          final sw = Stopwatch()..start();
          final plan = ExerciseGen.forLesson(
            lesson,
            mode: LessonMode.classic,
            confusions: const {},
            cefr: course.units.first.cefr,
          );
          sw.stop();
          expect(plan.length, greaterThan(0));
          samples.add(sw.elapsedMicroseconds / 1000.0);
        }
      }
      samples.sort();
      final p95 = samples[(samples.length * 0.95).ceil() - 1];
      // ignore: avoid_print
      print('PERF engine plan-build p95 = ${p95.toStringAsFixed(2)}ms over '
          '${samples.length} lessons (budget 16ms)');
      expect(p95, lessThan(16.0));
    });
  });
}
