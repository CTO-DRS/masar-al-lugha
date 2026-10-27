// Streak freeze + reminder tests (v5.12, plan feature F2.5).
//
// The freeze must be honest (earned by consistency, spent on exactly one
// missed day, never reviving a dead streak) and the reminder clock must be
// predictable. The notification plumbing is tested through the seam with
// a fake — the plugin itself is never touched here.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/services/notifications.dart';
import 'package:masar_al_lugha/streak_freeze.dart';

import 'fake_notifications.dart';

void main() {
  group('StreakFreeze engine', () {
    test('milestone counting: 1 at day 7, 2 at day 14', () {
      expect(StreakFreeze.milestoneCount(6), 0);
      expect(StreakFreeze.milestoneCount(7), 1);
      expect(StreakFreeze.milestoneCount(13), 1);
      expect(StreakFreeze.milestoneCount(14), 2);
    });

    test('a token is stored only when a new milestone meets a free slot', () {
      expect(StreakFreeze.shouldAward(streak: 7, lastAwardMark: 0, freezes: 0),
          isTrue);
      expect(StreakFreeze.shouldAward(streak: 7, lastAwardMark: 1, freezes: 0),
          isFalse,
          reason: 'milestone already collected');
      expect(StreakFreeze.shouldAward(streak: 14, lastAwardMark: 1, freezes: 2),
          isFalse,
          reason: 'wallet full — milestone is deferred, not wasted');
      expect(StreakFreeze.shouldAward(streak: 21, lastAwardMark: 1, freezes: 1),
          isTrue);
    });

    test('bridging covers exactly one missed day', () {
      expect(StreakFreeze.canBridge(freezes: 1, missedDays: 1), isTrue);
      expect(StreakFreeze.canBridge(freezes: 0, missedDays: 1), isFalse);
      expect(StreakFreeze.canBridge(freezes: 2, missedDays: 2), isFalse,
          reason: 'a freeze never covers multi-day absences');
    });

    test('afterBridge spends one token and never goes negative', () {
      expect(StreakFreeze.afterBridge(2), 1);
      expect(StreakFreeze.afterBridge(0), 0);
    });
  });

  group('ReminderClock', () {
    test('a future slot today fires today', () {
      final now = DateTime(2026, 3, 15, 10, 30);
      final fire = DateTime.fromMillisecondsSinceEpoch(
          ReminderClock.nextFireEpochMs(now, 20, 0));
      expect(fire.day, 15);
      expect(fire.hour, 20);
      expect(fire.minute, 0);
    });

    test('a past slot rolls to tomorrow', () {
      final now = DateTime(2026, 3, 15, 22, 0);
      final fire = DateTime.fromMillisecondsSinceEpoch(
          ReminderClock.nextFireEpochMs(now, 20, 0));
      expect(fire.day, 16);
      expect(fire.hour, 20);
    });

    test('the exact same millisecond rolls to tomorrow', () {
      final now = DateTime(2026, 3, 15, 20, 0, 0, 1);
      final fire = DateTime.fromMillisecondsSinceEpoch(
          ReminderClock.nextFireEpochMs(now, 20, 0));
      expect(fire.day, 16);
    });

    test('hours and minutes are clamped to sane ranges', () {
      final now = DateTime(2026, 3, 15, 10, 0);
      final fire = DateTime.fromMillisecondsSinceEpoch(
          ReminderClock.nextFireEpochMs(now, 99, 99));
      expect(fire.hour, 23);
      expect(fire.minute, 59);
    });

    test('needsReschedule tracks the enabled state only', () {
      expect(
          ReminderClock.needsReschedule(
              enabled: true,
              scheduledHour: 0,
              scheduledMinute: 0,
              scheduledActive: false),
          isTrue);
      expect(
          ReminderClock.needsReschedule(
              enabled: true,
              scheduledHour: 0,
              scheduledMinute: 0,
              scheduledActive: true),
          isFalse);
      expect(
          ReminderClock.needsReschedule(
              enabled: false,
              scheduledHour: 0,
              scheduledMinute: 0,
              scheduledActive: false),
          isFalse);
    });
  });

  group('ReminderSettings', () {
    test('json roundtrip', () {
      const s = ReminderSettings(enabled: true, hour: 7, minute: 45);
      final back = ReminderSettings.fromJson(s.toJson());
      expect(back.enabled, isTrue);
      expect(back.hour, 7);
      expect(back.minute, 45);
    });

    test('malformed json falls back to safe defaults, clamped', () {
      final s = ReminderSettings.fromJson({
        'enabled': 'yes',
        'hour': 55,
        'minute': -3,
      });
      expect(s.enabled, isFalse);
      expect(s.hour, 23);
      expect(s.minute, 0);
    });
  });

  group('ReminderService (via fake api)', () {
    test('disabled + nothing active → no plugin calls at all', () async {
      final api = FakeNotificationApi();
      final svc = ReminderService(api);
      final ok = await svc.sync(
          settings: const ReminderSettings(enabled: false, hour: 20, minute: 0),
          title: 't',
          body: 'b');
      expect(ok, isTrue);
      expect(api.initCalled, isFalse);
      expect(api.scheduled, isEmpty);
      expect(api.cancelled, isEmpty);
    });

    test('enabling asks permission once, then schedules', () async {
      final api = FakeNotificationApi();
      final svc = ReminderService(api);
      final ok = await svc.sync(
          settings: const ReminderSettings(enabled: true, hour: 7, minute: 30),
          title: 'Practice',
          body: '5 minutes');
      expect(ok, isTrue);
      expect(api.permissionRequests, 1);
      expect(api.scheduled, hasLength(1));
      expect(api.scheduled.first.hour, 7);
      expect(api.scheduled.first.minute, 30);
      expect(api.scheduled.first.title, 'Practice');
      expect(svc.scheduledActive, isTrue);
    });

    test('denied permission → sync fails, nothing is scheduled', () async {
      final api = FakeNotificationApi()..permissionToGrant = false;
      final svc = ReminderService(api);
      final ok = await svc.sync(
          settings: const ReminderSettings(enabled: true, hour: 7, minute: 30),
          title: 't',
          body: 'b');
      expect(ok, isFalse);
      expect(api.scheduled, isEmpty);
      expect(svc.scheduledActive, isFalse);
    });

    test('disabling cancels exactly the daily reminder', () async {
      final api = FakeNotificationApi();
      final svc = ReminderService(api);
      await svc.sync(
          settings: const ReminderSettings(enabled: true, hour: 8, minute: 0),
          title: 't',
          body: 'b');
      await svc.sync(
          settings: const ReminderSettings(enabled: false, hour: 8, minute: 0),
          title: 't',
          body: 'b');
      expect(api.cancelled, [kDailyReminderId]);
      expect(svc.scheduledActive, isFalse);
    });

    test('cancel without an active schedule is a no-op', () async {
      final api = FakeNotificationApi();
      final svc = ReminderService(api);
      await svc.sync(
          settings: const ReminderSettings(enabled: false, hour: 8, minute: 0),
          title: 't',
          body: 'b');
      expect(api.cancelled, isEmpty);
    });
  });
}
