// Local intelligence tests (v4.4):
// - insights engine rules (best hour, trend, goal suggestion, confusions,
//   review forecast, tutor tips) — pure Dart, deterministic via injected
//   DateTime anchors.
// - AppState capture: recordAnswer feeds hour buckets + answerLog,
//   recordConfusion normalizes pair keys and bounds the map, favorites
//   toggle per course, persistence round-trip through the real store.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/insights.dart';
import 'package:masar_al_lugha/models.dart';

CardData _card({required int dueInMs, int reps = 1}) {
  final c = CardData();
  c.dueEpochMs = DateTime.now().millisecondsSinceEpoch + dueInMs;
  c.reps = reps;
  c.state = 'review';
  return c;
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bestStudyHour', () {
    test('null when there is not enough data', () {
      final total = List<int>.filled(24, 0);
      final correct = List<int>.filled(24, 0);
      total[9] = 5; // below the 8-sample threshold
      correct[9] = 5;
      expect(Insights.bestStudyHour(total, correct), isNull);
    });

    test('picks the highest-accuracy busy hour', () {
      final total = List<int>.filled(24, 0);
      final correct = List<int>.filled(24, 0);
      total[8] = 10;
      correct[8] = 6; // 60%
      total[20] = 10;
      correct[20] = 9; // 90% -> winner
      total[23] = 12;
      correct[23] = 1; // busy but terrible
      expect(Insights.bestStudyHour(total, correct), 20);
    });

    test('accuracy tie goes to the busier bucket', () {
      final total = List<int>.filled(24, 0);
      final correct = List<int>.filled(24, 0);
      total[7] = 8;
      correct[7] = 8; // 100% with 8
      total[21] = 12;
      correct[21] = 12; // 100% with 12 -> wins
      expect(Insights.bestStudyHour(total, correct), 21);
    });
  });

  group('accuracyTrend / trendDelta', () {
    test('returns per-day percentages oldest-first and skips idle days', () {
      final now = DateTime(2026, 10, 20, 15);
      final log = <String, List<int>>{
        _dayKey(now): [4, 3], // 75%
        _dayKey(now.subtract(const Duration(days: 2))): [10, 5], // 50%
      };
      final trend = Insights.accuracyTrend(log, days: 7, now: now);
      expect(trend.length, 2);
      expect(trend[0].$2, 50); // two days ago comes first
      expect(trend[1].$2, 75); // today last
      expect(trend[0].$1, _dayKey(now.subtract(const Duration(days: 2))));
    });

    test('trendDelta needs evidence on both halves', () {
      final now = DateTime(2026, 10, 20, 15);
      expect(Insights.trendDelta({}, now: now), isNull);
      final log = <String, List<int>>{};
      // recent 3 days: 100 answers all correct; previous 3: 100 answers 50%
      for (var i = 0; i < 3; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = [34, 34];
        log[_dayKey(now.subtract(Duration(days: i + 3)))] = [34, 17];
      }
      final d = Insights.trendDelta(log, now: now);
      expect(d, isNotNull);
      expect(d! >= 30, isTrue); // ~100% vs ~50%
    });
  });

  group('goalSuggestion', () {
    final now = DateTime(2026, 10, 20, 15);

    test('no data -> null', () {
      expect(
        Insights.goalSuggestion(currentGoal: 20, xpLog: {}, now: now),
        isNull,
      );
    });

    test('raises after a consistently overachieving week', () {
      final log = <String, int>{};
      // 6 of the last 7 days at 40+ XP with goal 20 (avg 40 >= 20+15)
      for (var i = 1; i <= 6; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = 40;
      }
      log[_dayKey(now.subtract(const Duration(days: 7)))] = 5;
      final s = Insights.goalSuggestion(currentGoal: 20, xpLog: log, now: now);
      expect(s, isNotNull);
      expect(s!.newGoal, 25);
      expect(s.reasonKey, 'goalRaiseReason');
      expect(s.params['met'], '6');
      expect(s.params['avg'], '40');
    });

    test('never raises past the cap', () {
      final log = <String, int>{};
      for (var i = 1; i <= 6; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = 100;
      }
      final s = Insights.goalSuggestion(
          currentGoal: 58, xpLog: log, now: now, maxGoal: 60);
      expect(s, isNull); // 58+5 > 60 -> keep
    });

    test('lowers after a struggling week', () {
      final log = <String, int>{};
      for (var i = 1; i <= 4; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = 8; // active, under 20
      }
      final s = Insights.goalSuggestion(currentGoal: 20, xpLog: log, now: now);
      expect(s, isNotNull);
      expect(s!.newGoal, 15);
      expect(s.reasonKey, 'goalLowerReason');
      expect(s.params['miss'], '4');
    });

    test('never lowers below the floor', () {
      final log = <String, int>{};
      for (var i = 1; i <= 4; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = 3;
      }
      final s = Insights.goalSuggestion(
          currentGoal: 10, xpLog: log, now: now, minGoal: 10);
      expect(s, isNull);
    });
  });

  group('confusion pairs', () {
    test('confusionKey is direction-independent', () {
      expect(Insights.confusionKey('b', 'a'), 'a|b');
      expect(Insights.confusionKey('a', 'b'), 'a|b');
    });

    test('topConfusions sorts and parses', () {
      final raw = {'a|b': 2, 'c|d': 5, 'e|f': 1, 'bad-key': 9};
      final top = Insights.topConfusions(raw, limit: 2);
      expect(top.length, 2);
      expect(top[0].vocabIdA, 'c');
      expect(top[0].vocabIdB, 'd');
      expect(top[0].count, 5);
      expect(top[1].key, 'a|b');
    });
  });

  group('review forecast', () {
    test('counts everything due by the horizon (overdue included)', () {
      final cards = <String, CardData>{
        'a': _card(dueInMs: -Insights.dayMs), // overdue
        'b': _card(dueInMs: 0),
        'c': _card(dueInMs: 12 * 3600 * 1000), // within 1 day
        'd': _card(dueInMs: 3 * Insights.dayMs), // beyond
      };
      expect(Insights.dueWithinDays(cards, 1), 3);
      expect(Insights.dueWithinDays(cards, 3), 4);
    });
  });

  group('tutorTips', () {
    Vocab v(String id) =>
        Vocab(id: id, target: 't-$id', translationAr: 'm-$id', emoji: 'x$id');

    test('emits confusion tip only after enough evidence, with word texts', () {
      final byId = {
        for (final id in ['w1', 'w2']) id: v(id)
      };
      final tips = Insights.tutorTips(
        confusionPairs: {Insights.confusionKey('w1', 'w2'): 2},
        vocabById: byId,
        hourTotal: List.filled(24, 0),
        hourCorrect: List.filled(24, 0),
        cards: {},
        streak: 0,
        todayXp: 0,
        dailyGoal: 20,
        answerLog: {},
      );
      expect(tips, isEmpty); // count 2 < threshold 3

      final tips2 = Insights.tutorTips(
        confusionPairs: {Insights.confusionKey('w1', 'w2'): 4},
        vocabById: byId,
        hourTotal: List.filled(24, 0),
        hourCorrect: List.filled(24, 0),
        cards: {},
        streak: 0,
        todayXp: 0,
        dailyGoal: 20,
        answerLog: {},
      );
      expect(tips2.first.key, 'tipConfusion');
      expect(tips2.first.params['a'], 't-w1');
      expect(tips2.first.params['b'], 't-w2');
      expect(tips2.first.params['n'], '4');
    });

    test('streak guard + review wave fire under the right conditions', () {
      final tips = Insights.tutorTips(
        confusionPairs: {},
        vocabById: {},
        hourTotal: List.filled(24, 0),
        hourCorrect: List.filled(24, 0),
        cards: {'x': _card(dueInMs: 5 * 3600 * 1000)}, // due tomorrow
        streak: 6,
        todayXp: 5,
        dailyGoal: 20,
        answerLog: {},
      );
      final keys = tips.map((t) => t.key).toList();
      expect(keys, contains('tipStreakGuard'));
      expect(keys, isNot(contains('tipReviewWave'))); // 1 card < 8 threshold

      final guard = tips.firstWhere((t) => t.key == 'tipStreakGuard');
      expect(guard.params['streak'], '6');
      expect(guard.params['left'], '15');
    });

    test('caps the number of tips', () {
      final byId = {
        for (final id in ['w1', 'w2']) id: v(id)
      };
      final total = List<int>.filled(24, 0);
      final correct = List<int>.filled(24, 0);
      total[9] = 20;
      correct[9] = 19;
      final now = DateTime(2026, 10, 20, 15);
      final log = <String, List<int>>{};
      for (var i = 0; i < 3; i++) {
        log[_dayKey(now.subtract(Duration(days: i)))] = [40, 40];
        log[_dayKey(now.subtract(Duration(days: i + 3)))] = [40, 10];
      }
      final cards = <String, CardData>{
        for (var i = 0; i < 10; i++) 'c$i': _card(dueInMs: 3600 * 1000),
      };
      final tips = Insights.tutorTips(
        confusionPairs: {Insights.confusionKey('w1', 'w2'): 9},
        vocabById: byId,
        hourTotal: total,
        hourCorrect: correct,
        cards: cards,
        streak: 4,
        todayXp: 2,
        dailyGoal: 30,
        answerLog: log,
        now: now,
      );
      expect(tips.length, 4); // maxTips default
      expect(
          tips.map((t) => t.key), containsAll(['tipConfusion', 'tipBestHour']));
    });
  });

  group('AppState capture (v4.4)', () {
    test('recordAnswer fills hour buckets and the daily accuracy log', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.recordAnswer(true);
      st.recordAnswer(true);
      st.recordAnswer(false);
      final h = DateTime.now().hour;
      expect(st.hourTotal[h], 3);
      expect(st.hourCorrect[h], 2);
      expect(st.answerLog[AppState.todayKey()]![0], 3);
      expect(st.answerLog[AppState.todayKey()]![1], 2);
      expect(st.totalAnswers, 3);
      expect(st.correctAnswers, 2);
    });

    test('recordConfusion normalizes direction and ignores self-pairs', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.recordConfusion('en_w2', 'en_w1');
      st.recordConfusion('en_w1', 'en_w2'); // same pair, other direction
      st.recordConfusion('en_w1', 'en_w1'); // ignored
      expect(st.confusionPairs.length, 1);
      expect(st.confusionPairs['en_w1|en_w2'], 2);
    });

    test('confusion map stays bounded (top pairs kept)', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      // The pair below gets the HIGHEST count, so the bounded trim (keep
      // top 40 when the map exceeds 60) must never evict it.
      for (var i = 0; i < 5; i++) {
        st.recordConfusion('a0', 'b0');
      }
      for (var i = 0; i < 65; i++) {
        st.recordConfusion('a$i', 'z$i');
      }
      expect(st.confusionPairs.length, lessThanOrEqualTo(60));
      expect(st.confusionPairs['a0|b0'], 5);
    });

    test('favorites toggle is per course and resolves stale ids safely',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.courseId = 'en';
      st.toggleFavorite('en_w1');
      st.toggleFavorite('en_w2');
      st.toggleFavorite('en_w1'); // removed again
      expect(st.isFavorite('en_w1'), isFalse);
      expect(st.isFavorite('en_w2'), isTrue);
      expect(st.favorites['en'], ['en_w2']);

      // Resolve against a synthetic course: 'en_w2' survives, 'ghost' is
      // silently dropped (removed content / foreign profile import).
      final course = Course(
        id: 'en',
        nameAr: '',
        nameEn: '',
        flag: '',
        ttsLang: 'en-US',
        units: [
          Unit(
            id: 'u1',
            titleAr: '',
            titleEn: '',
            colorHex: '#58CC02',
            lessons: [
              Lesson(
                id: 'l1',
                titleAr: '',
                titleEn: '',
                vocab: [
                  Vocab(id: 'en_w2', target: 'word', translationAr: 'كلمة')
                ],
              ),
            ],
          ),
        ],
      );
      final fav = st.favoriteVocab(course);
      expect(fav.map((v) => v.id), ['en_w2']);
    });

    test('insights + favorites survive the real save/load round-trip',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.recordConfusion('en_w2', 'en_w1');
      st.recordAnswer(true);
      st.toggleFavorite('en_w2');
      await st.save();

      final st2 = AppState();
      await st2.load();
      expect(st2.confusionPairs['en_w1|en_w2'], 1);
      expect(st2.hourTotal.fold<int>(0, (a, b) => a + b), 1);
      expect(st2.answerLog[AppState.todayKey()], [1, 1]);
      expect(st2.favorites['en'], ['en_w2']);
    });

    test('export/import carries insights + favorites', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      st.recordConfusion('en_w2', 'en_w1');
      st.toggleFavorite('en_w2');
      final exported = st.exportProfileJson();

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st2 = AppState();
      final err = await st2.importProfileJson(exported);
      expect(err, isNull);
      expect(st2.confusionPairs['en_w1|en_w2'], 1);
      expect(st2.favorites['en'], ['en_w2']);
    });

    test('import of an old v4.3 export (no insights keys) still works',
        () async {
      final legacy = jsonEncode({
        'app': 'masar-al-lugha',
        'exportVersion': 1,
        'progress': {
          'schema': 2,
          'xp': 55,
          'lessonStars': <String, int>{},
          'cards': <String, dynamic>{},
        },
      });
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      final err = await st.importProfileJson(legacy);
      expect(err, isNull);
      expect(st.xp, 55);
      expect(st.confusionPairs, isEmpty);
      expect(st.hourTotal.length, 24);
    });
  });

  // ================= v5.11: per-card smart memory hints ==================
  group('v5.11 memoryHint', () {
    CardData card({
      int lapses = 0,
      double difficulty = 5,
      double stability = 10,
      String state = 'review',
      int dueInDays = 1, // positive = still future
    }) {
      final c = CardData();
      c.lapses = lapses;
      c.difficulty = difficulty;
      c.stability = stability;
      c.state = state;
      c.reps = 3;
      c.dueEpochMs =
          DateTime.now().millisecondsSinceEpoch + dueInDays * Insights.dayMs;
      return c;
    }

    test('lapses >= 3 wins and carries the count', () {
      final t = Insights.memoryHint(card(lapses: 4))!;
      expect(t.key, 'hintLapses');
      expect(t.params['n'], '4');
    });

    test('high difficulty fires when there are no lapses', () {
      final t = Insights.memoryHint(card(difficulty: 8.1))!;
      expect(t.key, 'hintHard');
    });

    test('review card overdue by more than 3 days reports the days', () {
      final t = Insights.memoryHint(card(dueInDays: -5))!;
      expect(t.key, 'hintLate');
      expect(t.params['n'], '5');
    });

    test('overdue by exactly 3 days is NOT late — silence beats noise', () {
      expect(Insights.memoryHint(card(dueInDays: -3)), isNull);
    });

    test('young card (stability under 3 days) asks for one more day', () {
      final t = Insights.memoryHint(card(stability: 2))!;
      expect(t.key, 'hintYoung');
    });

    test('no rule fires on a healthy card', () {
      expect(Insights.memoryHint(card()), isNull);
    });

    test('a never-seen card gets no hint', () {
      final c = CardData(); // reps 0, no FSRS state
      expect(Insights.memoryHint(c), isNull);
    });

    test('precedence: lapses > difficulty > late > young', () {
      expect(Insights.memoryHint(card(lapses: 3, difficulty: 9))!.key,
          'hintLapses');
      expect(Insights.memoryHint(card(difficulty: 9, dueInDays: -9))!.key,
          'hintHard');
      expect(Insights.memoryHint(card(stability: 2, dueInDays: -9))!.key,
          'hintLate');
    });
  });

  // ================= v5.11: quick review queue ============================
  group('v5.11 quickReviewQueue', () {
    Vocab v(int i) => Vocab(id: 'en_w$i', target: 'w$i', translationAr: 'ك$i');

    CardData seenDue() => CardData()
      ..reps = 2
      ..dueEpochMs = DateTime.now().millisecondsSinceEpoch - 1000;

    test('drops unseen (reps 0 / no card) and not-yet-due cards', () {
      final pool = [v(1), v(2), v(3), v(4)];
      final cards = <String, CardData>{
        'en_w1': seenDue(), // in
        'en_w2': CardData()..reps = 0, // unseen → out
        'en_w3': CardData()
          ..reps = 2
          ..dueEpochMs =
              DateTime.now().millisecondsSinceEpoch + Insights.dayMs, // future
        // en_w4: no card at all → out
      };
      final q = Insights.quickReviewQueue(
          pool: pool, cards: cards, random: Random(1));
      expect(q.single.id, 'en_w1');
    });

    test('caps the queue and shuffles deterministically with a seed', () {
      final pool = [for (var i = 1; i <= 30; i++) v(i)];
      final cards = <String, CardData>{
        for (final w in pool) w.id: seenDue(),
      };
      final a = Insights.quickReviewQueue(
          pool: pool, cards: cards, random: Random(7));
      final b = Insights.quickReviewQueue(
          pool: pool, cards: cards, random: Random(7));
      expect(a.length, Insights.quickReviewCap);
      expect(a.map((e) => e.id).toList(), b.map((e) => e.id).toList());
      // and the full pool, uncapped, returns everything
      final all = Insights.quickReviewQueue(
          pool: pool, cards: cards, cap: 50, random: Random(7));
      expect(all.length, 30);
    });

    test('cap is clamped to at least 1', () {
      final pool = [v(1), v(2)];
      final cards = {
        'en_w1': seenDue(),
        'en_w2': seenDue(),
      };
      final q = Insights.quickReviewQueue(
          pool: pool, cards: cards, cap: 0, random: Random(1));
      expect(q.length, 1);
    });
  });
}
