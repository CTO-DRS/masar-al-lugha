// Records engine tests (v4.8) — all-time record computation, weekly XP
// window boundaries, the new profile counters (bestStreak / bestDayXp /
// activeDays) across simulated days, persistence + export/import round
// trips, old-payload compatibility and the record-broken mascot priority.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/mascot.dart';
import 'package:masar_al_lugha/records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('records engine', () {
    test('compute emits every record in display order', () {
      final r = Records.compute(
        bestStreak: 12,
        streak: 5,
        xp: 2340,
        bestDayXp: 130,
        activeDays: 41,
        lessonsCompleted: 88,
        perfectLessons: 23,
        starsTotal: 214,
        wordsMastered: 510,
        cardsReviewed: 1902,
        accuracyPct: 93,
        customWords: 36,
        favorites: 12,
        badges: 9,
      );
      expect(r.length, 14);
      expect(r.map((e) => e.key).toList(), [
        'bestStreak',
        'streak',
        'xp',
        'bestDayXp',
        'activeDays',
        'lessons',
        'perfectLessons',
        'stars',
        'words',
        'cards',
        'accuracy',
        'customWords',
        'favorites',
        'badges',
      ]);
      expect(r.map((e) => e.value).toList(),
          [12, 5, 2340, 130, 41, 88, 23, 214, 510, 1902, 93, 36, 12, 9]);
    });

    test('dayKey matches the yyyy-MM-dd zero-padded convention', () {
      expect(Records.dayKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(Records.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('weeklyXp windows: 7 days ending today vs the 7 before', () {
      final today = DateTime(2026, 10, 24); // a Saturday
      final log = {
        '2026-10-24': 10, // this week (today)
        '2026-10-18': 20, // this week (6 days ago — first window day)
        '2026-10-17': 40, // last week (7 days ago — first old-window day)
        '2026-10-14': 5, // last week
        '2026-10-11': 80, // last week (13 days ago — last old-window day)
        '2026-10-10': 160, // outside both windows
        '2026-10-25': 320, // future — never counted
      };
      final w = Records.weeklyXp(log, today);
      expect(w.thisWeek, 30);
      expect(w.lastWeek, 125);
      expect(w.delta, -95);
    });

    test('weeklyXp handles empty logs and identical weeks', () {
      final today = DateTime(2026, 10, 24);
      final empty = Records.weeklyXp({}, today);
      expect(empty.thisWeek, 0);
      expect(empty.lastWeek, 0);
      expect(empty.delta, 0);
      final even = Records.weeklyXp({'2026-10-20': 7, '2026-10-13': 7}, today);
      expect(even.delta, 0);
    });
  });

  group('profile record counters', () {
    test('addXp bumps bestDayXp within a day without extra active days',
        () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState();
      st.addXp(15);
      expect(st.streak, 1);
      expect(st.bestStreak, 1);
      expect(st.activeDays, 1);
      expect(st.bestDayXp, 15);
      st.addXp(20);
      expect(st.streak, 1); // same day — no double bump
      expect(st.bestStreak, 1);
      expect(st.activeDays, 1);
      expect(st.bestDayXp, 35);
    });

    test('consecutive day extends streak, record and active days', () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState();
      st.addXp(10);
      st.lastActiveDay = AppState.yesterdayKey(); // simulate next day
      st.addXp(10);
      expect(st.streak, 2);
      expect(st.bestStreak, 2);
      expect(st.activeDays, 2);
    });

    test('gap day resets streak but keeps bestStreak and counts the day',
        () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState();
      st.addXp(10);
      st.lastActiveDay = AppState.yesterdayKey();
      st.addXp(10); // streak 2
      // Simulate a 3-day gap directly with the same day-key convention.
      final gapDay = DateTime.now().subtract(const Duration(days: 3));
      st.lastActiveDay =
          '${gapDay.year.toString().padLeft(4, '0')}-${gapDay.month.toString().padLeft(2, '0')}-${gapDay.day.toString().padLeft(2, '0')}';
      st.addXp(5);
      expect(st.streak, 1); // reset
      expect(st.bestStreak, 2); // all-time kept
      expect(st.activeDays, 3);
    });

    test('completeLesson also feeds the records (streak + active day)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState();
      st.completeLesson('en_l1', mistakes: 0, vocabCount: 4);
      expect(st.streak, 1);
      expect(st.bestStreak, 1);
      expect(st.activeDays, 1);
      expect(st.lessonStars['en_l1'], 3);
    });

    test('save/load round trip preserves the record counters', () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState();
      await st.load();
      st.addXp(30);
      st.lastActiveDay = AppState.yesterdayKey();
      st.addXp(12); // streak 2
      await st.store.flush();
      final st2 = AppState();
      await st2.load();
      expect(st2.bestStreak, 2);
      expect(st2.bestDayXp, 42);
      expect(st2.activeDays, 2);
      expect(st2.xp, 42);
    });

    test('export/import round trip preserves the record counters', () async {
      SharedPreferences.setMockInitialValues({});
      final src = AppState();
      src.addXp(60);
      src.lastActiveDay = AppState.yesterdayKey();
      src.addXp(30); // streak 2, day XP 90
      final payload = src.exportProfileJson();

      SharedPreferences.setMockInitialValues({});
      final dst = AppState();
      final err = await dst.importProfileJson(payload);
      expect(err, isNull);
      expect(dst.bestStreak, 2);
      expect(dst.bestDayXp, 90);
      expect(dst.activeDays, 2);
    });

    test('old payloads without record keys load as zeros', () async {
      final v1 = jsonEncode({
        'xp': 120,
        'streak': 4,
        'dailyGoal': 30,
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'progress_json_v1': v1,
      });
      final st = AppState();
      await st.load();
      expect(st.xp, 120);
      expect(st.bestStreak, 0);
      expect(st.bestDayXp, 0);
      expect(st.activeDays, 0);
    });
  });

  group('record-broken mascot event', () {
    MascotFacts f() => const MascotFacts(
        xp: 100, streak: 2, lessons: 3, level: 2, accuracy: 90, missedDays: 0);

    test('a fresh record beats a level-up', () {
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonGood,
          leveledUp: true,
          streakBefore: 2,
          streakAfter: 2,
          brokeRecord: true,
        ),
        MascotEvent.recordBroken,
      );
    });

    test('a streak milestone still outranks a record', () {
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonPerfect,
          leveledUp: true,
          streakBefore: 6,
          streakAfter: 7,
          brokeRecord: true,
        ),
        MascotEvent.streakMilestone,
      );
    });

    test('without a record the priority chain is unchanged', () {
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonGreat,
          leveledUp: true,
          streakBefore: 2,
          streakAfter: 2,
        ),
        MascotEvent.levelUp,
      );
      expect(
        MascotEngine.resultEvent(
          lessonQuality: MascotEvent.lessonGreat,
          leveledUp: false,
          streakBefore: 2,
          streakAfter: 2,
        ),
        MascotEvent.lessonGreat,
      );
    });

    test('recordBroken renders as a celebration with 6 bilingual lines', () {
      expect(
          MascotEngine.moodFor(MascotEvent.recordBroken), MascotMood.celebrate);
      final bank = mascotLineCatalog[MascotEvent.recordBroken]!;
      expect(bank.length, 6);
      for (final (ar, en) in bank) {
        expect(ar.isNotEmpty, true);
        expect(en.isNotEmpty, true);
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(ar), true, reason: ar);
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(en), false, reason: en);
      }
      // deterministic rotation like every other event
      final out = <String>{};
      for (var i = 0; i < bank.length; i++) {
        out.add(
            MascotEngine.lineFor(MascotEvent.recordBroken, f(), 'ar', salt: i));
      }
      expect(out.length, bank.length);
    });
  });
}
