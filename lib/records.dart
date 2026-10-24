// Records engine for Masar Al-Lugha (v4.8).
//
// All-time personal bests + weekly momentum, computed from the learner's
// own profile state — the same philosophy as lib/insights.dart: every
// number is derived from data that is already tracked, with the rule
// documented next to each record. No network, no accounts, no estimates.
//
// The engine is Flutter-free and unit-tested (test/records_test.dart).

/// One record row for the UI. The engine emits a stable [key]; the screen
/// maps key -> localized label + icon, keeping this file Flutter-free.
class RecordStat {
  final String key;
  final int value;

  const RecordStat(this.key, this.value);
}

/// Weekly XP comparison: the 7 days ending today vs the 7 days before.
class WeekXp {
  final int thisWeek;
  final int lastWeek;

  const WeekXp(this.thisWeek, this.lastWeek);

  /// Signed delta: positive = improving, negative = cooling down.
  int get delta => thisWeek - lastWeek;
}

class Records {
  static const int dayMs = 86400000;

  /// Day key in the exact [AppState.todayKey] convention (local date,
  /// zero-padded yyyy-MM-dd) so the engine reads the same xpLog buckets.
  static String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Sum of XP earned on the [days] calendar days starting at [from].
  static int _windowXp(Map<String, int> xpLog, DateTime from, int days) {
    var sum = 0;
    for (var i = 0; i < days; i++) {
      sum += xpLog[dayKey(DateTime(from.year, from.month, from.day + i))] ?? 0;
    }
    return sum;
  }

  /// Weekly momentum. This week = the 7 days ending today (inclusive),
  /// last week = the 7 days before that window. xpLog only retains 30
  /// days, which comfortably covers both windows.
  static WeekXp weeklyXp(Map<String, int> xpLog, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final thisWeek = _windowXp(xpLog, t.subtract(const Duration(days: 6)), 7);
    final lastWeek = _windowXp(xpLog, t.subtract(const Duration(days: 13)), 7);
    return WeekXp(thisWeek, lastWeek);
  }

  /// All-time records, ordered for display.
  ///
  /// Rule notes (where the value comes from):
  ///  - bestStreak / streak / bestDayXp / activeDays: dedicated profile
  ///    counters (v4.8) maintained by addXp/_bumpStreak.
  ///  - lessons: number of lessons with at least one completion.
  ///  - perfectLessons: lessons whose best run earned 3 stars.
  ///  - stars: total stars collected across all lessons (best run counts).
  ///  - words: vocab cards that reached the review state.
  ///  - accuracy: lifetime percentage, 0 when nothing answered yet.
  ///  - customWords: words the learner authored in "قوائمي" decks.
  ///  - favorites: starred dictionary words across all courses.
  ///  - badges: earned badge count.
  static List<RecordStat> compute({
    required int bestStreak,
    required int streak,
    required int xp,
    required int bestDayXp,
    required int activeDays,
    required int lessonsCompleted,
    required int perfectLessons,
    required int starsTotal,
    required int wordsMastered,
    required int cardsReviewed,
    required int accuracyPct,
    required int customWords,
    required int favorites,
    required int badges,
  }) =>
      [
        RecordStat('bestStreak', bestStreak),
        RecordStat('streak', streak),
        RecordStat('xp', xp),
        RecordStat('bestDayXp', bestDayXp),
        RecordStat('activeDays', activeDays),
        RecordStat('lessons', lessonsCompleted),
        RecordStat('perfectLessons', perfectLessons),
        RecordStat('stars', starsTotal),
        RecordStat('words', wordsMastered),
        RecordStat('cards', cardsReviewed),
        RecordStat('accuracy', accuracyPct),
        RecordStat('customWords', customWords),
        RecordStat('favorites', favorites),
        RecordStat('badges', badges),
      ];
}
