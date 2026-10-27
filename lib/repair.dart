// F1.2 — instant micro-repair after mistakes (12-month plan §Q1 F1.2).
//
// Until v5.13 a wrong answer showed the correct answer in the feedback bar
// and moved on: the mistake was COUNTED (wordMistakes) but never TREATED.
// This module closes that gap with a 20-second repair card inside the same
// screen, right after the first mistake on a word in a session:
//
//   step 1  hint      — the rule/distinction (a confusion pair the learner
//                       just proved, the v5.11 per-card memory hint rule, or
//                       a generic look-again line) + the word's own example
//                       when the corpus provides one.
//   step 2  reask     — a NEW question on the SAME word with DIFFERENT
//                       distractors (never the same decoys twice).
//   step 3  quickPick — a deliberately easier 2-option "pick the right one".
//
// Success at step 2 or 3 ends the repair and continues the lesson; failure
// returns to step 1 with a hard cap of 2 cycles, then the lesson continues
// without embarrassment (the plan's "لا إحراج" rule).
//
// dictation / listenComp repair is hint-then-retry-the-same-question only —
// no re-rolled typing (the plan's anti-fatigue exception).
//
// Repair rounds are XP-NEUTRAL by construction: they never touch recordAnswer,
// correctCount, mistakes, hearts or XP — only scored rounds do. The failed
// question itself is re-queued to return as a normal scored round at least
// [RepairEngine.minReaskGap] rounds later (never immediately), which is the
// plan acceptance "نجاح الخطوة 2 يمنع إعادة السؤال الأصلي مباشرة".
//
// Pure Dart (Flutter-free like insights.dart) and deterministic under an
// injected seeded Random: same inputs + same seed ⇒ same repair plan.
import 'dart:math' as math;

import 'distractors.dart';
import 'exercise_gen.dart';
import 'insights.dart';
import 'models.dart';

/// The three steps of the repair card.
enum RepairStep { hint, reask, quickPick }

/// What the session wants the screen to do after a repair interaction.
enum RepairAction {
  /// Show/keep the current step (no state change needed).
  stay,

  /// Render the re-rolled question (step 2).
  toReask,

  /// Render the easier 2-option question (step 3).
  toQuickPick,

  /// Back to the hint card (start of the next cycle).
  toHint,

  /// Repair succeeded — show success feedback, then resume the lesson.
  success,

  /// Both cycles exhausted — resume the lesson without embarrassment.
  giveUp,
}

/// Everything the screen needs to render one repair, precomputed once.
class RepairPlan {
  /// The word being repaired (== original.vocab, or the mistaken word when
  /// the repair was triggered from inside a match boss).
  final Vocab word;

  /// The exercise that was answered wrong (the match exercise itself when
  /// triggered from a match round).
  final Exercise original;

  /// Step 2 — new question on the same word, different distractors. For
  /// retryOriginalOnly plans this IS the original exercise (same instance).
  final Exercise reask;

  /// Step 3 — the easier 2-option pick. Null for retryOriginalOnly plans.
  final Exercise? quickPick;

  /// What gets re-queued into the lesson plan when the repair ends: the
  /// original failed question for normal repairs; for match-boss repairs a
  /// fresh recognition round on the mistaken word (re-queueing a whole
  /// multi-word pairing game would be disproportionate).
  final Exercise requeue;

  /// dictation / listenComp: hint then retry the SAME question, no re-roll.
  final bool retryOriginalOnly;

  /// Localized hint line: an l10n key + substitution args (same shape as
  /// Insights TutorTips — rendered with context.trF).
  final String hintKey;
  final Map<String, String> hintArgs;

  /// The word's own example, shown as the neutral anchor when present.
  final String? exampleTarget;
  final String? exampleAr;

  const RepairPlan({
    required this.word,
    required this.original,
    required this.reask,
    required this.quickPick,
    required this.requeue,
    required this.retryOriginalOnly,
    required this.hintKey,
    required this.hintArgs,
    this.exampleTarget,
    this.exampleAr,
  });
}

/// State machine for one repair: hint -> re-ask -> (quick pick), at most
/// [RepairEngine.maxCycles] cycles, then the lesson moves on.
class RepairSession {
  final RepairPlan plan;

  RepairStep step = RepairStep.hint;

  /// 1-based cycle counter (the plan's "حد أقصى دورتين").
  int cycle = 1;
  bool finished = false;
  bool succeeded = false;

  RepairSession(this.plan);

  /// CTA on the hint card pressed -> show the re-ask question.
  RepairAction hintDone() {
    step = RepairStep.reask;
    return RepairAction.toReask;
  }

  /// The learner answered the step-2 question.
  RepairAction answerReask(bool ok) {
    if (ok) {
      finished = true;
      succeeded = true;
      return RepairAction.success;
    }
    // dictation / listenComp: no easier fallback question — straight to the
    // next cycle (or give up).
    if (plan.retryOriginalOnly) return _failCycle();
    step = RepairStep.quickPick;
    return RepairAction.toQuickPick;
  }

  /// The learner answered the step-3 question.
  RepairAction answerQuick(bool ok) {
    if (ok) {
      finished = true;
      succeeded = true;
      return RepairAction.success;
    }
    return _failCycle();
  }

  RepairAction _failCycle() {
    if (cycle >= RepairEngine.maxCycles) {
      finished = true;
      succeeded = false;
      return RepairAction.giveUp;
    }
    cycle++;
    step = RepairStep.hint;
    return RepairAction.toHint;
  }
}

class RepairEngine {
  /// Hard cap of repair cycles per mistake (plan: "حد أقصى دورتين").
  static const int maxCycles = 2;

  /// The failed question may not come back as a scored round until at least
  /// this many other rounds were played (plan acceptance 2).
  static const int minReaskGap = 3;

  /// First-mistake rule: a word triggers a repair once per session — the
  /// first time it is answered wrong. [mistakenThisSession] is the caller's
  /// running set; returns true exactly when [vocabId] is new to it.
  static bool isFirstMistake(String vocabId, Set<String> mistakenThisSession) {
    return mistakenThisSession.add(vocabId);
  }

  /// Where the failed question should be re-inserted so that at least
  /// [gap] other rounds play before it: the learner is leaving index
  /// [justLeft]; positions justLeft+1 .. justLeft+gap must be other rounds,
  /// so the earliest allowed slot is justLeft + 1 + gap (clamped to the
  /// current plan length when the lesson is almost over — best effort).
  static int requeueIndex(
      {required int justLeft, required int length, int gap = minReaskGap}) {
    return math.min(justLeft + 1 + gap, length);
  }

  /// Stable seed for the repair RNG — FNV-1a over the lesson id, word id and
  /// how many repairs already ran, so the same mistake in a replayed lesson
  /// produces the same plan (determinism contract, like ExerciseGen).
  static int seedFor(String lessonId, String vocabId, int salt) {
    var h = 0x811c9dc5;
    for (final c in ('$lessonId|$vocabId|$salt').codeUnits) {
      h ^= c & 0xff;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// Builds the full repair for a wrong answer on [word].
  ///
  /// [original] is the failed exercise; [pool] the lesson's vocab (re-rolls
  /// draw distractors from it); [confusions] the learner's confusion pairs;
  /// [card] the word's SRS card when it exists (feeds the v5.11 memory-hint
  /// rule); [confusedWithId] the vocab the learner actually picked, when the
  /// wrong pick mapped to a real corpus word — the strongest hint material
  /// and the preferred quickPick decoy; [forMatch] switches the requeue to
  /// the re-rolled round (see [RepairPlan.requeue]).
  static RepairPlan buildPlan({
    required Exercise original,
    required Vocab word,
    required List<Vocab> pool,
    required Map<String, int> confusions,
    required math.Random random,
    CardData? card,
    String? confusedWithId,
    bool forMatch = false,
    List<Vocab> courseVocab = const [],
  }) {
    final retryOriginalOnly = original.type == ExerciseType.dictation ||
        original.type == ExerciseType.listenComp;

    // Step 2 — re-rolled question, same word, different distractors.
    final reaskType = forMatch ? ExerciseType.mcq : _reaskTypeOf(original.type);
    final avoid = original.options
        .where((o) => o.isNotEmpty && o != original.answer)
        .toList();
    final reask = retryOriginalOnly
        ? original // same instance: hint, then retry the identical question
        : ExerciseGen.remake(
            word,
            reaskType,
            pool,
            confusions,
            avoid: avoid,
            seed: seedFor(original.vocab.id, word.id, 1),
          );

    // Step 3 — the easier 2-option pick. Distractors.pick already prefers
    // the learner's own confusion partner (priority 1), which is exactly
    // the decoy worth drilling here.
    Exercise? quickPick;
    if (!retryOriginalOnly) {
      final meaningSide = original.type == ExerciseType.mcq ||
          original.type == ExerciseType.truefalse;
      final decoy = Distractors.pick(
        target: word,
        pool: pool,
        fieldOf:
            meaningSide ? (Vocab v) => v.translationAr : (Vocab v) => v.target,
        confusionPairs: confusions,
        count: 1,
        random: random,
        reserve: ExerciseGen.realWordReserve,
      );
      final wrong = decoy.isEmpty ? _anyOther(pool, word, random) : decoy.first;
      final opts = meaningSide
          ? [word.translationAr, if (wrong != null) wrong.option]
          : [word.target, if (wrong != null) wrong.option];
      opts.shuffle(random);
      quickPick = Exercise(
        type: ExerciseType.mcq,
        prompt: meaningSide ? word.target : word.translationAr,
        answer: meaningSide ? word.translationAr : word.target,
        options: opts,
        vocab: word,
        audioText: '', // playing the target would leak a target-option answer
        hint: meaningSide ? null : word.translationAr,
      );
    }

    // Requeue payload (see RepairPlan.requeue).
    final requeue = forMatch ? reask : original;

    // Hint selection — first match wins, silence beats noise.
    String hintKey;
    var hintArgs = const <String, String>{};
    // The confusion partner may live outside this lesson (cross-lesson
    // confusion) — resolve against the whole course corpus too.
    final partner = confusedWithId == null
        ? null
        : (_byId(pool, confusedWithId) ?? _byId(courseVocab, confusedWithId));
    if (partner != null && partner.id != word.id) {
      hintKey = 'repairHintPair';
      hintArgs = {
        'a': word.target,
        'am': word.translationAr,
        'b': partner.target,
        'bm': partner.translationAr,
      };
    } else if (card != null) {
      final tip = Insights.memoryHint(card);
      if (tip != null) {
        hintKey = tip.key;
        hintArgs = tip.params;
      } else {
        hintKey = 'repairHintGeneric';
      }
    } else {
      hintKey = 'repairHintGeneric';
    }

    return RepairPlan(
      word: word,
      original: original,
      reask: reask,
      quickPick: quickPick,
      requeue: requeue,
      retryOriginalOnly: retryOriginalOnly,
      hintKey: hintKey,
      hintArgs: hintArgs,
      exampleTarget: word.exampleTarget,
      exampleAr: word.exampleAr,
    );
  }

  /// The re-rolled type for step 2: same family as the failed round when the
  /// type is re-rollable, else a meaning mcq (the universal fallback).
  static ExerciseType _reaskTypeOf(ExerciseType t) {
    switch (t) {
      case ExerciseType.mcq:
      case ExerciseType.reverse:
      case ExerciseType.listen:
      case ExerciseType.picToWord:
      case ExerciseType.wordToPic:
      case ExerciseType.fillblank:
      case ExerciseType.truefalse:
      case ExerciseType.build:
        return t;
      case ExerciseType.dictation:
      case ExerciseType.listenComp:
      case ExerciseType.match:
        return ExerciseType.mcq; // unreachable via normal flow (guarded)
    }
  }

  /// Last-resort quickPick decoy for tiny pools: any other pool word.
  static DistractorChoice? _anyOther(
      List<Vocab> pool, Vocab word, math.Random random) {
    final rest = pool.where((v) => v.id != word.id).toList()..shuffle(random);
    if (rest.isEmpty) return null;
    return DistractorChoice(
        rest.first.target, rest.first.id, DistractorSource.random);
  }

  static Vocab? _byId(List<Vocab> pool, String id) {
    for (final v in pool) {
      if (v.id == id) return v;
    }
    return null;
  }
}
