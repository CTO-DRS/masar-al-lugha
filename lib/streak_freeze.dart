// Streak freeze + daily-reminder logic for Masar Al-Lugha (v5.12, plan
// feature F2.5).
//
// STREAK FREEZE — the honest version: a freeze is EARNED by consistency
// (one token per 7 consecutive active days, stored up to 2) and SPENT
// automatically to bridge exactly ONE missed day. A freeze never revives a
// dead streak, never covers multi-day absences, and never grants XP for a
// day that was not studied — it only protects the streak counter.
//
// REMINDER CLOCK — pure decision helpers for the local daily reminder:
// computing the next fire time and whether a (re)schedule is needed. The
// actual notification plumbing lives in lib/services/notifications.dart
// behind an interface, so this logic is unit-testable with a fake.
//
// Both engines are Flutter-free and unit-tested (test/streak_freeze_test.dart).

class StreakFreeze {
  StreakFreeze._();

  /// Maximum freeze tokens a learner can hold.
  static const int maxFreezes = 2;

  /// One token per this many consecutive active days.
  static const int awardEveryDays = 7;

  /// Milestone number the streak has reached (1 at day 7, 2 at day 14…).
  static int milestoneCount(int streak) => streak ~/ awardEveryDays;

  /// Whether a token should be stored NOW: a new milestone was reached
  /// AND there is room. When the wallet is full the milestone is NOT
  /// consumed — it is deferred, so the next free slot collects it.
  static bool shouldAward({
    required int streak,
    required int lastAwardMark,
    required int freezes,
  }) =>
      freezes < maxFreezes && milestoneCount(streak) > lastAwardMark;

  /// Tokens held after storing one.
  static int afterAward(int freezes) => (freezes + 1).clamp(0, maxFreezes);

  /// Award mark to persist after granting the milestone.
  static int markAfter(int streak) => milestoneCount(streak);

  /// Whether a single missed day ([gapDays] = calendar days between the
  /// last active day and today, minus the active days themselves) can be
  /// bridged with one token. Only exactly-one-missed-day gaps qualify.
  static bool canBridge({
    required int freezes,
    required int missedDays,
  }) =>
      freezes > 0 && missedDays == 1;

  /// Tokens left after bridging one missed day.
  static int afterBridge(int freezes) => (freezes - 1).clamp(0, maxFreezes);
}

/// Pure reminder-clock math. Local wall-clock time is intentional: a
/// "remind me at 20:00" habit means the user's LOCAL 20:00, every day.
class ReminderClock {
  ReminderClock._();

  /// The next epoch-ms strictly AFTER [now] at local [hour]:[:minute].
  /// If today's slot already passed (or is this exact millisecond), the
  /// next fire is tomorrow at the same local time.
  static int nextFireEpochMs(DateTime now, int hour, int minute) {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    var next = DateTime(now.year, now.month, now.day, h, m);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.millisecondsSinceEpoch;
  }

  /// Whether the stored schedule differs from what the notifier currently
  /// holds — used to avoid redundant rescheduling on every app start.
  static bool needsReschedule({
    required bool enabled,
    required int scheduledHour,
    required int scheduledMinute,
    required bool scheduledActive,
  }) =>
      enabled != scheduledActive;
}

/// Immutable reminder preferences (persisted in the settings block).
class ReminderSettings {
  final bool enabled;
  final int hour; // local 0..23
  final int minute; // 0..59

  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'hour': hour, 'minute': minute};

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        // Type-checked (not just null-checked): a hand-tampered payload
        // must fall back to safe defaults, never crash the loader.
        enabled: (j['enabled'] is bool) ? j['enabled'] as bool : false,
        hour: ((j['hour'] as num?)?.toInt() ?? 20).clamp(0, 23),
        minute: ((j['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      );
}
