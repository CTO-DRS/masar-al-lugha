// Local intelligence engine for Masar Al-Lugha (v4.4).
//
// 100% on-device and rule-based: every insight below is derived from the
// learner's own progress log with an explainable rule (documented next to
// each function). No network, no accounts, no paid APIs — the MASTER
// PROMPT forbids them and this engine never needed one.
//
// The engine is Flutter-free and unit-tested (test/insights_test.dart).
import 'models.dart';

/// One confusion pair, normalized so [vocabIdA] < [vocabIdB] lexically —
/// the same two words always collapse into the same key.
class ConfusionPair {
  final String vocabIdA;
  final String vocabIdB;
  final int count;

  const ConfusionPair(this.vocabIdA, this.vocabIdB, this.count);

  String get key => '$vocabIdA|$vocabIdB';
}

/// A rule-based tutor tip. The engine only emits a l10n [key] plus display
/// [params]; the UI renders the localized template. Structured output keeps
/// the engine testable without any Flutter/l10n dependency.
class TutorTip {
  final String key;
  final Map<String, String> params;

  const TutorTip(this.key, this.params);
}

/// A smart daily-goal suggestion (rule + numbers, never silent magic).
class GoalSuggestion {
  final int newGoal;

  /// l10n key explaining WHY: 'goalRaiseReason' | 'goalLowerReason'.
  final String reasonKey;

  /// Numbers shown in the reason text (met/miss days, avg XP).
  final Map<String, String> params;

  const GoalSuggestion(this.newGoal, this.reasonKey, this.params);
}

class Insights {
  static const int dayMs = 86400000;

  // ================= best study hour =================

  /// The hour-of-day bucket where the learner performs best.
  ///
  /// Rule: among buckets with at least [minSamples] recorded answers, pick
  /// the highest accuracy; ties go to the busier bucket (more evidence).
  /// Returns null while there is not enough data — we never guess.
  static int? bestStudyHour(List<int> hourTotal, List<int> hourCorrect,
      {int minSamples = 8}) {
    int? best;
    double bestAcc = 0;
    int bestSamples = 0;
    for (var h = 0; h < 24 && h < hourTotal.length; h++) {
      final total = hourTotal[h];
      if (total < minSamples) continue;
      final correct = h < hourCorrect.length ? hourCorrect[h] : 0;
      final acc = correct / total;
      if (best == null ||
          acc > bestAcc ||
          (acc == bestAcc && total > bestSamples)) {
        best = h;
        bestAcc = acc;
        bestSamples = total;
      }
    }
    return best;
  }

  static double accuracyAt(List<int> hourTotal, List<int> hourCorrect, int h) {
    if (h < 0 || h >= hourTotal.length || hourTotal[h] == 0) return 0;
    final correct = h < hourCorrect.length ? hourCorrect[h] : 0;
    return correct / hourTotal[h];
  }

  // ================= accuracy trend =================

  /// Accuracy percentage per calendar day for the last [days] days
  /// (oldest first). Days without answers are skipped — the chart shows
  /// real activity only. [answerLog] maps dayKey -> [total, correct].
  static List<(String, int)> accuracyTrend(Map<String, List<int>> answerLog,
      {int days = 7, DateTime? now}) {
    final n = now ?? DateTime.now();
    final out = <(String, int)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = n.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final e = answerLog[key];
      if (e == null || e.length < 2 || e[0] == 0) continue;
      out.add((key, ((e[1] / e[0]) * 100).round()));
    }
    return out;
  }

  /// Mean accuracy of the last [k] active days vs the [k] before them.
  /// Returns null unless both halves have at least [minPerHalf] answers.
  /// Positive result = improving. Used by the trend tips.
  static int? trendDelta(Map<String, List<int>> answerLog,
      {int k = 3, int minPerHalf = 20, DateTime? now}) {
    final n = now ?? DateTime.now();
    int recentTotal = 0, recentCorrect = 0, prevTotal = 0, prevCorrect = 0;
    for (var i = 0; i < k * 2; i++) {
      final d = n.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final e = answerLog[key];
      if (e == null || e.length < 2) continue;
      if (i < k) {
        recentTotal += e[0];
        recentCorrect += e[1];
      } else {
        prevTotal += e[0];
        prevCorrect += e[1];
      }
    }
    if (recentTotal < minPerHalf || prevTotal < minPerHalf) return null;
    final a = ((recentCorrect / recentTotal) * 100).round();
    final b = ((prevCorrect / prevTotal) * 100).round();
    return a - b;
  }

  // ================= smart daily goal =================

  /// Suggest raising or lowering the daily goal, or null to keep it.
  ///
  /// Rules (explainable by design, derived from [xpLog] — dayKey -> XP):
  ///  - RAISE +5 (cap [maxGoal], default 60): goal met on >= 6 of the last
  ///    7 days AND average XP on those met days >= goal + 15 (comfort
  ///    margin, prevents immediate re-suggestion churn).
  ///  - LOWER −5 (floor [minGoal], default 10): goal missed on >= 4 of the
  ///    last 7 FULL days (today never counts as a miss — it is not over).
  ///  - Otherwise null. No data → null.
  static GoalSuggestion? goalSuggestion({
    required int currentGoal,
    required Map<String, int> xpLog,
    int window = 7,
    int minGoal = 10,
    int maxGoal = 60,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final days = <String>[];
    for (var i = 1; i <= window; i++) {
      final d = n.subtract(Duration(days: i));
      days.add(
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    int met = 0, missed = 0, metXpSum = 0;
    for (final day in days) {
      final v = xpLog[day] ?? 0;
      if (v >= currentGoal) {
        met += 1;
        metXpSum += v;
      } else if (v > 0) {
        missed += 1; // active but under goal = a real miss (idle days ignored)
      }
    }
    if (met >= 6) {
      final avg = metXpSum ~/ met;
      if (avg >= currentGoal + 15 && currentGoal + 5 <= maxGoal) {
        return GoalSuggestion(
            currentGoal + 5, 'goalRaiseReason', {'met': '$met', 'avg': '$avg'});
      }
    }
    if (missed >= 4 && currentGoal - 5 >= minGoal) {
      return GoalSuggestion(
          currentGoal - 5, 'goalLowerReason', {'miss': '$missed'});
    }
    return null;
  }

  // ================= confusion pairs =================

  /// Top confusion pairs by miss count, descending.
  /// [raw] maps "idA|idB" (lexically sorted) -> miss count.
  static List<ConfusionPair> topConfusions(Map<String, int> raw,
      {int limit = 5}) {
    final out = <ConfusionPair>[];
    raw.forEach((key, count) {
      final i = key.indexOf('|');
      if (i <= 0 || i == key.length - 1) return;
      final a = key.substring(0, i);
      final b = key.substring(i + 1);
      out.add(ConfusionPair(a, b, count));
    });
    out.sort((x, y) => y.count.compareTo(x.count));
    return out.take(limit).toList();
  }

  /// Normalized key for a confusion pair (lexically sorted ids).
  static String confusionKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  // ================= review forecast =================

  /// How many cards come due within the next [days] days (overdue cards
  /// count too — they are due even earlier).
  static int dueWithinDays(Map<String, CardData> cards, int days,
      {DateTime? now}) {
    final horizon =
        (now ?? DateTime.now()).millisecondsSinceEpoch + days * dayMs;
    return cards.values.where((c) => c.dueEpochMs <= horizon).length;
  }

  // ================= tutor tips =================

  /// Composed, prioritized, rule-based tips (max [maxTips]). Each rule is
  /// guarded by an evidence threshold so the learner never sees noise:
  ///  1. confusion pair with count >= 3
  ///  2. a best study hour exists
  ///  3. streak at risk (streak > 0 and today's XP is under the goal)
  ///  4. big review wave tomorrow (>= 8 cards)
  ///  5. accuracy trend up/down (needs >= 20 answers per half)
  static List<TutorTip> tutorTips({
    required Map<String, int> confusionPairs,
    required Map<String, Vocab> vocabById,
    required List<int> hourTotal,
    required List<int> hourCorrect,
    required Map<String, CardData> cards,
    required int streak,
    required int todayXp,
    required int dailyGoal,
    required Map<String, List<int>> answerLog,
    int maxTips = 4,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final tips = <TutorTip>[];

    final pairs = topConfusions(confusionPairs, limit: 1);
    if (pairs.isNotEmpty && pairs.first.count >= 3) {
      final p = pairs.first;
      final a = vocabById[p.vocabIdA]?.target ?? p.vocabIdA;
      final b = vocabById[p.vocabIdB]?.target ?? p.vocabIdB;
      tips.add(TutorTip('tipConfusion', {
        'a': a,
        'b': b,
        'n': '${p.count}',
        'idA': p.vocabIdA,
        'idB': p.vocabIdB
      }));
    }

    final hour = bestStudyHour(hourTotal, hourCorrect);
    if (hour != null) {
      final pct = (accuracyAt(hourTotal, hourCorrect, hour) * 100).round();
      tips.add(TutorTip('tipBestHour', {'hour': '$hour', 'pct': '$pct'}));
    }

    if (streak > 0 && todayXp < dailyGoal) {
      tips.add(TutorTip('tipStreakGuard',
          {'streak': '$streak', 'left': '${dailyGoal - todayXp}'}));
    }

    final dueTomorrow = dueWithinDays(cards, 1, now: n);
    if (dueTomorrow >= 8) {
      tips.add(TutorTip('tipReviewWave', {'n': '$dueTomorrow'}));
    }

    final delta = trendDelta(answerLog, now: n);
    if (delta != null) {
      if (delta >= 8) {
        tips.add(TutorTip('tipTrendUp', {'delta': '$delta'}));
      } else if (delta <= -8) {
        tips.add(TutorTip('tipTrendDown', {'delta': '$delta'}));
      }
    }

    return tips.take(maxTips).toList();
  }
}

// ================= v5.10 opt-in local analytics ==========================

/// Local, anonymous-by-construction retention metrics (opt-in only),
/// derived purely from the xpLog the app already stores — nothing ever
/// leaves the device.
class RetentionStats {
  RetentionStats._();

  /// Of the learner's last [window] active days, the fraction that were
  /// followed by an active NEXT day. Returns null when there is no
  /// evidence yet (<2 active days).
  static double? dayReturnRate(Map<String, int> xpLog, DateTime today,
      {int window = 14}) {
    final days = xpLog.keys
        .where((k) => (xpLog[k] ?? 0) > 0)
        .map(_parseDay)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (days.length < 2) return null;
    final from =
        days.length > window ? days.sublist(days.length - window) : days;
    var followed = 0;
    for (var i = 0; i < from.length - 1; i++) {
      if (from[i + 1].difference(from[i]).inDays == 1) followed++;
    }
    return followed / (from.length - 1);
  }

  static DateTime? _parseDay(String key) {
    final p = key.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
