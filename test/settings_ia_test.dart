// Settings IA tests (v5.15, plan F3.5).
//
// Acceptance: every EXISTING settings key keeps working (display-only
// reorganization), the four sections are present, and the search finds a
// setting by its title within one interaction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/l10n.dart';
import 'package:masar_al_lugha/scope.dart';
import 'package:masar_al_lugha/screens/settings.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/services/tts.dart';

import 'fake_notifications.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final st = AppState();
  await st.load();
  return st;
}

Widget _harness(AppState st) => AppScope(
      state: st,
      tts: TtsService(),
      reminders: ReminderService(FakeNotificationApi()),
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  group('settings IA (F3.5)', () {
    testWidgets('the four titled sections are all present', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st));
      await tester.pump();

      expect(find.text(L.t('ar', 'setSectionProfiles')), findsOneWidget);
      expect(find.text(L.t('ar', 'setSectionLearning')), findsOneWidget);
      // Sections 3-4 sit below the fold in the default test surface —
      // scroll down to them.
      await tester.scrollUntilVisible(
        find.text(L.t('ar', 'setSectionAppearance')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(L.t('ar', 'setSectionAppearance')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(L.t('ar', 'setSectionData')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(L.t('ar', 'setSectionData')), findsOneWidget);
    });

    testWidgets('search narrows to the matching section(s)', (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st));
      await tester.pump();

      // Type the reminder section's title — only the Learning section
      // matches; the others hide.
      await tester.enterText(
          find.byType(TextField), L.t('ar', 'reminderSection'));
      await tester.pump();

      expect(find.text(L.t('ar', 'setSectionLearning')), findsOneWidget);
      expect(find.text(L.t('ar', 'reminderEnable')), findsOneWidget);
      // Non-matching sections are gone from the tree (still one screen
      // away — clearing the box brings them back).
      expect(find.text(L.t('ar', 'setSectionProfiles')), findsNothing);
      expect(find.text(L.t('ar', 'setSectionData')), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text(L.t('ar', 'setSectionProfiles')), findsOneWidget);
    });

    testWidgets('NEW a11y switches exist and flip state safely',
        (tester) async {
      final st = await _state();
      await tester.pumpWidget(_harness(st));
      await tester.pump();

      // Both switches live in the Appearance section — scroll to them.
      await tester.scrollUntilVisible(
        find.text(L.t('ar', 'simplifiedAudio')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(L.t('ar', 'simplifiedAudio')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(L.t('ar', 'largerText')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(L.t('ar', 'largerText')), findsOneWidget);

      await tester.tap(find.text(L.t('ar', 'simplifiedAudio')));
      await tester.pump();
      expect(st.simplifiedAudio, isTrue);
      await tester.tap(find.text(L.t('ar', 'largerText')));
      await tester.pump();
      expect(st.largerText, isTrue);
    });

    test('zero semantic key changes: old keys persist with same defaults',
        () async {
      final st = await _state();
      // Every pre-v5.15 default survives untouched.
      expect(st.darkMode, isFalse);
      expect(st.reduceMotion, isFalse);
      expect(st.ttsEnabled, isTrue);
      expect(st.retentionTarget, 0.9);
      expect(st.simplifiedAudio, isFalse, reason: 'additive, off by default');
      expect(st.largerText, isFalse, reason: 'additive, off by default');
    });
  });
}
