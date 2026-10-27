// F1.1 — confusion-driven distractor selection (12-month plan §Q1).
//
// Until v5.12 the exercise generator picked distractors uniformly at random
// from the lesson pool while the app ALREADY tracked which words the learner
// confuses (Insights confusion pairs, fed by lesson mistakes since v4.4).
// The two engines were disconnected: exercises stayed artificially easy on
// the pairs the learner actually mixes up and artificially hard elsewhere.
//
// This module closes that loop. It is pure logic (Flutter-free, like
// insights.dart) and fully deterministic under an injected seeded Random:
// same inputs + same seed ⇒ exactly the same options, test-enforced.
//
// Distractor priority (12-month plan §F1.1):
//   1. learnerConfusion — a recorded confusion partner of the TARGET word
//      itself (the pair the learner personally mixes up).
//   2. profileConfusion — a frequently-confused word from elsewhere in the
//      learner's own history (count >= 2 required — evidence, not noise).
//      A word this learner demonstrably confuses is by definition a
//      slippery option worth probing against other targets too.
//   3. similarity       — orthographic/phonetic look-alike (shared prefix
//      or suffix with the tested string), the classic decoy.
//   4. random           — seeded random fill from the remaining pool.
//   5. reserve          — last-resort real-word padding for tiny lessons
//      (the v4.0 realWordReserve list, passed in by the generator).
import 'dart:math' as math;

import 'models.dart';

/// Where a chosen distractor came from — the provenance behind the
/// plan's KPI "distractor-from-confusion >= 40%".
enum DistractorSource {
  learnerConfusion,
  profileConfusion,
  similarity,
  random,
  reserve,
}

/// One chosen distractor: the option string, the vocab it came from
/// ('' for reserve padding) and why it was chosen.
class DistractorChoice {
  final String option;
  final String vocabId;
  final DistractorSource source;

  const DistractorChoice(this.option, this.vocabId, this.source);

  @override
  String toString() => '$option($source)';
}

class Distractors {
  /// Minimum miss-count for a NON-direct pair to count as profile evidence
  /// (priority 2). Direct pairs of the target word count from 1.
  static const int profileEvidenceMin = 2;

  /// Minimum shared prefix+suffix length for two strings to count as
  /// look-alikes (priority 3).
  static const int minSimilarity = 2;

  /// Picks up to [count] distractors for [target] from [pool].
  ///
  /// [fieldOf] extracts the compared string from a vocab — pass
  /// `(v) => v.target` for word-options (reverse/listen/pic) or
  /// `(v) => v.translationAr` for meaning-options (mcq). Confusion pairs
  /// are word-level, so the same partner works for both fields.
  ///
  /// [confusionPairs] maps "idA|idB" (lexically sorted, exactly what
  /// Insights.confusionKey produces and AppState stores) -> miss count.
  /// [random] makes the pick reproducible: same inputs + same seed ⇒ same
  /// output. [reserve] is the caller's real-word padding for tiny pools
  /// (the generator passes ExerciseGen.realWordReserve; a bare pick pads
  /// with nothing and may return fewer than [count] options).
  static List<DistractorChoice> pick({
    required Vocab target,
    required List<Vocab> pool,
    required String Function(Vocab) fieldOf,
    Map<String, int> confusionPairs = const {},
    int count = 3,
    math.Random? random,
    List<String> reserve = const [],
  }) {
    final rnd = random ?? math.Random();
    final correct = fieldOf(target);
    final byId = {for (final v in pool) v.id: v};
    final seen = <String>{correct};
    final out = <DistractorChoice>[];

    bool tryAdd(Vocab v, DistractorSource s) {
      if (v.id == target.id) return false;
      final o = fieldOf(v);
      if (o.isEmpty || o == correct || seen.contains(o)) return false;
      seen.add(o);
      out.add(DistractorChoice(o, v.id, s));
      return true;
    }

    // ---- Priority 1: the learner's own confusion partners of the target.
    final direct = <String, int>{};
    confusionPairs.forEach((key, c) {
      final partner = _partnerOf(key, target.id);
      if (partner != null) direct[partner] = c;
    });
    final directIds = direct.keys.toList()
      ..sort((a, b) {
        final byCount = direct[b]!.compareTo(direct[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    for (final id in directIds) {
      if (out.length >= count) break;
      final v = byId[id];
      if (v != null) tryAdd(v, DistractorSource.learnerConfusion);
    }

    // ---- Priority 2: profile-level confusable words (evidence >= 2).
    if (out.length < count) {
      final indirect = <String, int>{};
      confusionPairs.forEach((key, c) {
        if (c < profileEvidenceMin) return;
        final i = key.indexOf('|');
        if (i <= 0 || i == key.length - 1) return;
        final a = key.substring(0, i);
        final b = key.substring(i + 1);
        if (a == target.id || b == target.id) return; // already priority 1
        // The confusable word is whichever side lives in this pool.
        final candidate =
            byId.containsKey(a) ? a : (byId.containsKey(b) ? b : null);
        if (candidate == null || candidate == target.id) return;
        final w = c;
        if (w > (indirect[candidate] ?? 0)) indirect[candidate] = w;
      });
      final indirectIds = indirect.keys.toList()
        ..sort((a, b) {
          final byCount = indirect[b]!.compareTo(indirect[a]!);
          return byCount != 0 ? byCount : a.compareTo(b);
        });
      for (final id in indirectIds) {
        if (out.length >= count) break;
        tryAdd(byId[id]!, DistractorSource.profileConfusion);
      }
    }

    // ---- Priority 3: look-alikes (shared prefix / suffix).
    if (out.length < count) {
      final scored = <(Vocab, int)>[];
      for (final v in pool) {
        final o = fieldOf(v);
        if (o == correct || seen.contains(o) || o.isEmpty) continue;
        final s = _lcp(o, correct) + _lcs(o, correct);
        if (s >= minSimilarity) scored.add((v, s));
      }
      scored.sort((a, b) {
        final byScore = b.$2.compareTo(a.$2);
        return byScore != 0 ? byScore : a.$1.id.compareTo(b.$1.id);
      });
      for (final (v, _) in scored) {
        if (out.length >= count) break;
        tryAdd(v, DistractorSource.similarity);
      }
    }

    // ---- Priority 4: seeded random fill from what is left.
    if (out.length < count) {
      final rest = pool
          .where((v) => !seen.contains(fieldOf(v)) && v.id != target.id)
          .toList()
        ..shuffle(rnd);
      for (final v in rest) {
        if (out.length >= count) break;
        tryAdd(v, DistractorSource.random);
      }
    }

    // ---- Priority 5: real-word reserve for very small lessons.
    for (final r in reserve) {
      if (out.length >= count) break;
      if (r == correct || seen.contains(r)) continue;
      seen.add(r);
      out.add(DistractorChoice(r, '', DistractorSource.reserve));
    }

    return out.take(count).toList();
  }

  /// Share of distractor slots in [exercises] that trace back to the
  /// learner's confusion data — the session-level KPI behind the plan
  /// acceptance ">= 40% of distractors come from learner pairs".
  ///
  /// A distractor counts as confusion-sourced when its word participates in
  /// the learner's confusion network: a DIRECT partner of the tested word
  /// (priority 1) or a word the learner has confused elsewhere (priority 2).
  /// Words picked by look-alike/random/reserve that happen to sit in the
  /// network also count — the metric is a lower bound of true provenance
  /// and never invents confusion that is not in [confusionPairs].
  ///
  /// Audited types: mcq (meaning options), reverse/listen/picToWord
  /// (word options) and fillblank (word options). wordToPic uses emojis,
  /// truefalse has no distractor list, dictation has no options, and
  /// listenComp mixes example/meaning sources — those are excluded from
  /// both numerator and denominator (documented in the plan).
  static double confusionShare({
    required List<Exercise> exercises,
    required List<Vocab> pool,
    required Map<String, int> confusionPairs,
  }) {
    final byTarget = <String, String>{};
    final byAr = <String, String>{};
    for (final v in pool) {
      byTarget.putIfAbsent(v.target, () => v.id);
      byAr.putIfAbsent(v.translationAr, () => v.id);
    }
    final partners = <String, Set<String>>{};
    confusionPairs.forEach((key, _) {
      final i = key.indexOf('|');
      if (i <= 0 || i == key.length - 1) return;
      final a = key.substring(0, i);
      final b = key.substring(i + 1);
      (partners[a] ??= {}).add(b);
      (partners[b] ??= {}).add(a);
    });
    final network = <String>{
      for (final s in partners.values) ...s,
    };

    var total = 0;
    var confused = 0;
    for (final ex in exercises) {
      final Map<String, String>? index;
      switch (ex.type) {
        case ExerciseType.mcq:
          index = byAr;
        case ExerciseType.reverse:
        case ExerciseType.listen:
        case ExerciseType.picToWord:
        case ExerciseType.fillblank:
          index = byTarget;
        default:
          index = null; // not audited (see doc comment)
      }
      if (index == null) continue;
      final direct = partners[ex.vocab.id] ?? const <String>{};
      for (final o in ex.options) {
        if (o == ex.answer) continue;
        total++;
        final oid = index[o];
        if (oid == null) continue;
        if (direct.contains(oid) || network.contains(oid)) confused++;
      }
    }
    if (total == 0) return 0;
    return confused / total;
  }

  /// The other side of a confusion key when one side is [id], else null.
  static String? _partnerOf(String key, String id) {
    final i = key.indexOf('|');
    if (i <= 0 || i == key.length - 1) return null;
    final a = key.substring(0, i);
    final b = key.substring(i + 1);
    if (a == id) return b;
    if (b == id) return a;
    return null;
  }

  static int _lcp(String a, String b) {
    var n = 0;
    final m = a.length < b.length ? a.length : b.length;
    while (n < m && a.codeUnitAt(n) == b.codeUnitAt(n)) {
      n++;
    }
    return n;
  }

  static int _lcs(String a, String b) {
    var n = 0;
    while (n < a.length &&
        n < b.length &&
        a[a.length - 1 - n] == b[b.length - 1 - n]) {
      n++;
    }
    return n;
  }
}
