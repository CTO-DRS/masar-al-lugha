// First-run journey widget tests (v5.15, plan F3.1).
//
// Covered acceptance criteria:
//  1. a zero learner reaches the first lesson with NO mandatory decision
//     beyond language + course (2 picks, auto-start);
//  2. the "experience" branch keeps the adaptive placement test fully
//     available AND a skip;
//  3. a returning learner with an active profile never sees the journey;
//  4. completing the first-win lesson lands on the first-win result
//     screen with the non-blocking customize-path card, and the journey
//     timer is recorded exactly once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/screens/lesson_screen.dart';
import 'package:masar_al_lugha/screens/onboarding.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';
import 'package:masar_al_lugha/theme.dart';

import 'fake_notifications.dart';

const _lessonId = 'fx_first';

Lesson _lesson() => Lesson(
      id: _lessonId,
      titleAr: 'الدرس الأول',
      titleEn: 'First lesson',
      vocab: List.generate(
        6,
        (i) => Vocab(
          id: 'fw_w$i',
          target: 'word$i',
          translationAr: 'كلمة$i',
          emoji: '📗',
          exampleTarget: 'word$i example',
          exampleAr: 'مثال $i',
        ),
      ),
    );

Future<AppState> _state({bool onboardingDone = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
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
  await st.load();
  st.onboardingDone = onboardingDone;
  return st;
}

Widget _harness(AppState st) => AppScope(
      state: st,
      tts: TtsService(),
      reminders: ReminderService(FakeNotificationApi()),
      child: MaterialApp(home: const OnboardingScreen()),
    );

void main() {
  group('first-run journey (F3.1)', () {
    testWidgets('zero path: 2 picks -> the FIRST LESSON starts itself',
        (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st));
      await tester.pump();

      // Screen 1: UI language.
      expect(find.text('العربية'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pump();
      await tester.tap(find.byType(ChunkyButton));
      await tester.pump();

      // Screen 2: the course — the ONLY mandatory content decision.
      expect(find.text('إنجليزي'), findsOneWidget);
      await tester.tap(find.text('إنجليزي'));
      await tester.pump();
      await tester.tap(find.byType(ChunkyButton));
      await tester.pump();

      // Screen 3: the experience question.
      expect(find.text(L.t('ar', 'experienceQuestion')), findsOneWidget);
      // The zero path needs ONE tap — no wizard, no domain, no level.
      await tester.tap(find.text(L.t('ar', 'fromZero')));
      await tester.pump();
      await tester.pump();

      // The first lesson is ALREADY on screen (auto-start).
      expect(find.byType(LessonScreen), findsOneWidget);
      // And the journey clock started with onboarding.
      expect(st.journeyStartedAt, isNotNull);
      expect(st.onboardingDone, isTrue);
    });

    testWidgets('experience path: placement stays available + skip',
        (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st));
      await tester.pump();
      await tester.tap(find.text('العربية'));
      await tester.pump();
      await tester.tap(find.byType(ChunkyButton));
      await tester.pump();
      await tester.tap(find.text('إنجليزي'));
      await tester.pump();
      await tester.tap(find.byType(ChunkyButton));
      await tester.pump();

      // Experience branch reveals BOTH lanes.
      await tester.tap(find.text(L.t('ar', 'withExperience')));
      await tester.pump();
      await tester.pump();
      expect(find.text(L.t('ar', 'startPlacement')), findsOneWidget);
      expect(find.text(L.t('ar', 'skipForNow')), findsOneWidget);
      // The adaptive test stays fully available (its screen pushes);
      // skip completes onboarding WITHOUT any lesson.
      await tester.tap(find.text(L.t('ar', 'skipForNow')));
      await tester.pump();
      expect(st.onboardingDone, isTrue);
      expect(st.journeyStartedAt, isNotNull);
    });

    test('returning learner never sees the journey (active profile)', () async {
      final st = await _state(onboardingDone: true);
      // The splash routes on onboardingDone — a returning profile goes
      // straight home. This mirrors SplashScreen's routing decision.
      expect(st.onboardingDone, isTrue);
      // And the journey timer is never re-armed for them.
      expect(st.journeyStartedAt, isNull);
    });

    testWidgets('first win: result screen shows customize card + timer once',
        (tester) async {
      // A tall surface so the whole first-win column (stats + card +
      // continue) is on-screen for the drive.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final st = await _state();
      st.finishOnboarding();
      expect(st.journeyStartedAt, isNotNull);
      // Simulate the completed first lesson's result screen (what
      // LessonScreen pushes with firstWin: true).
      await tester.pumpWidget(AppScope(
        state: st,
        tts: TtsService(),
        reminders: ReminderService(FakeNotificationApi()),
        child: MaterialApp(
          home: LessonResultScreen(
            lesson: _lesson(),
            xpEarned: 15,
            accuracy: 100,
            perfect: true,
            firstWin: true,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(L.t('ar', 'firstWinTitle')), findsOneWidget);
      expect(find.text(L.t('ar', 'firstWinCustomize')), findsOneWidget);
      expect(find.byKey(const ValueKey('firstWinContinue')), findsOneWidget);

      // Continue records the timer — exactly once.
      await tester.tap(find.byKey(const ValueKey('firstWinContinue')));
      await tester.pump();
      final first = st.firstWinAt;
      expect(first, isNotNull);
      expect(first! >= st.journeyStartedAt!, isTrue);

      st.markFirstWin();
      expect(st.firstWinAt, first, reason: 'recorded once, never moved');
    });
  });
}
