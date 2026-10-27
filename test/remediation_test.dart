// 7-day remediation tests (v5.12, plan feature F2.4).
//
// The window must reward honesty: distinct days count, same-day repeats
// collapse, logs self-clean, and the scan is deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_al_lugha/remediation.dart';

void main() {
  final now = DateTime(2026, 3, 15, 12);

  test('remediation: a single lapse day is never a target', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'w', now);
    expect(Remediation.scan(log, now: now), isEmpty);
  });

  test('remediation: two distinct days inside the window qualify', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'w', now.subtract(const Duration(days: 2)));
    Remediation.recordLapse(log, 'w', now);
    final items = Remediation.scan(log, now: now);
    expect(items.length, 1);
    expect(items.first.vocabId, 'w');
    expect(items.first.lapseDays, 2);
    expect(items.first.severity, closeTo(2 / 7, 0.001));
  });

  test('remediation: same-day repeats collapse into one event', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'w', now);
    Remediation.recordLapse(log, 'w', now.add(const Duration(hours: 1)));
    Remediation.recordLapse(log, 'w', now.add(const Duration(hours: 5)));
    expect(log['w'], hasLength(1));
    expect(Remediation.scan(log, now: now), isEmpty,
        reason: 'one bad afternoon is not a chronic trap');
  });

  test('remediation: events outside the window age out', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'w', now.subtract(const Duration(days: 9)));
    Remediation.recordLapse(log, 'w', now.subtract(const Duration(days: 8)));
    Remediation.recordLapse(log, 'w', now);
    // Only today's event survives the 7-day window.
    expect(Remediation.scan(log, now: now), isEmpty);
    expect(log['w'], hasLength(1));
  });

  test('remediation: scan prunes words whose events fully aged out', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'old', now.subtract(const Duration(days: 30)));
    Remediation.scan(log, now: now);
    expect(log.containsKey('old'), isFalse);
  });

  test('remediation: recovery is automatic — stop lapsing, drop out', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'w', now.subtract(const Duration(days: 6)));
    Remediation.recordLapse(log, 'w', now.subtract(const Duration(days: 5)));
    expect(Remediation.isTarget(log, 'w', now: now), isTrue);
    // ...8 quiet days later the word is free.
    final later = now.add(const Duration(days: 8));
    expect(Remediation.isTarget(log, 'w', now: later), isFalse);
    expect(Remediation.scan(log, now: later), isEmpty);
  });

  test('remediation: most chronic word sorts first, ties break by id', () {
    final log = <String, List<int>>{};
    // 'b' lapsed on 4 distinct days, 'a' on 4 too, 'c' on 2.
    for (final d in [6, 4, 2, 0]) {
      Remediation.recordLapse(log, 'b', now.subtract(Duration(days: d)));
    }
    for (final d in [6, 4, 2, 0]) {
      Remediation.recordLapse(log, 'a', now.subtract(Duration(days: d)));
    }
    for (final d in [1, 3]) {
      Remediation.recordLapse(log, 'c', now.subtract(Duration(days: d)));
    }
    final items = Remediation.scan(log, now: now);
    expect(items.map((i) => i.vocabId).toList(), ['a', 'b', 'c']);
  });

  test('remediation: per-word event list is bounded', () {
    final log = <String, List<int>>{};
    // 10 lapse events on 10 distinct days — but only 7 days of window and
    // a cap of 8 events per word.
    for (var d = 0; d < 10; d++) {
      Remediation.recordLapse(log, 'w', now.subtract(Duration(days: d)));
    }
    expect(log['w']!.length, lessThanOrEqualTo(Remediation.maxEventsPerWord));
  });

  test('remediation: the tracked-word budget evicts the stalest word', () {
    final log = <String, List<int>>{};
    // Fill the budget with words lapsed today.
    for (var i = 0; i < Remediation.maxWordsTracked; i++) {
      Remediation.recordLapse(log, 'w$i', now);
    }
    expect(log.length, Remediation.maxWordsTracked);
    // One more word must evict exactly one existing word.
    Remediation.recordLapse(log, 'newcomer', now);
    expect(log.length, Remediation.maxWordsTracked);
    expect(log.containsKey('newcomer'), isTrue);
  });

  test('remediation: epochDay is UTC-based and stable across the day', () {
    expect(Remediation.epochDay(DateTime(2026, 3, 15, 0, 0, 0, 1)),
        Remediation.epochDay(DateTime(2026, 3, 15, 23, 59)));
  });

  test('remediation: severity is bounded 0..1', () {
    final log = <String, List<int>>{};
    for (final d in [0, 1, 2, 3, 4, 5, 6]) {
      Remediation.recordLapse(log, 'w', now.subtract(Duration(days: d)));
    }
    final items = Remediation.scan(log, now: now);
    expect(items.first.severity, 1.0);
  });

  test('remediation: isTarget matches scan results', () {
    final log = <String, List<int>>{};
    Remediation.recordLapse(log, 'trap', now.subtract(const Duration(days: 1)));
    Remediation.recordLapse(log, 'trap', now);
    Remediation.recordLapse(log, 'once', now);
    expect(Remediation.isTarget(log, 'trap', now: now), isTrue);
    expect(Remediation.isTarget(log, 'once', now: now), isFalse);
  });
}
