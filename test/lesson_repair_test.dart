// F1.2 widget tests — the instant micro-repair card inside LessonScreen.
// Covered acceptance criteria from the 12-month plan §Q1 F1.2:
//  1. any FIRST mistake in a session opens the repair within one frame;
//  2. the failed question is NOT re-asked immediately — it returns exactly
//     after the >= 3-round gap (played as a normal scored round);
//  3. reduce-motion shows the repair instantly, without the intro animation;
//  4. the repair is XP-neutral: no recordAnswer/hearts effects during the
//     whole mistake -> repair -> success cycle.
// The exercise plan is deterministic (seeded by lesson id), so the test
// knows exactly which round it is driving.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/screens/lesson_screen.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';

import 'fake_notifications.dart';

const _lessonId = 'fx_repair';

Lesson _lesson() => const Lesson(
      id: _lessonId,
      titleAr: 'درس الإصلاح',
      titleEn: 'Repair lesson',
      vocab: [
        Vocab(
            id: 'w1',
            target: 'Cat',
            translationAr: 'قط',
            emoji: '🐱',
            exampleTarget: 'The cat is small',
            exampleAr: 'القط صغير'),
        Vocab(
            id: 'w2',
            target: 'Dog',
            translationAr: 'كلب',
            emoji: '🐶',
            exampleTarget: 'The dog runs fast',
            exampleAr: 'الكلب يجري بسرعة'),
        Vocab(id: 'w3', target: 'Bird', translationAr: 'طائر', emoji: '🐦'),
        Vocab(id: 'w4', target: 'Fish', translationAr: 'سمكة', emoji: '🐟'),
        Vocab(id: 'w5', target: 'Bread', translationAr: 'خبز', emoji: '🍞'),
        Vocab(id: 'w6', target: 'Tree', translationAr: 'شجرة', emoji: '🌳'),
      ],
    );

String tr(String k) => L.t('ar', k);

Future<AppState> _state({bool reduceMotion = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
  st.courses['en'] = const Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: 'u1',
        titleAr: 'وحدة',
        titleEn: 'Unit',
        colorHex: '#58CC02',
        lessons: [],
        cefr: 'A1',
      ),
    ],
  );
  // The screen looks its lesson up in the units to resolve the CEFR band —
  // rebuild the unit with the lesson included.
  st.courses['en'] = Course(
    id: 'en',
    nameAr: 'إنجليزي',
    nameEn: 'English',
    flag: '🇬🇧',
    ttsLang: 'en-US',
    units: [
      Unit(
          id: 'u1',
          titleAr: 'وحدة',
          titleEn: 'Unit',
          colorHex: '#58CC02',
          lessons: [_lesson()]),
    ],
  );
  st.courseId = 'en';
  st.reduceMotion = reduceMotion;
  return st;
}

Widget _harness(AppState st) => AppScope(
      state: st,
      tts: TtsService(),
      reminders: ReminderService(FakeNotificationApi()),
      child: MaterialApp(home: LessonScreen(lesson: _lesson())),
    );

/// Standard Android phone surface (360x780 logical @ dpr 3). The default
/// 800x600 test surface is shorter than any real phone and would push the
/// option grid's second row under the bottom bar — a test artifact, not a
/// product defect.
void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1080, 2340);
  addTearDown(tester.view.reset);
}

/// Taps an option by its rendered text.
Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pump();
}

/// Plays the CURRENT round correctly (works for every option round, build
/// and dictation — the types the plan's first pass produces).
Future<void> _answerCorrect(WidgetTester tester, Exercise e) async {
  switch (e.type) {
    case ExerciseType.build:
      // NOTE: derive the token split from the ANSWER, not from the tiles'
      // space heuristic ('C A T' contains spaces even for a single word).
      final tokens = e.answer.contains(' ')
          ? e.answer.split(' ')
          : e.answer.toUpperCase().split('');
      for (final t in tokens) {
        await _tap(tester, t);
      }
      break;
    case ExerciseType.truefalse:
      await _tap(tester,
          e.answer == 'true' ? '✅ ${tr('trueWord')}' : '❌ ${tr('falseWord')}');
      break;
    case ExerciseType.dictation:
      await tester.enterText(find.byType(TextField), e.answer);
      await tester.pump();
      break;
    default:
      await _tap(tester, e.answer);
      break;
  }
  await _tap(tester, tr('check'));
  await tester.pump();
}

/// Continues past the green feedback bar.
Future<void> _continue(WidgetTester tester) async {
  await _tap(tester, tr('continue'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final plan = ExerciseGen.forLesson(_lesson());

  test('precondition: deterministic plan opens reverse/mcq/listen/build', () {
    expect(plan.first.type, ExerciseType.reverse,
        reason: 'cycle[0] is reverse for the first shuffled word');
    expect(plan[1].type, ExerciseType.mcq);
    expect(plan[2].type, ExerciseType.listen);
    expect(plan[3].type, ExerciseType.build);
    expect(plan.length, greaterThanOrEqualTo(8));
  });

  testWidgets(
      'F1.2 acceptance 1+2+4: first mistake opens the repair in one frame, '
      'repair is XP-neutral, and the failed question is not re-asked before '
      '3 rounds', (tester) async {
    final st = await _state();
    final original = plan.first;
    final wrongPick = original.options.firstWhere((o) => o != original.answer);
    _usePhoneSurface(tester);

    await tester.pumpWidget(_harness(st));
    await tester.pump(); // postFrameCallback: plan speak + first build

    // --- the deliberate mistake -------------------------------------------
    await _tap(tester, wrongPick);
    await _tap(tester, tr('check'));
    await tester.pump();

    expect(st.totalAnswers, 1, reason: 'the scored round was recorded');
    expect(find.byKey(const ValueKey('repairOpen')), findsOneWidget,
        reason: 'a first mistake offers the quick fix');
    expect(find.byKey(const ValueKey('lessonContinue')), findsNothing);

    // --- acceptance 1: the repair opens within ONE frame ------------------
    await tester.tap(find.byKey(const ValueKey('repairOpen')));
    await tester.pump(); // a single frame
    expect(find.byKey(const ValueKey('repairPanel')), findsOneWidget,
        reason: 'repair card visible within one frame');
    // let the 250ms intro animation finish before interacting
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('repairTitle')), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget, reason: 'the word being repaired');
    expect(find.text('The dog runs fast'), findsOneWidget,
        reason: 'the corpus example anchors the hint');

    // --- hint -> re-rolled question ---------------------------------------
    await tester.tap(find.byKey(const ValueKey('repairHintCta')));
    await tester.pump();
    // acceptance: different distractors — the old decoy is gone
    expect(find.text(wrongPick), findsNothing,
        reason: 're-ask must not recycle the same decoys');
    expect(find.text(original.answer), findsOneWidget);

    // --- answer the re-ask; XP must stay untouched (acceptance 4) ---------
    await _tap(tester, original.answer);
    await _tap(tester, tr('check'));
    await tester.pump();
    expect(st.totalAnswers, 1, reason: 'repair rounds never hit recordAnswer');
    expect(st.wordMistakes['w2'], 1,
        reason: 'the mistake stays counted — repaired, not erased');
    expect(find.byKey(const ValueKey('repairDone')), findsOneWidget);

    // --- success resumes the lesson ---------------------------------------
    await tester.tap(find.byKey(const ValueKey('repairDone')));
    await tester.pump();
    expect(find.byKey(const ValueKey('repairPanel')), findsNothing);
    expect(st.totalAnswers, 1, reason: 'still XP-neutral after the repair');

    // --- acceptance 2: the failed round returns after >= 3 rounds ---------
    // Plan rounds 2..4 play first (mcq, listen, build for this fixture);
    // none of them may render the original round's full option set.
    for (var played = 0; played < 3; played++) {
      final allOriginalVisible =
          original.options.every((o) => find.text(o).evaluate().isNotEmpty);
      expect(allOriginalVisible, isFalse,
          reason: 'round ${played + 1} after the repair must not be the '
              'failed question');
      await _answerCorrect(tester, plan[played + 1]);
      await _continue(tester);
    }
    // The 4th round IS the re-queued original — same prompt, same options.
    expect(find.text(original.prompt), findsOneWidget);
    for (final o in original.options) {
      expect(find.text(o), findsOneWidget,
          reason: 'the failed question came back intact');
    }
    // And answering it correctly is a NORMAL scored round.
    await _tap(tester, original.answer);
    await _tap(tester, tr('check'));
    await tester.pump();
    expect(st.totalAnswers, 5,
        reason: '1 wrong + 3 intervening rounds + 1 re-queued correct — '
            'exactly the scored rounds; the repair added none');
    await st.flush();
  });

  testWidgets(
      'F1.2 acceptance 3: reduce-motion renders the repair instantly, '
      'with no intro animation', (tester) async {
    final st = await _state(reduceMotion: true);
    final original = plan.first;
    final wrongPick = original.options.firstWhere((o) => o != original.answer);
    _usePhoneSurface(tester);

    await tester.pumpWidget(_harness(st));
    await tester.pump();

    await _tap(tester, wrongPick);
    await _tap(tester, tr('check'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('repairOpen')));
    await tester.pump(); // exactly one frame — content must already be there
    expect(find.byKey(const ValueKey('repairPanel')), findsOneWidget);
    expect(find.text(tr('repairTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('repairIntro')), findsNothing,
        reason: 'no entrance animation under reduce-motion');
    await st.flush();
  });

  testWidgets(
      'F1.2: a SECOND mistake on the same word does not re-open the repair',
      (tester) async {
    final st = await _state();
    final original = plan.first;
    final wrongPick = original.options.firstWhere((o) => o != original.answer);
    _usePhoneSurface(tester);

    await tester.pumpWidget(_harness(st));
    await tester.pump();

    // First mistake -> repair opens -> succeed at the re-ask.
    await _tap(tester, wrongPick);
    await _tap(tester, tr('check'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('repairOpen')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // intro settles
    await tester.tap(find.byKey(const ValueKey('repairHintCta')));
    await tester.pump();
    await _tap(tester, original.answer);
    await _tap(tester, tr('check'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('repairDone')));
    await tester.pump();

    // Drive to the re-queued original and fail it AGAIN: no second repair.
    for (var played = 0; played < 3; played++) {
      await _answerCorrect(tester, plan[played + 1]);
      await _continue(tester);
    }
    await _tap(tester, wrongPick);
    await _tap(tester, tr('check'));
    await tester.pump();
    expect(find.byKey(const ValueKey('repairOpen')), findsNothing,
        reason: 'one repair per word per session');
    expect(find.byKey(const ValueKey('lessonContinue')), findsOneWidget,
        reason: 'plain continue — the mistake is only counted');
    await st.flush();
  });
}
