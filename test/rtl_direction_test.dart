// v4.12.1 — RTL/LTR direction safety: target-language content must lay out
// in its OWN script direction inside the Arabic RTL shell. Before this fix
// the build (arrange) exercise inherited the UI's RTL and rendered English
// sentences reversed ("Good morning" -> "morning | Good"), the exact bug
// users report from other learning apps too. Urdu (Arabic-script) must keep
// flowing RTL — so the rule is per-content, not a blanket LTR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/theme.dart';

void main() {
  group('directionOf — first strong character (v4.12.1)', () {
    test('Latin words and sentences are LTR', () {
      expect(directionOf('Good morning'), TextDirection.ltr);
      expect(directionOf('Where are you from?'), TextDirection.ltr);
      expect(directionOf('Cat'), TextDirection.ltr);
      // French accented letters are still Latin (Latin-1 supplement).
      expect(directionOf('Ça va très bien'), TextDirection.ltr);
      // v5.0: German umlauts and ß live in the extended-Latin range —
      // the fourth course keeps reading LTR.
      expect(directionOf('Grüße'), TextDirection.ltr);
      expect(directionOf('Wo ist der Bahnhof?'), TextDirection.ltr);
    });

    test('Arabic-script sentences are RTL (Urdu course included)', () {
      expect(directionOf('السلام علیکم'), TextDirection.rtl); // Urdu
      expect(directionOf('آپ کیسے ہیں؟'), TextDirection.rtl); // Urdu question
      expect(directionOf('مرحبا'), TextDirection.rtl); // Arabic
    });

    test('neutral characters are skipped — the first STRONG char decides', () {
      expect(directionOf('______ morning'), TextDirection.ltr,
          reason: 'cloze blank marker is neutral');
      expect(directionOf('______ مرحبا'), TextDirection.rtl);
      expect(directionOf('123 مرحبا'), TextDirection.rtl,
          reason: 'digits are neutral');
      expect(directionOf('🎓 Cat'), TextDirection.ltr,
          reason: 'emoji is neutral');
    });

    test('no strong character defaults to LTR', () {
      expect(directionOf(''), TextDirection.ltr);
      expect(directionOf('123 456'), TextDirection.ltr);
      expect(directionOf('___ 🎨'), TextDirection.ltr);
    });

    test('build tiles resolve the direction of the sentence they compose', () {
      // Exactly what _buildBody passes to ScriptDirection.
      expect(directionOf(['Good', 'morning'].join(' ')), TextDirection.ltr);
      expect(directionOf(['آپ', 'کیسے', 'ہیں؟'].join(' ')), TextDirection.rtl);
      // Letter builds (single Latin word) are LTR too.
      expect(directionOf(['C', 'a', 't'].join(' ')), TextDirection.ltr);
    });
  });

  group('ScriptDirection widget (v4.12.1)', () {
    testWidgets('English build tiles lay out LTR inside the RTL shell',
        (tester) async {
      await tester.pumpWidget(const Directionality(
        // The Arabic-first UI shell — what MaterialApp gives uiLocale=ar.
        textDirection: TextDirection.rtl,
        child: ScriptDirection(
          text: 'Good morning',
          child: SizedBox(width: 10, height: 10),
        ),
      ));
      final ctx = tester.element(find.byType(SizedBox));
      expect(Directionality.of(ctx), TextDirection.ltr,
          reason: 'the sentence the learner builds must read Good | morning');
    });

    testWidgets('Urdu build tiles keep flowing RTL inside the same shell',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: ScriptDirection(
          text: 'آپ کیسے ہیں؟',
          child: SizedBox(width: 10, height: 10),
        ),
      ));
      final ctx = tester.element(find.byType(SizedBox));
      expect(Directionality.of(ctx), TextDirection.rtl,
          reason: 'Urdu course must keep its natural direction');
    });
  });

  group('OptionCard direction (v4.12.1)', () {
    testWidgets('English sentence options lay out LTR inside RTL shell',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: buildMasarTheme(dark: false),
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: OptionCard(text: 'Where are you from?'),
            ),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('Where are you from?'));
      expect(text.textDirection, TextDirection.ltr);
    });

    testWidgets('Arabic meaning options stay RTL', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: buildMasarTheme(dark: false),
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: OptionCard(text: 'من أين أنت؟'),
            ),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('من أين أنت؟'));
      expect(text.textDirection, TextDirection.rtl);
    });
  });
}
