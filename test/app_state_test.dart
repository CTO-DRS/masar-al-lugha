// AppState persistence tests (v4.0, MASTER PROMPT Wave 3):
// - schema v1 -> v2 migration through the real load() path
// - corrupt-JSON recovery keeps a restorable backup (audit H2)
// - save/load round-trip preserves settings and progress
// - debounced scheduleSave + flush actually persists (audit M3)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/profile_store.dart';

const _kProgress = 'progress_json_v1';
const _kBackup = 'progress_backup_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 payload (no schema field) loads and is upgraded on save', () async {
    final v1 = jsonEncode({
      // NOTE: intentionally missing 'schema' — pre-4.0 payload shape.
      'xp': 120,
      'streak': 4,
      'dailyGoal': 30,
      'lessonStars': {'en_l1': 3},
      'cards': {
        'en_w1': {
          'ease': 2.6,
          'ivl': 3,
          'due': 1700000000000,
          'reps': 2,
          'lapses': 0,
          'state': 'review'
        },
      },
      'badges': ['first_lesson'],
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      _kProgress: v1,
      'onboarding_done': true,
    });

    final st = AppState();
    await st.load();

    expect(st.xp, 120);
    expect(st.streak, 4);
    expect(st.dailyGoal, 30);
    expect(st.lessonStars['en_l1'], 3);
    expect(st.cards['en_w1']!.ease, 2.6);
    expect(st.cards['en_w1']!.intervalDays, 3);
    expect(st.badges, contains('first_lesson'));

    await st.save();
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString(_kProgress)!) as Map<String, dynamic>;
    expect(saved['schema'], AppState.progressSchema); // upgraded marker
  });

  test('v2 payload round-trips settings and engine state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    st.darkMode = true;
    st.reduceMotion = true;
    st.ttsEnabled = false;
    st.ttsRate = 1.3;
    st.dailyGoal = 50;
    st.wordMistakes['en_w9'] = 3;
    st.placementDone['fr'] = true;
    st.placementSkip['fr'] = 12;
    st.newCardsToday = 7;
    st.newCardsDay = AppState.todayKey();
    await st.save();

    final st2 = AppState();
    await st2.load();
    expect(st2.darkMode, isTrue);
    expect(st2.reduceMotion, isTrue);
    expect(st2.ttsEnabled, isFalse);
    expect(st2.ttsRate, 1.3);
    expect(st2.dailyGoal, 50);
    expect(st2.wordMistakes['en_w9'], 3);
    expect(st2.placementDone['fr'], isTrue);
    expect(st2.placementSkip['fr'], 12);
    expect(st2.newCardsToday, 7);
  });

  test('corrupt JSON does not crash and is backed up before reset (H2)',
      () async {
    const corrupt = '{"xp": 55, "cards": { NOT VALID JSON';
    SharedPreferences.setMockInitialValues(
        <String, Object>{_kProgress: corrupt});

    final st = AppState();
    await st.load(); // must not throw

    expect(st.loaded, isTrue);
    expect(st.xp, 0); // fresh start, no partial state

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_kBackup), corrupt); // recoverable copy kept
  });

  test('scheduleSave marks dirty; flush persists and clears dirty (M3)',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    st.xp = 42;
    st.scheduleSave();
    expect(st.dirty, isTrue);

    // Nothing persisted before flush (timer has not fired inside test time).
    await st.flush();
    expect(st.dirty, isFalse);

    final st2 = AppState();
    await st2.load();
    expect(st2.xp, 42);
  });

  test('streak extends on consecutive days (v4.0.1 fix)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    // Simulate: the learner was active yesterday with streak = 1.
    st.lastActiveDay = AppState.yesterdayKey();
    st.streak = 1;

    st.addXp(10);
    expect(st.streak, 2); // consecutive day extends the streak

    // Same-day activity must NOT double-increment.
    st.addXp(5);
    expect(st.streak, 2);

    await st.flush(); // addXp now uses the debounced save (v4.0.1 M4)
  });

  test('streak restarts at 1 after a missed day (v4.0.1 HIGH fix)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    // Simulate a stale profile: last active long ago, daily state also stale,
    // so _ensureDaily() takes the gap branch at the next activity.
    st.lastActiveDay = '2020-01-01';
    st.dailyXpDay = '2020-01-01';
    st.streak = 9;

    st.addXp(10);
    expect(st.streak, 1); // gap breaks the streak, new streak starts

    await st.flush();
  });

  test('streak earns the streak_3 badge once it reaches 3 days', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    st.lastActiveDay = AppState.yesterdayKey();
    st.streak = 2;
    st.addXp(1);
    expect(st.streak, 3);
    expect(st.badges, contains('streak_3'));

    await st.flush();
  });

  test('v4.1: AppState delegates persistence to ProfileStore (same keys)',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final st = AppState();
    await st.load();

    // Dirty flag is mirrored from the store through the same public API.
    st.xp = 7;
    expect(st.dirty, isFalse);
    st.scheduleSave();
    expect(st.dirty, isTrue);
    expect(st.store.dirty, isTrue);

    // Round-trip through the extracted store keeps the on-disk shape:
    // same progress key, schema marker, and settings blob.
    await st.flush();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('progress_json_v1');
    expect(raw, isNotNull);
    final j = jsonDecode(raw!) as Map<String, dynamic>;
    expect(j['schema'], ProfileStore.progressSchema);
    expect(j['settings'], isA<Map>());

    final st2 = AppState();
    await st2.load();
    expect(st2.xp, 7);
    expect(st2.dirty, isFalse);
  });
}
