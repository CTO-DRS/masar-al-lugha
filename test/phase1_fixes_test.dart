// Phase-1 (v5.17) regression tests — every audit fix lands with a test
// that pins it. Audit IDs referenced below:
//  H-1  pronunciation screen crashed on the first frame (late _current)
//  H-2  profile data bleed: F2.x engine fields survived resetAll and
//       switchProfile, and load() merged lapseLog over the previous slot
//  H-3  lesson double-tap: one answer counted twice / lesson XP awarded twice
//  M-1  failed import left half-applied state in memory
//  M-4  flashcards rating double-tap double-counted
//  P-1  dictionary search rescanned the corpus on every rebuild (regression:
//       the memoized index must still return correct results)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/exercise_gen.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/theme.dart';
import 'package:masar_al_lugha/screens/dictionary.dart';
import 'package:masar_al_lugha/screens/flashcards.dart';
import 'package:masar_al_lugha/screens/lesson_screen.dart';
import 'package:masar_al_lugha/screens/pronunciation_screen.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';

import 'fake_notifications.dart';

// ---------------------------------------------------------------- harness

const _lessonId = 'ph1_lesson';

Lesson _lesson() => const Lesson(
      id: _lessonId,
      titleAr: 'درس المرحلة',
      titleEn: 'Phase lesson',
      vocab: [
        Vocab(
            id: 'ph1_w1',
            target: 'Cat',
            translationAr: 'قط',
            emoji: '🐱',
            exampleTarget: 'The cat is small',
            exampleAr: 'القط صغير'),
        Vocab(
            id: 'ph1_w2',
            target: 'Dog',
            translationAr: 'كلب',
            emoji: '🐶',
            exampleTarget: 'The dog runs fast',
            exampleAr: 'الكلب يجري بسرعة'),
        Vocab(
            id: 'ph1_w3',
            target: 'Bird',
            translationAr: 'طائر',
            emoji: '🐦',
            exampleTarget: 'The bird sings',
            exampleAr: 'الطائر يغني'),
      ],
    );

Future<AppState> _state() async {
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
        cefr: 'A1',
        lessons: [],
      ),
    ],
  );
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
        cefr: 'A1',
        lessons: [_lesson()],
      ),
    ],
  );
  st.courseId = 'en';
  st.reduceMotion = true; // deterministic rendering, no intro tweens
  return st;
}

Widget _harness(AppState st, Widget home) => AppScope(
      state: st,
      tts: TtsService(),
      reminders: ReminderService(FakeNotificationApi()),
      child: MaterialApp(home: home),
    );

void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1080, 2340);
  addTearDown(tester.view.reset);
}

List<Exercise> _plan(AppState st) => ExerciseGen.forLesson(
      _lesson(),
      mode: LessonMode.classic,
      confusions: st.confusionPairs,
      cefr: 'A1',
    );

/// Scored correct events for a perfectly played round: one per normal round,
/// one per matched pair inside the match boss (matches correctCount exactly).
int _scoredCorrect(Exercise ex) =>
    ex.type == ExerciseType.match ? ex.matchLeft.length : 1;

/// Answers the current round CORRECTLY, exactly like a human would.
Future<void> _answerCorrectly(WidgetTester tester, Exercise ex) async {
  switch (ex.type) {
    case ExerciseType.mcq:
    case ExerciseType.reverse:
    case ExerciseType.listen:
    case ExerciseType.listenComp:
    case ExerciseType.picToWord:
    case ExerciseType.fillblank:
      final f = find.widgetWithText(OptionCard, ex.answer);
      expect(f, findsOneWidget,
          reason: 'round ${ex.type} answer "${ex.answer}"');
      await tester.tap(f.first);
      break;
    case ExerciseType.wordToPic:
      final f = find.widgetWithText(PictureCard, ex.answer);
      expect(f, findsOneWidget,
          reason: 'round ${ex.type} answer "${ex.answer}"');
      await tester.tap(f.first);
      break;
    case ExerciseType.truefalse:
      await tester
          .tap(find.textContaining(ex.answer == 'true' ? '✅' : '❌').first);
      break;
    case ExerciseType.dictation:
      await tester.enterText(find.byType(TextField), ex.answer);
      break;
    case ExerciseType.build:
      for (final t in ex.tiles) {
        // The answer line (top) re-renders placed tiles; the bank (bottom)
        // comes later in tree order, so .last always hits the bank.
        await tester.tap(find.text(t).last, warnIfMissed: false);
        await tester.pump();
      }
      break;
    case ExerciseType.match:
      for (var i = 0; i < ex.matchLeft.length; i++) {
        await tester.tap(find.text(ex.matchLeft[i]).first);
        await tester.pump();
        await tester.tap(find.text(ex.matchRight[i]).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500)); // flash delay
      }
      return; // the match boss advances by itself
  }
  await tester.pump();
}

// ------------------------------------------------- H-2: data integrity

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('H-2: profile engine state is per-profile', () {
    test('resetAll wipes the F2.x engine fields', () async {
      final st = await _state();
      st.lapseLog['ph1_w1'] = [20000];
      st.calibrationLog.add([500, 1]);
      st.streakFreezes = 2;
      st.lastFreezeAwardMark = 7;

      await st.resetAll();

      expect(st.lapseLog, isEmpty);
      expect(st.calibrationLog, isEmpty);
      expect(st.streakFreezes, 0);
      expect(st.lastFreezeAwardMark, 0);
    });

    test('switchProfile does not bleed engine state into the new slot',
        () async {
      final st = await _state();
      await st.load();
      st.lapseLog['ph1_w1'] = [20000];
      st.calibrationLog.add([400, 0]);
      st.streakFreezes = 2;
      await st.save();

      await st.switchProfile(2);

      expect(st.profileSlot, 2);
      expect(st.lapseLog, isEmpty, reason: 'slot 2 must start clean');
      expect(st.calibrationLog, isEmpty);
      expect(st.streakFreezes, 0);
    });

    test('load() REPLACES engine containers instead of merging', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'progress_json_v1',
        jsonEncode({
          'schema': 2,
          'xp': 5,
          'lapseLog': {
            'ph1_w1': [20000],
          },
          'insights': {
            'calibration': [
              [500, 1],
            ],
          },
          'streakFreezes': 1,
        }),
      );
      final st = AppState();
      // Stale in-memory state a previous profile left behind:
      st.lapseLog['ghost'] = [1];
      st.calibrationLog.add([123, 0]);
      st.streakFreezes = 2;

      await st.load();

      expect(st.lapseLog.keys, ['ph1_w1'], reason: 'ghost must be replaced');
      expect(st.calibrationLog, [
        [500, 1]
      ]);
      expect(st.streakFreezes, 1);
      expect(st.xp, 5);
    });

    test('load() with an old payload lacking engine keys resets them',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'progress_json_v1', jsonEncode({'schema': 2, 'xp': 3}));
      final st = AppState();
      st.lapseLog['ghost'] = [1];
      st.streakFreezes = 2;

      await st.load();

      expect(st.lapseLog, isEmpty);
      expect(st.streakFreezes, 0);
      expect(st.xp, 3);
    });
  });

  group('M-1: failed import recovers', () {
    test('a mid-parse failure restores the persisted snapshot', () async {
      final st = await _state();
      st.xp = 50;
      await st.save(); // the snapshot the recovery reloads

      // Valid header, then xp parses fine (999 assigned), then lessonStars
      // has the wrong TYPE — the throw lands AFTER xp was mutated, which is
      // exactly the partial-mutation window the fix heals.
      final bad = jsonEncode({
        'app': 'masar-al-lugha',
        'progress': {'xp': 999, 'lessonStars': 'oops'},
      });

      final err = await st.importProfileJson(bad);

      expect(err, 'importInvalid');
      expect(st.xp, 50, reason: 'state must be restored, not half-applied');
      expect(st.lessonStars, isEmpty);
    });
  });

  group('H-3: lesson input is counted exactly once', () {
    testWidgets('double-tap on Check scores the round once', (tester) async {
      _usePhoneSurface(tester);
      final st = await _state();
      final plan = _plan(st);
      // Precondition for this test's shape: the FIRST round must be a
      // scored option round (not the match boss, which has no Check).
      expect(plan.first.type, isNot(ExerciseType.match));

      await tester.pumpWidget(_harness(st, LessonScreen(lesson: _lesson())));
      await tester.pump();
      await tester.pump();

      await _answerCorrectly(tester, plan.first);

      final check = find.text('تحقق');
      expect(check, findsOneWidget);
      await tester.tap(check.first);
      await tester.tap(check.first); // same frame — the defect window
      await tester.pump();

      expect(st.totalAnswers, 1, reason: 'one answer, not two');
      expect(find.byKey(const ValueKey('lessonContinue')), findsOneWidget);
      await st.flush(); // settle the debounced-save timer
    });

    testWidgets('a double-tapped final Continue awards the lesson XP once',
        (tester) async {
      _usePhoneSurface(tester);
      final st = await _state();
      final plan = _plan(st);
      final expectedXp =
          10 + 5 + plan.fold<int>(0, (s, e) => s + _scoredCorrect(e));

      await tester.pumpWidget(_harness(st, LessonScreen(lesson: _lesson())));
      await tester.pump();
      await tester.pump();

      for (var i = 0; i < plan.length; i++) {
        final ex = plan[i];
        await _answerCorrectly(tester, ex);
        if (ex.type == ExerciseType.match) {
          // Perfect board: no repair opens; the boss advances by itself.
          await tester.pump(const Duration(milliseconds: 550));
          continue;
        }
        await tester.tap(find.text('تحقق').first);
        await tester.pump();
        final cont = find.byKey(const ValueKey('lessonContinue'));
        expect(cont, findsOneWidget, reason: 'round $i (${ex.type})');
        if (i == plan.length - 1) {
          await tester.tap(cont.first);
          await tester.tap(cont.first); // the defect window
        } else {
          await tester.tap(cont.first);
        }
        await tester.pump();
        await tester.pump();
      }

      // The result screen schedules its 700ms badge reveal timer — let it
      // fire before the test ends or the binding flags a pending timer.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(st.xp, expectedXp,
          reason: 'XP must be awarded exactly once for a perfect lesson');
      expect(st.lessonStars.containsKey(_lessonId), isTrue);
      await st.flush(); // settle the debounced-save timer
    });
  });

  group('M-4: flashcard rating double-tap', () {
    testWidgets('rating one card twice counts one review', (tester) async {
      _usePhoneSurface(tester);
      final st = await _state();
      st.lessonStars[_lessonId] = 3; // lesson completed → vocab is earned
      st.cards['ph1_w1'] = CardData(ease: 2.5, intervalDays: 1, dueEpochMs: 0)
        ..reps = 1
        ..state = 'review';

      await tester.pumpWidget(_harness(st, const FlashcardsScreen()));
      await tester.pump();
      await tester.pump();

      // Flip the due card, then double-tap the same rating tile.
      await tester.tap(find.text('Cat'));
      await tester.pump();
      final good = find.text('جيد');
      expect(good, findsOneWidget);
      await tester.tap(good);
      await tester.tap(good); // same frame — the defect window
      await tester.pump();

      expect(st.cardsReviewed, 1, reason: 'one rating, not two');
      expect(st.xp, 1);
      await st.flush(); // settle the debounced-save timer
    });
  });

  group('H-1: pronunciation screen first frame', () {
    testWidgets('opens without LateInitializationError', (tester) async {
      _usePhoneSurface(tester);
      final st = await _state();
      await tester.pumpWidget(
          _harness(st, const PronunciationScreen(initialWord: 'Dog')));
      // The first frame used to throw here (build read the late field).
      expect(tester.takeException(), isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      // The requested word is resolved and rendered.
      expect(find.text('Dog'), findsWidgets);
    });
  });

  group('P-1: dictionary search regression', () {
    testWidgets('memoized search still returns correct results',
        (tester) async {
      _usePhoneSurface(tester);
      final st = await _state();
      await tester.pumpWidget(_harness(st, const DictionaryScreen()));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Dog');
      await tester.pump();
      // The search field itself also carries the typed text, so assert on
      // the RESULT COUNT line + the absence of the other words.
      expect(find.text('Cat'), findsNothing);
      expect(find.text('Bird'), findsNothing);
      expect(find.textContaining('1 '), findsWidgets); // '1 كلمة'

      // Back to the full bank.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Cat'), findsOneWidget);
      expect(find.text('Bird'), findsOneWidget);
    });
  });
}
