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
//   4. random           — seeded random fill from the remaining pool; in
//      F1.1b challenge mode this fill is drawn FIRST from the fair
//      challenge corpus (seen prior-unit vocab of a nearby domain), then
//      from the lesson pool.
//   5. reserve          — last-resort real-word padding for tiny lessons
//      (the v4.0 realWordReserve list, passed in by the generator).
import 'dart:math' as math;

import 'models.dart';
import 'path.dart';

/// Where a chosen distractor came from — the provenance behind the
/// plan's KPI "distractor-from-confusion >= 40%".
enum DistractorSource {
  learnerConfusion,
  profileConfusion,
  similarity,
  random,
  reserve,

  /// F1.1b (v5.20): a decoy drawn from the fair-difficulty challenge
  /// corpus — a word the learner has ALREADY SEEN in a prior unit of a
  /// nearby domain. Only reachable when the caller passes an [extraPool]
  /// (challenge mode); normal-mode plans never contain it.
  priorUnit,
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
  ///
  /// F1.1b (v5.20): [extraPool] is the fair-difficulty challenge corpus
  /// (seen prior-unit vocab, assembled by [challengePool]). Extras enter
  /// ONLY at priority 4 — they never displace the learner's own confusion
  /// pairs (1+2) or the classic look-alike decoys (3) — and they are drawn
  /// BEFORE the remaining lesson pool, so a challenge-mode random slot
  /// comes from nearby-domain learned material whenever one is available.
  /// An empty [extraPool] (the default = normal mode) consumes no RNG
  /// draws and leaves the output byte-identical to the v5.12–v5.19 pick.
  static List<DistractorChoice> pick({
    required Vocab target,
    required List<Vocab> pool,
    required String Function(Vocab) fieldOf,
    Map<String, int> confusionPairs = const {},
    int count = 3,
    math.Random? random,
    List<String> reserve = const [],
    List<Vocab> extraPool = const [],
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
      // F1.1b: challenge mode fills the random slots from the SEEN
      // prior-unit corpus first (fair = the learner met every one of
      // these words). An empty extraPool skips this loop without taking
      // a single draw from [rnd] — normal mode stays byte-identical.
      final extraRest = extraPool
          .where((v) => v.id != target.id && !seen.contains(fieldOf(v)))
          .toList()
        ..shuffle(rnd);
      for (final v in extraRest) {
        if (out.length >= count) break;
        tryAdd(v, DistractorSource.priorUnit);
      }
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

  /// F1.1b — the FAIR-DIFFICULTY challenge corpus for one lesson.
  ///
  /// Assembles up to [cap] vocab rows the learner has ALREADY SEEN
  /// ([seenIds] = the profile's card ids) from units that come BEFORE the
  /// lesson's unit, nearest domain first:
  ///   pass 1 — prior units whose [PathEngine.domainOfUnit] equals the
  ///            lesson unit's domain (the plan's "nearby-domain");
  ///   pass 2 — only if pass 1 is thinner than [cap]: prior units of ANY
  ///            domain whose CEFR band does not exceed the lesson's
  ///            (never material above the learner).
  ///
  /// Fairness invariants (all test-enforced):
  ///  - seen-only: a word without a card is never offered as a decoy;
  ///  - prior-only: the lesson's own unit (and everything after it) is
  ///    excluded — new material never leaks into the options;
  ///  - no collisions: rows whose target OR Arabic meaning string equals
  ///    a current-lesson row are dropped, so [challengeShare] can map an
  ///    option string back to exactly one owner word;
  ///  - deterministic: course order, lessons in order, first-come kept.
  ///
  /// The empty course / unknown lesson / no seen ids all yield `const []`.
  static List<Vocab> challengePool({
    required Course course,
    required String lessonId,
    required Set<String> seenIds,
    int cap = 24,
  }) {
    if (cap <= 0 || seenIds.isEmpty) return const [];
    var unitIdx = -1;
    for (var i = 0; i < course.units.length; i++) {
      if (course.units[i].lessons.any((l) => l.id == lessonId)) {
        unitIdx = i;
        break;
      }
    }
    if (unitIdx <= 0) return const []; // no prior units to draw from
    final unit = course.units[unitIdx];
    final domain = PathEngine.domainOfUnit(unit);
    final rank = PathEngine.cefrRank(unit.cefr);

    // Strings owned by the CURRENT lesson — extras must never collide.
    final lessonIds = <String>{};
    final lessonTargets = <String>{};
    for (final l in unit.lessons) {
      for (final v in l.vocab) {
        lessonIds.add(v.id);
        lessonTargets.add(v.target);
        lessonTargets.add(v.translationAr);
      }
    }

    final out = <Vocab>[];
    final usedIds = <String>{};
    void collect(List<Unit> units) {
      for (final u in units) {
        for (final l in u.lessons) {
          for (final v in l.vocab) {
            if (out.length >= cap) return;
            if (usedIds.contains(v.id) || lessonIds.contains(v.id)) continue;
            if (!seenIds.contains(v.id)) continue; // fair = seen only
            if (lessonTargets.contains(v.target) ||
                lessonTargets.contains(v.translationAr)) {
              continue;
            }
            usedIds.add(v.id);
            out.add(v);
          }
        }
      }
    }

    final prior = course.units.sublist(0, unitIdx);
    collect(prior.where((u) => PathEngine.domainOfUnit(u) == domain).toList());
    if (out.length < cap) {
      collect(prior.where((u) => PathEngine.cefrRank(u.cefr) <= rank).toList());
    }
    return out;
  }

  /// F1.1b KPI — the share of audited distractor slots in [exercises]
  /// that trace back to the challenge corpus ([extraPool]) rather than to
  /// the lesson's own [pool]. The challenge-mode counterpart of
  /// [confusionShare]: a slot counts when its option string maps to an
  /// extra-pool word and to NO pool word (challengePool drops string
  /// collisions, so the owner is unique). Audited types are the same set
  /// as [confusionShare]; untyped rounds are excluded from both sides.
  /// Normal mode (empty extras) is always exactly 0.
  static double challengeShare({
    required List<Exercise> exercises,
    required List<Vocab> pool,
    required List<Vocab> extraPool,
  }) {
    if (extraPool.isEmpty) return 0;
    (Map<String, String>, Map<String, String>) index(List<Vocab> vocab) {
      final byTarget = <String, String>{};
      final byAr = <String, String>{};
      for (final v in vocab) {
        byTarget.putIfAbsent(v.target, () => v.id);
        byAr.putIfAbsent(v.translationAr, () => v.id);
      }
      return (byTarget, byAr);
    }

    final (poolT, poolAr) = index(pool);
    final (extraT, extraAr) = index(extraPool);

    var total = 0;
    var prior = 0;
    for (final ex in exercises) {
      final bool meanings;
      switch (ex.type) {
        case ExerciseType.mcq:
          meanings = true;
        case ExerciseType.reverse:
        case ExerciseType.listen:
        case ExerciseType.picToWord:
        case ExerciseType.fillblank:
          meanings = false;
        default:
          continue; // not audited (same exclusion list as confusionShare)
      }
      final poolIdx = meanings ? poolAr : poolT;
      final extraIdx = meanings ? extraAr : extraT;
      for (final o in ex.options) {
        if (o == ex.answer) continue;
        total++;
        if (poolIdx.containsKey(o)) continue; // owned by the lesson pool
        if (extraIdx.containsKey(o)) prior++;
      }
    }
    if (total == 0) return 0;
    return prior / total;
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
