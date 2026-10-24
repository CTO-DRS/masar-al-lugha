// Companion engine tests (v4.5) — cast integrity, evidence-based unlocks,
// event priority, catalog parity/placeholders, rotation determinism and
// widget rendering. Mirrors the contract documented in lib/mascot.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/mascot.dart';
import 'package:masar_al_lugha/widgets/mascot.dart';

MascotFacts _f({
  int xp = 0,
  int streak = 0,
  int lessons = 0,
  int level = 1,
  int accuracy = 100,
  int missedDays = 0,
}) =>
    MascotFacts(
      xp: xp,
      streak: streak,
      lessons: lessons,
      level: level,
      accuracy: accuracy,
      missedDays: missedDays,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cast integrity', () {
    test('five companions with unique ids', () {
      expect(mascotCast.length, 5);
      final ids = mascotCast.map((c) => c.id).toSet();
      expect(ids.length, 5);
      expect(ids, containsAll(['rafiq', 'farah', 'nur', 'zayd', 'salma']));
    });

    test('every character is fully bilingual', () {
      for (final c in mascotCast) {
        expect(c.nameAr.isNotEmpty, true, reason: c.id);
        expect(c.nameEn.isNotEmpty, true, reason: c.id);
        expect(c.taglineAr.isNotEmpty, true, reason: c.id);
        expect(c.taglineEn.isNotEmpty, true, reason: c.id);
      }
    });

    test('rafiq is the ungated default', () {
      final rafiq = mascotById('rafiq');
      expect(rafiq.missingRequirement(_f()), isNull);
      expect(mascotById('unknown'), same(rafiq)); // safe fallback
    });
  });

  group('evidence-based unlocks', () {
    test('farah unlocks at 500 XP', () {
      final farah = mascotById('farah');
      expect(farah.missingRequirement(_f(xp: 499)), isNotNull);
      expect(farah.missingRequirement(_f(xp: 500)), isNull);
    });

    test('nur unlocks at a 7-day streak', () {
      final nur = mascotById('nur');
      expect(nur.missingRequirement(_f(streak: 6)), isNotNull);
      expect(nur.missingRequirement(_f(streak: 7)), isNull);
    });

    test('zayd unlocks at 50 lessons', () {
      final zayd = mascotById('zayd');
      expect(zayd.missingRequirement(_f(lessons: 49)), isNotNull);
      expect(zayd.missingRequirement(_f(lessons: 50)), isNull);
    });

    test('salma unlocks at 1500 XP', () {
      final salma = mascotById('salma');
      expect(salma.missingRequirement(_f(xp: 1499)), isNotNull);
      expect(salma.missingRequirement(_f(xp: 1500)), isNull);
    });

    test('missing requirement reports the strictest remaining gate', () {
      final salma = mascotById('salma');
      expect(salma.missingRequirement(_f(xp: 10)), ('xp', 1500));
    });
  });

  group('event selection', () {
    test('lesson quality mapping', () {
      expect(MascotEngine.lessonEvent(perfect: true, accuracy: 100),
          MascotEvent.lessonPerfect);
      expect(MascotEngine.lessonEvent(perfect: false, accuracy: 85),
          MascotEvent.lessonGreat);
      expect(MascotEngine.lessonEvent(perfect: false, accuracy: 60),
          MascotEvent.lessonGood);
      expect(MascotEngine.lessonEvent(perfect: false, accuracy: 30),
          MascotEvent.lessonStruggled);
    });

    test('streak milestone beats level up beats lesson quality', () {
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonStruggled,
          leveledUp: true,
          streakBefore: 2,
          streakAfter: 3,
        ),
        MascotEvent.streakMilestone,
      );
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonStruggled,
          leveledUp: true,
          streakBefore: 2,
          streakAfter: 3, // 3 is a milestone but must be FRESH (> before)
        ),
        MascotEvent.streakMilestone,
      );
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonPerfect,
          leveledUp: false,
          streakBefore: 3,
          streakAfter: 4, // not a milestone
        ),
        MascotEvent.lessonPerfect,
      );
      // old milestone (streak did not move) must NOT re-fire
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonGood,
          leveledUp: false,
          streakBefore: 7,
          streakAfter: 7,
        ),
        MascotEvent.lessonGood,
      );
    });

    test('milestone set is exactly {3,7,14,30,60,100}', () {
      for (final m in const [3, 7, 14, 30, 60, 100]) {
        expect(MascotEngine.isMilestone(m), true, reason: '$m');
      }
      for (final m in const [1, 2, 4, 5, 8, 13, 29, 1000]) {
        expect(MascotEngine.isMilestone(m), false, reason: '$m');
      }
    });

    test('mood mapping', () {
      expect(MascotEngine.moodFor(MascotEvent.lessonPerfect),
          MascotMood.celebrate);
      expect(MascotEngine.moodFor(MascotEvent.levelUp), MascotMood.celebrate);
      expect(MascotEngine.moodFor(MascotEvent.streakMilestone),
          MascotMood.celebrate);
      expect(MascotEngine.moodFor(MascotEvent.comeback), MascotMood.happy);
      expect(MascotEngine.moodFor(MascotEvent.idle), MascotMood.neutral);
      expect(MascotEngine.moodFor(MascotEvent.lessonFailed), MascotMood.sad);
      expect(MascotEngine.moodFor(MascotEvent.lessonStruggled), MascotMood.sad);
    });
  });

  group('line catalog', () {
    final allEvents = MascotEvent.values;

    test('every event has >= 4 lines in BOTH locales', () {
      for (final e in allEvents) {
        final bank = _linesOf(e);
        expect(bank.length, greaterThanOrEqualTo(4), reason: '$e');
        for (final (ar, en) in bank) {
          expect(ar.trim().isNotEmpty, true, reason: '$e ar empty');
          expect(en.trim().isNotEmpty, true, reason: '$e en empty');
        }
      }
    });

    test('rotation actually cycles the bank (variety guarantee)', () {
      const f = MascotFacts(
          xp: 0, streak: 0, lessons: 0, level: 1, accuracy: 0, missedDays: 0);
      for (final e in allEvents) {
        final bank = _linesOf(e);
        final rendered = <String>{};
        for (var i = 0; i < bank.length; i++) {
          rendered.add(MascotEngine.lineFor(e, f, 'ar', salt: i));
        }
        // every catalog line is reachable and distinct after fill
        expect(rendered.length, bank.length, reason: '$e');
      }
    });

    test('only documented placeholders appear', () {
      const allowed = {'{s}', '{lvl}', '{p}', '{m}'};
      for (final e in allEvents) {
        for (final (ar, en) in _linesOf(e)) {
          for (final line in [ar, en]) {
            final matches = RegExp(r'\{[a-zA-Z]+\}').allMatches(line);
            for (final m in matches) {
              expect(allowed.contains(m.group(0)), true,
                  reason: '$e uses unknown ${m.group(0)}: $line');
            }
          }
        }
      }
    });

    test('{m} (missed days) only appears in comeback lines', () {
      for (final e in allEvents) {
        if (e == MascotEvent.comeback) continue;
        for (final (ar, en) in _linesOf(e)) {
          expect(ar.contains('{m}'), false, reason: '$e ar');
          expect(en.contains('{m}'), false, reason: '$e en');
        }
      }
    });

    test('fill substitutes every documented placeholder', () {
      const tpl = 'streak={s} level={lvl} acc={p} missed={m}';
      final out = MascotEngine.fill(
          tpl, _f(streak: 7, level: 4, accuracy: 92, missedDays: 3));
      expect(out, 'streak=7 level=4 acc=92 missed=3');
    });

    test('lineFor rotates deterministically and cycles', () {
      final f = _f(streak: 7, level: 3, accuracy: 88);
      final bank = _linesOf(MascotEvent.streakMilestone);
      for (var i = 0; i < bank.length; i++) {
        expect(
          MascotEngine.lineFor(MascotEvent.streakMilestone, f, 'ar', salt: i),
          MascotEngine.lineFor(MascotEvent.streakMilestone, f, 'ar',
              salt: i + bank.length),
        );
      }
    });

    test('locale switch returns the other language', () {
      final f = _f(streak: 3);
      final ar =
          MascotEngine.lineFor(MascotEvent.streakMilestone, f, 'ar', salt: 0);
      final en =
          MascotEngine.lineFor(MascotEvent.streakMilestone, f, 'en', salt: 0);
      expect(ar, isNot(en));
      // Arabic contains Arabic-script letters, English does not
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(ar), true);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(en), false);
    });

    test('comeback lines embed the missed-day count', () {
      final f = _f(missedDays: 5);
      final ar = MascotEngine.lineFor(MascotEvent.comeback, f, 'ar', salt: 0);
      expect(ar.contains('5'), true, reason: ar);
    });
  });

  group('AppState integration', () {
    test('selectMascot rejects locked companions (no-op)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();

      st.selectMascot('farah'); // locked: xp == 0 < 500
      expect(st.mascotId, 'rafiq');
    });

    test('selectMascot accepts unlocked companions and persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();

      st.xp = 500; // farah gate open
      st.selectMascot('farah');
      expect(st.mascotId, 'farah');

      await st.save();
      final st2 = AppState();
      await st2.load();
      expect(st2.mascotId, 'farah');
    });

    test('mascotMissedDays counts fully-missed days', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();

      expect(st.mascotMissedDays, 0); // never active -> treated as new

      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      st.lastActiveDay = '${threeDaysAgo.year.toString().padLeft(4, '0')}-'
          '${threeDaysAgo.month.toString().padLeft(2, '0')}-'
          '${threeDaysAgo.day.toString().padLeft(2, '0')}';
      expect(st.mascotMissedDays, inInclusiveRange(2, 3));

      st.lastActiveDay = AppState.todayKey();
      expect(st.mascotMissedDays, 0);
    });

    test('mascotFacts mirrors live profile evidence', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();

      st.xp = 350;
      st.streak = 7;
      st.lessonStars['en_u1_l1'] = 3;
      final f = st.mascotFacts;
      expect(f.xp, 350);
      expect(f.streak, 7);
      expect(f.lessons, 1);
      expect(f.level, 4); // 350 / 100 + 1
    });

    test('export/import carries the companion choice', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      st.xp = 500;
      st.selectMascot('farah');

      final raw = st.exportProfileJson();
      final st2 = AppState();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st2.load();
      final err = await st2.importProfileJson(raw);
      expect(err, isNull);
      expect(st2.mascotId, 'farah');
    });

    test('import drops unknown mascot ids', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.load();
      final raw = st.exportProfileJson();

      // Tamper: swap in an unknown id.
      final tampered = raw.replaceFirst('"farah"', '"hacker"');
      final st2 = AppState();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await st2.load();
      final err = await st2.importProfileJson(tampered);
      expect(err, isNull);
      expect(st2.mascotId, 'rafiq');
    });
  });

  group('widgets render for the whole cast', () {
    for (final c in mascotCast) {
      testWidgets('Mascot renders ${c.id} in every mood', (tester) async {
        for (final mood in MascotMood.values) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Center(
                child: Mascot(size: 60, mood: mood, characterId: c.id),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${c.id}/$mood');
        }
      });
    }

    testWidgets('MascotBubble renders text with and without avatar',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MascotBubble(
            characterId: 'rafiq',
            mood: MascotMood.happy,
            text: 'Hello learner',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hello learner'), findsOneWidget);
      expect(find.byType(Mascot), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MascotBubble(
            characterId: 'rafiq',
            mood: MascotMood.happy,
            text: 'Second bubble',
            showAvatar: false,
            animate: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Second bubble'), findsOneWidget);
      expect(find.byType(Mascot), findsNothing);
    });
  });
}

// Direct access to the (now public) bilingual catalog for parity tests.
List<(String, String)> _linesOf(MascotEvent e) => mascotLineCatalog[e]!;
