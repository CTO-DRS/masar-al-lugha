// 7-day remediation engine for Masar Al-Lugha (v5.12, plan feature F2.4).
//
// The FSRS scheduler already re-shows lapsed cards — but some words keep
// coming back again and again. This engine spots the TRAP: words the
// learner has forgotten on 2+ DISTINCT days within the rolling 7-day
// window, so the app can offer a focused repair lane before frustration
// sets in.
//
// Honesty rules:
//  - "distinct days" (not raw lapses): forgetting the same word three
//    times in one bad afternoon is one bad afternoon, not a chronic trap;
//  - the log is bounded (8 events per word, 200 words tracked, 7-day
//    window) — it records RECENT behaviour only and self-cleans;
//  - recovery is automatic: stop lapsing for a few days and a word drops
//    out of the window (and the queue) on its own.
//
// The engine is Flutter-free and unit-tested (test/remediation_test.dart).

/// One remediation target.
class RemediationItem {
  final String vocabId;

  /// Distinct calendar days (within the window) on which this word lapsed.
  final int lapseDays;

  /// severity = lapseDays / windowDays, 0..1 — higher = more chronic.
  final double severity;

  const RemediationItem(this.vocabId, this.lapseDays, this.severity);
}

class Remediation {
  Remediation._();

  static const int windowDays = 7;

  /// A word needs remediation when it lapsed on at least this many
  /// DISTINCT days inside the window.
  static const int minLapseDays = 2;

  /// Log bounds. 8 events per word covers a worst week; 200 words covers a
  /// heavy reviewer. Both keep the persisted payload small forever.
  static const int maxEventsPerWord = 8;
  static const int maxWordsTracked = 200;

  /// Epoch-day bucket — deliberately UTC-based (epochDay = ms / dayMs):
  /// stable across timezone/DST changes and identical to how FSRS intervals
  /// count days. All comparisons happen between epoch days, never wall
  /// clocks, so "yesterday" can never drift.
  static int epochDay(DateTime t) => t.millisecondsSinceEpoch ~/ dayMs;

  static const int dayMs = 86400000;

  // ================= recording =================

  /// Records one lapse for [vocabId] at time [now]. Same-day repeats
  /// collapse into one event (the distinct-days rule). The word's event
  /// list is pruned to the window and capped; when the word count exceeds
  /// [maxWordsTracked] the stalest-tracked word is evicted.
  static void recordLapse(
    Map<String, List<int>> log,
    String vocabId,
    DateTime now,
  ) {
    final today = epochDay(now);
    final cutoff = today - windowDays + 1; // window = today-6 .. today

    var events = log[vocabId];
    if (events == null) {
      if (log.length >= maxWordsTracked) _evictStalest(log);
      events = <int>[];
      log[vocabId] = events;
    }

    // Prune anything outside the window (cheap, keeps lists tiny).
    events.removeWhere((d) => d < cutoff);

    if (!events.contains(today)) {
      events.add(today);
      events.sort();
      if (events.length > maxEventsPerWord) {
        events.removeRange(0, events.length - maxEventsPerWord);
      }
    }

    // A word whose events all aged out no longer needs tracking.
    if (events.isEmpty) log.remove(vocabId);
  }

  /// Drops the word whose most recent event is the oldest (ties break by
  /// id for determinism). Called only when the word budget is full and a
  /// NEW word needs a slot.
  static void _evictStalest(Map<String, List<int>> log) {
    String? stalest;
    int stalestLast = -1;
    log.forEach((id, events) {
      final last = events.isEmpty ? -1 : events.last;
      if (stalest == null ||
          last < stalestLast ||
          (last == stalestLast && id.compareTo(stalest!) < 0)) {
        stalest = id;
        stalestLast = last;
      }
    });
    if (stalest != null) log.remove(stalest);
  }

  // ================= scanning =================

  /// Words trapped in the lapse window, most chronic first. Ties break by
  /// vocab id so the queue is deterministic. Words with no events inside
  /// the window are never returned (and are pruned from the log).
  static List<RemediationItem> scan(
    Map<String, List<int>> log, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = epochDay(n);
    final cutoff = today - windowDays + 1;

    final items = <RemediationItem>[];
    final dead = <String>[];
    log.forEach((id, events) {
      events.removeWhere((d) => d < cutoff);
      if (events.isEmpty) {
        dead.add(id);
        return;
      }
      final distinct = events.toSet().length;
      if (distinct >= minLapseDays) {
        items.add(RemediationItem(id, distinct, distinct / windowDays));
      }
    });
    for (final id in dead) {
      log.remove(id);
    }
    items.sort((a, b) {
      final bySeverity = b.severity.compareTo(a.severity);
      if (bySeverity != 0) return bySeverity;
      return a.vocabId.compareTo(b.vocabId);
    });
    return items;
  }

  /// True when [vocabId] is currently a remediation target — used by
  /// screens to badge a word without scanning the whole log.
  static bool isTarget(
    Map<String, List<int>> log,
    String vocabId, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final cutoff = epochDay(n) - windowDays + 1;
    return (log[vocabId] ?? const []).where((d) => d >= cutoff).length >=
        minLapseDays;
  }
}
