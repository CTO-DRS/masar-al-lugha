// Storage-layer tests (v4.0, Wave 3): prove the SharedPreferences JSON
// profile scales to the heaviest plausible profile (~3,000 SRS cards) with
// correct round-trip fidelity — the measurement cited in docs/ARCHITECTURE.md §2.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/profile_store.dart';

CardData _card(int i) => CardData(
      ease: 2.3 + (i % 10) / 20,
      intervalDays: i % 90,
      dueEpochMs: 1700000000000 + i * 60000,
      reps: i % 30,
      lapses: i % 4,
      state: i % 3 == 0 ? 'review' : 'learning',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('3,000-card profile round-trips losslessly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    for (var i = 0; i < 3000; i++) {
      st.cards['stress_w$i'] = _card(i);
      if (i % 5 == 0) st.wordMistakes['stress_w$i'] = i % 7;
      if (i % 11 == 0) st.lessonStars['stress_l$i'] = (i % 3) + 1;
    }

    final sw = Stopwatch()..start();
    await st.save();
    final encodeMs = sw.elapsedMilliseconds;

    final st2 = AppState();
    sw
      ..reset()
      ..start();
    await st2.load();
    final decodeMs = sw.elapsedMilliseconds;

    // Fidelity: every card survives with identical fields.
    expect(st2.cards.length, 3000);
    for (var i = 0; i < 3000; i++) {
      final a = st.cards['stress_w$i']!;
      final b = st2.cards['stress_w$i']!;
      expect(b.ease, a.ease, reason: 'ease mismatch at $i');
      expect(b.intervalDays, a.intervalDays, reason: 'interval mismatch at $i');
      expect(b.dueEpochMs, a.dueEpochMs, reason: 'due mismatch at $i');
      expect(b.reps, a.reps, reason: 'reps mismatch at $i');
      expect(b.lapses, a.lapses, reason: 'lapses mismatch at $i');
      expect(b.state, a.state, reason: 'state mismatch at $i');
    }
    expect(st2.lessonStars.length, st.lessonStars.length);
    expect(st2.wordMistakes.length, st.wordMistakes.length);

    // Budget: encode+decode of the heaviest profile stays far below a frame
    // budget on the order of tens of milliseconds — the claim made in
    // ARCHITECTURE.md §2 ("single-digit to low-tens of milliseconds").
    // Generous CI headroom: 150 ms per direction.
    expect(encodeMs, lessThan(150), reason: 'save() too slow for 3000 cards');
    expect(decodeMs, lessThan(150), reason: 'load() too slow for 3000 cards');
  });

  test('profile JSON size stays in the hundreds-of-KB range at 3,000 cards',
      () async {
    final st = AppState();
    for (var i = 0; i < 3000; i++) {
      st.cards['stress_w$i'] = _card(i);
    }
    final encoded = jsonEncode(st.cards.map((k, v) => MapEntry(k, v.toJson())));
    // ARCHITECTURE.md §2 claims ~350 KB — assert well under 1 MB (the
    // documented re-evaluation threshold for switching to SQLite).
    expect(encoded.length, lessThan(1 << 20));
    expect(
        encoded.length, greaterThan(100 << 10)); // sanity: really ~3000 cards
  });

  // Phase-3 round 2 (migration reality check): the v1->v2 payload migration
  // in ProfileStore._migrateSchema was previously untested — these feed REAL
  // old-shape payloads through the real load() path and prove no data loss.
  test('pre-4.0 payload (no schema key) migrates losslessly to schema 2',
      () async {
    // A realistic pre-4.0 progress blob: no 'schema' key (defaults to v1),
    // no lessonStars, no FSRS d/s/last fields on cards, none of the v5.x
    // additive containers (insights/errorKinds/lapseLog/...).
    const v1Payload = <String, dynamic>{
      'xp': 123,
      'streak': 4,
      'dailyGoal': 20,
      'cards': <String, dynamic>{
        'en_u1_w1': <String, dynamic>{
          'ease': 2.5,
          'ivl': 3,
          'due': 1700000000000,
          'reps': 2,
          'lapses': 0,
          'state': 'review',
        },
        'en_u1_w2': <String, dynamic>{
          'ease': 2.3,
          'ivl': 0,
          'due': 1700000100000,
          'reps': 1,
          'lapses': 1,
          'state': 'learning',
        },
      },
      'wordMistakes': <String, dynamic>{'en_u1_w2': 2},
    };
    SharedPreferences.setMockInitialValues(
        <String, Object>{'progress_json_v1': jsonEncode(v1Payload)});

    final st = AppState();
    await st.load(); // must not throw on the old shape
    expect(st.xp, 123, reason: 'xp must survive the migration');
    expect(st.streak, 4, reason: 'streak must survive the migration');
    expect(st.cards.length, 2, reason: 'both v1 cards must survive');
    expect(st.cards['en_u1_w1']!.intervalDays, 3);
    expect(st.cards['en_u1_w1']!.ease, 2.5);
    expect(st.cards['en_u1_w2']!.lapses, 1);
    expect(st.wordMistakes['en_u1_w2'], 2);
    expect(st.lessonStars, isEmpty,
        reason: 'v1 payload has no lessonStars — migration must default it');

    // Saved back at the CURRENT schema with the same data.
    await st.save();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('progress_json_v1')!)
        as Map<String, dynamic>;
    expect(saved['schema'], ProfileStore.progressSchema,
        reason: 'save() must stamp the current schema version');

    // Round-trip through the migrated shape stays lossless.
    final st2 = AppState();
    await st2.load();
    expect(st2.xp, 123);
    expect(st2.streak, 4);
    expect(st2.cards.length, 2);
    expect(st2.cards['en_u1_w1']!.intervalDays, 3);
    expect(st2.wordMistakes['en_u1_w2'], 2);
  });

  test('minimal old payload (schema: 1, nothing else) loads with safe defaults',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'progress_json_v1': jsonEncode(<String, dynamic>{'schema': 1})
    });
    final st = AppState();
    await st.load(); // must not throw
    expect(st.xp, 0);
    expect(st.streak, 0);
    expect(st.cards, isEmpty);
    expect(st.lessonStars, isEmpty);
    expect(st.dailyGoal, 20,
        reason: 'default daily goal applies on old payloads');
  });
}
