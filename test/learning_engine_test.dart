// Learning-engine integration tests (v5.12, plan features F2.1-F2.5).
//
// Everything here runs against the real AppState with mocked
// SharedPreferences — the same fixture pattern as systems_test.dart — so
// the hooks (calibration logging, lapse recording, freeze bridge/award)
// are exercised exactly where the UI hits them.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/app_state.dart';
import 'package:masar_al_lugha/calibration.dart';
import 'package:masar_al_lugha/mastery.dart';
import 'package:masar_al_lugha/models.dart';
import 'package:masar_al_lugha/remediation.dart';
import 'package:masar_al_lugha/srs.dart';
import 'package:masar_al_lugha/streak_freeze.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course _course(String id, List<String> words) {
  return Course(
    id: id,
    nameAr: 'دورة $id',
    nameEn: 'Course $id',
    flag: '🌍',
    ttsLang: 'en-US',
    units: [
      Unit(
        id: '${id}_u_1',
        titleAr: 'وحدة 1',
        titleEn: 'Unit 1',
        colorHex: '#58CC02',
        lessons: [
          Lesson(
            id: '${id}_l_1',
            titleAr: 'درس 1',
            titleEn: 'Lesson 1',
            vocab: words
                .map((w) => Vocab(id: w, target: w, translationAr: 'معنى $w'))
                .toList(),
          ),
        ],
      ),
    ],
  );
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  test('calibration: brand-new cards never produce samples', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1']);
    await st.load();
    st.rateCard('w1', Srs.good);
    expect(st.calibrationLog, isEmpty);
  });

  test('calibration: seen-card ratings record prediction and outcome',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1']);
    await st.load();
    st.rateCard('w1', Srs.good); // first encounter → no sample
    st.rateCard('w1', Srs.good); // seen → sample, recalled
    expect(st.calibrationLog, hasLength(1));
    expect(st.calibrationLog.last[1], 1);
    st.rateCard('w1', Srs.again); // seen → lapsed
    expect(st.calibrationLog, hasLength(2));
    expect(st.calibrationLog.last[1], 0);
    // Samples stay within the documented bounds.
    expect(st.calibrationLog.last[0], inInclusiveRange(0, 1000));
  });

  test('calibration: lesson results log real outcomes for seen words',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1', 'w2', 'w3']);
    await st.load();
    // Seed the SRS state for w2/w3 with one lesson pass.
    st.applyLessonResults({'w2': true, 'w3': true});
    final before = st.calibrationLog.length;
    expect(before, 0, reason: 'first encounters carry no prediction');
    // A later lesson re-tests all three: w1 first time, w2 right, w3 wrong.
    st.applyLessonResults({'w1': true, 'w2': true, 'w3': false});
    expect(st.calibrationLog.length, before + 2,
        reason: 'w2 (recalled) and w3 (lapsed) are honest datapoints');
    expect(st.calibrationLog.last, [st.calibrationLog.last[0], 0]);
    final report = Calibration.report(st.calibrationLog);
    expect(report.total, 2);
  });

  test('remediation: lapsing a seen word on two days surfaces it', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1', 'w2']);
    await st.load();
    st.applyLessonResults({'w1': true, 'w2': true}); // both enter SRS
    st.rateCard('w1', Srs.again); // lapse day 1
    expect(st.remediationVocab(st.course), isEmpty,
        reason: 'a single lapse day is not a trap yet');
    // A second "day" — simulated by back-dating today's event and
    // lapsing again (the engine itself is window-tested in its own file).
    final today = Remediation.epochDay(DateTime.now());
    st.lapseLog['w1'] = [today - 2, today];
    expect(st.remediationVocab(st.course).map((v) => v.id).toList(), ['w1']);
  });

  test('freeze: one missed day is bridged and the token is spent', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.streak = 5;
    st.streakFreezes = 1;
    st.lastActiveDay =
        _dayKey(DateTime.now().subtract(const Duration(days: 2)));
    st.dailyXpDay = 'stale'; // force ensureDaily to roll
    st.ensureDaily();
    expect(st.streak, 5, reason: 'the freeze protected the streak');
    expect(st.streakFreezes, 0);
    expect(st.lastActiveDay, AppState.yesterdayKey());
    // Studying today extends the chain naturally.
    st.addXp(10);
    expect(st.streak, 6);
  });

  test('freeze: without a token a missed day still resets the streak',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.streak = 5;
    st.streakFreezes = 0;
    st.lastActiveDay =
        _dayKey(DateTime.now().subtract(const Duration(days: 2)));
    st.dailyXpDay = 'stale';
    st.ensureDaily();
    expect(st.streak, 0);
  });

  test('freeze: multi-day gaps are never bridged', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.streak = 5;
    st.streakFreezes = 2;
    st.lastActiveDay =
        _dayKey(DateTime.now().subtract(const Duration(days: 3)));
    st.dailyXpDay = 'stale';
    st.ensureDaily();
    expect(st.streak, 0);
    expect(st.streakFreezes, 2, reason: 'nothing was spent on a dead cause');
  });

  test('freeze: the bridge consumes exactly one token per missed day',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.streak = 5;
    st.streakFreezes = 2;
    st.lastActiveDay =
        _dayKey(DateTime.now().subtract(const Duration(days: 2)));
    st.dailyXpDay = 'stale';
    st.ensureDaily();
    st.ensureDaily(); // second roll on the same day must be a no-op
    expect(st.streakFreezes, 1);
  });

  test('freeze: tokens are earned at 7-day milestones and capped at 2',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.dailyXpDay = AppState.todayKey(); // avoid daily-roll interference
    // Walk the streak to 7 across "consecutive" days.
    st.streak = 6;
    st.lastActiveDay = AppState.yesterdayKey();
    st.addXp(5);
    expect(st.streak, 7);
    expect(st.streakFreezes, 1);
    expect(st.lastFreezeAwardMark, 1);
    // Another week → second token.
    st.streak = 13;
    st.lastActiveDay = AppState.yesterdayKey();
    st.addXp(5);
    expect(st.streak, 14);
    expect(st.streakFreezes, 2);
    // A full wallet defers the milestone instead of wasting it.
    st.streak = 20;
    st.lastActiveDay = AppState.yesterdayKey();
    st.addXp(5);
    expect(st.streak, 21);
    expect(st.streakFreezes, 2);
    expect(st.lastFreezeAwardMark, 2);
  });

  test('missedDaysSince: the arithmetic the bridge depends on', () {
    final today = DateTime(2026, 3, 15);
    expect(
        AppState.missedDaysSince(
            _dayKey(today.subtract(const Duration(days: 1))), _dayKey(today)),
        0,
        reason: 'active yesterday → nothing missed');
    expect(
        AppState.missedDaysSince(
            _dayKey(today.subtract(const Duration(days: 2))), _dayKey(today)),
        1,
        reason: 'yesterday skipped → one missed day');
    expect(
        AppState.missedDaysSince(
            _dayKey(today.subtract(const Duration(days: 4))), _dayKey(today)),
        3);
    expect(AppState.missedDaysSince('garbage', _dayKey(today)), 99);
  });

  test('reminders: setReminders clamps and persists across reload', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    await st.load();
    st.setReminders(const ReminderSettings(enabled: true, hour: 7, minute: 45));
    expect(st.reminders.enabled, isTrue);
    st.setReminders(
        const ReminderSettings(enabled: true, hour: 90, minute: -4));
    expect(st.reminders.hour, 23);
    expect(st.reminders.minute, 0);

    await st.save();
    final st2 = AppState();
    await st2.load();
    expect(st2.reminders.enabled, isTrue);
    expect(st2.reminders.hour, 23);
  });

  test('persistence: the new v5.12 fields survive a save/load roundtrip',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1', 'w2']);
    await st.load();
    st.streak = 9;
    st.streakFreezes = 2;
    st.lastFreezeAwardMark = 1;
    st.rateCard('w1', Srs.good);
    st.rateCard('w1', Srs.again); // calibration sample + lapse event
    // Two distinct lapse days (one back-dated) make w1 a true target.
    final today = Remediation.epochDay(DateTime.now());
    st.lapseLog['w1'] = [today - 2, today];
    st.lapseLog['w2'] = [today];
    await st.save();

    final st2 = AppState();
    st2.courses['en'] = _course('en', ['w1', 'w2']);
    await st2.load();
    expect(st2.streak, 9);
    expect(st2.streakFreezes, 2);
    expect(st2.lastFreezeAwardMark, 1);
    expect(st2.calibrationLog, st.calibrationLog);
    expect(st2.lapseLog['w1'], isNotNull);
    expect(st2.lapseLog['w2'], isNotNull);
    // The restored lapse log still drives the same remediation lane.
    expect(st2.remediationVocab(st2.course).map((v) => v.id).toList(), ['w1']);
  });

  test('persistence: old payloads without v5.12 keys load unchanged', () async {
    // A v5.11-shaped payload (no calibration/lapse/freeze keys) must keep
    // loading with the additive defaults.
    SharedPreferences.setMockInitialValues({
      'progress_json_v1': '{"schema":2,"xp":42,"streak":3,"cards":{}}',
    });
    final st = AppState();
    await st.load();
    expect(st.xp, 42);
    expect(st.streak, 3);
    expect(st.streakFreezes, 0);
    expect(st.calibrationLog, isEmpty);
    expect(st.lapseLog, isEmpty);
    expect(st.reminders.enabled, isFalse);
  });

  test('mastery: AppState exposes the per-course summary', () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1', 'w2']);
    await st.load();
    st.rateCard('w1', Srs.good);
    final sum = st.masterySummary(st.course);
    expect(sum.total, 2);
    expect(sum.averagePct, greaterThan(0));
    expect(st.masteryOf('w1'), greaterThan(0));
    expect(st.masteryOf('never-seen'), 0);
  });

  test('v5.18: masteryStateCounts carries all six keys and sums to total',
      () async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState();
    st.courses['en'] = _course('en', ['w1', 'w2', 'w3']);
    await st.load();
    st.rateCard('w1', Srs.good);
    final counts = st.masteryStateCounts(st.course);
    expect(counts.length, 6, reason: 'all six state keys, even at zero');
    expect(counts.values.fold<int>(0, (a, b) => a + b), 3,
        reason: 'every course word lands in exactly one state');
    expect(counts[Mastery.stateMasteryConsolidating], 1,
        reason: 'a first good rating graduates to the review schedule '
            '(consolidating until the score proves more)');
    expect(counts[Mastery.stateMasteryLearning], 0,
        reason: 'learning state is only for again/hard first steps');
    expect(counts[Mastery.stateMasteryNew], 2,
        reason: 'unseen words are new, never fake-progressed');
  });
}
