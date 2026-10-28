// Generates varied interactive exercises from lesson vocabulary.
// v2.0: adds interactive picture rounds (word<->emoji), fill-in-the-blank
// and true/false alongside the classic mcq / reverse / listen / build / match.
// v4.3: lesson styles — classic (unchanged mix), sentence-mining (cloze-first)
// and audio-first (TTS-led). Same corpus, different exercise sequence.
// v5.12 (F1.1): confusion-driven distractors (lib/distractors.dart) replace
// the purely random option picks, every lesson gets a per-lesson seeded RNG
// (same lesson + same learner state ⇒ same plan), and plans are balanced
// afterwards: no exercise type above 40% of the rounds, and CEFR A2+
// lessons always contain at least one production round (dictation/build).
import 'dart:math';

import 'distractors.dart';
import 'grammar.dart';
import 'models.dart';
import 'path.dart';

class ExerciseGen {
  // F1.1: re-seeded at every forLesson call (see _stableSeed). A static is
  // safe here because plan generation is synchronous within one isolate.
  static Random _rng = Random();

  static const _fallbackEmojis = ['🎓', '🎨', '🎵', '⚽', '📚', '🌟'];

  /// Full exercise plan for a lesson in the requested style.
  ///
  /// F1.1 parameters:
  ///  - [confusions]: the learner's confusion-pair map ("idA|idB" -> miss
  ///    count, exactly AppState.confusionPairs) — drives distractor
  ///    priorities 1 and 2 (learner's own pairs, then profile-level ones).
  ///  - [cefr]: the lesson unit's CEFR band — A2+ lessons get the
  ///    production floor (at least one dictation/build round).
  static List<Exercise> forLesson(Lesson lesson,
      {LessonMode mode = LessonMode.classic,
      Map<String, int> confusions = const {},
      String cefr = 'A1'}) {
    _rng = Random(_stableSeed(lesson.id));
    final List<Exercise> plan;
    switch (mode) {
      case LessonMode.sentences:
        plan = _sentencePlan(lesson, confusions);
        break;
      case LessonMode.audio:
        plan = _audioPlan(lesson, confusions);
        break;
      case LessonMode.classic:
        plan = _classicPlan(lesson, confusions);
        break;
    }
    // v5.18 (Phase-2 Batch B4): one grammar-drill round, only when the
    // course catalog has a lesson at or below this lesson's CEFR band —
    // the "قاعدة في الدرس" integration lane. Deterministic per lesson id;
    // inserted BEFORE the match boss so the boss stays the finale, and
    // subject to the same 14-round cap as every other round. Audio-first
    // lessons SKIP the round: they are TTS-led, and a silent reading rule
    // would break the mode's own invariant (pinned by distractors_test).
    final balanced = _balanced(_capped(plan), lesson.vocab, confusions,
        mode: mode, cefr: cefr);
    return mode == LessonMode.audio
        ? balanced
        : _withGrammarRound(balanced, lesson, cefr);
  }

  /// v5.18 (Batch B4): the per-lesson grammar round. Rules:
  ///  - the course must have grammar lessons at or below the lesson's CEFR
  ///    band (content that fits — never material above the learner);
  ///  - the picked lesson + drill are a pure function of the lesson id, so
  ///    the same lesson always drills the same rule (determinism contract);
  ///  - the drill renders like an mcq, with the WHY carried in [Exercise.hint]
  ///    (the rule reminder shown before answering — teach, then ask);
  ///  - never created for an empty/odd plan, never after the match boss.
  static List<Exercise> _withGrammarRound(
      List<Exercise> plan, Lesson lesson, String cefr) {
    if (plan.isEmpty || lesson.vocab.isEmpty) return plan;
    final courseId = lesson.id.split('_').first;
    if (courseId.length != 2) return plan;
    final rank = PathEngine.cefrRank(cefr);
    final pool = GrammarCatalog.forCourse(courseId)
        .where((l) => PathEngine.cefrRank(l.level) <= rank)
        .toList();
    if (pool.isEmpty) return plan;
    final gl = pool[_stableSeed('${lesson.id}|gr') % pool.length];
    final drill = gl.drills[_stableSeed('${lesson.id}|drill') % gl.drills.length];
    final grammarEx = Exercise(
      type: ExerciseType.grammar,
      prompt: drill.prompt,
      answer: drill.options[drill.correct],
      options: drill.options,
      vocab: lesson.vocab.first,
      audioText: '', // no auto-speak: the prompt is a rule, not a word
      hint: drill.explainAr,
    );
    final out = List<Exercise>.from(plan);
    final matchIdx = out.indexWhere((e) => e.type == ExerciseType.match);
    if (matchIdx >= 0) {
      out.insert(matchIdx, grammarEx);
    } else {
      out.add(grammarEx);
    }
    return out;
  }

  /// FNV-1a over UTF-16 code units — stable across runs and devices
  /// (String.hashCode is not contractually stable). Keeps whole plans
  /// reproducible: same lesson id ⇒ same shuffle order, which is what the
  /// determinism test and the 40%-cap sampler rely on.
  static int _stableSeed(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c & 0xff;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// v4.3 — sentence-mining plan: cloze first, then sentence building,
  /// then listen-to-the-whole-sentence, topped up with classic drills for
  /// lessons with little sentence material. Never returns an empty plan.
  static List<Exercise> _sentencePlan(
      Lesson lesson, Map<String, int> confusions) {
    final pool = lesson.vocab;
    final exercises = <Exercise>[];

    // Sentence material: multi-word items + words with an example sentence.
    final candidates = pool.where(_canBlank).toList()..shuffle(_rng);

    // 1) Cloze rounds (up to 6): the keyword hidden inside a real sentence.
    var cloze = 0;
    for (final v in candidates) {
      if (cloze >= 6) break;
      final b = _makeBlank(v, pool, confusions);
      if (b == null) continue;
      exercises.add(b);
      cloze++;
    }

    // 2) Build rounds (up to 4): arrange the sentence's words back in order.
    var builds = 0;
    for (final v in candidates) {
      if (builds >= 4) break;
      final t = v.isSentence ? v.target : v.exampleTarget!;
      final words = t.trim().split(RegExp(r'\s+'));
      if (words.length < 3 || words.length > 8) continue;
      exercises.add(Exercise(
        type: ExerciseType.build,
        prompt:
            v.isSentence ? v.translationAr : (v.exampleAr ?? v.translationAr),
        answer: t,
        tiles: words,
        vocab: v,
        audioText: t,
        hint: v.isSentence ? null : v.target,
      ));
      builds++;
    }

    // 3) Listen rounds (up to 4): hear the whole sentence, pick it out.
    final sentences = candidates.where((v) => v.isSentence).toList()
      ..shuffle(_rng);
    var listens = 0;
    for (final v in sentences) {
      if (listens >= 4) break;
      final opts = <String>[v.target];
      for (final o in sentences) {
        if (o == v || opts.contains(o.target)) continue;
        opts.add(o.target);
        if (opts.length >= 3) break;
      }
      if (opts.length < 2) continue; // need at least one distractor sentence
      opts.shuffle(_rng);
      exercises.add(Exercise(
        type: ExerciseType.listen,
        prompt: '',
        answer: v.target,
        options: opts,
        vocab: v,
        audioText: v.target,
      ));
      listens++;
    }

    // 3b) v4.6 dictation (1): hear the sentence -> type it. Arrange-then-type
    // deepens the mining loop without lengthening the lesson.
    for (final v in candidates) {
      final d = _makeDictation(v, pool);
      if (d == null) continue;
      exercises.add(d);
      break;
    }

    // 3c) v4.6 listening comprehension (up to 2): hear the sentence ->
    // pick its Arabic meaning (understanding, not just recognition).
    var comps = 0;
    for (final v in candidates) {
      if (comps >= 2) break;
      final c = _makeListenComp(v, pool);
      if (c == null) continue;
      exercises.add(c);
      comps++;
    }

    // 4) Thin material → top up with classic drills so the lesson is playable.
    if (exercises.length < 5) {
      final covered = exercises.map((e) => e.vocab.id).toSet();
      const cycle = [ExerciseType.reverse, ExerciseType.mcq];
      var i = 0;
      for (final v in pool) {
        if (exercises.length >= 6) break;
        if (covered.contains(v.id)) continue;
        exercises.add(_make(cycle[i++ % cycle.length], v, pool, confusions));
        covered.add(v.id);
      }
    }

    // Boss: matching pairs (words only — sentence chips would overflow).
    _addMatchBoss(exercises, pool);

    return _capped(exercises);
  }

  /// v4.3 — audio-first plan: every word starts as sound (hear → pick the
  /// word, hear → pick the meaning), then audio sentence building and a
  /// listen-to-the-sentence round. Every exercise except the tap-to-speak
  /// match boss carries non-empty [Exercise.audioText] (test-enforced).
  static List<Exercise> _audioPlan(Lesson lesson, Map<String, int> confusions) {
    final pool = lesson.vocab;
    final vocab = List<Vocab>.from(pool)..shuffle(_rng);
    final exercises = <Exercise>[];

    // 1) Ears-first recognition pass over the whole lesson.
    for (var i = 0; i < vocab.length; i++) {
      final v = vocab[i];
      if (i.isEven) {
        // hear the word -> pick the written word
        exercises.add(Exercise(
          type: ExerciseType.listen,
          prompt: '',
          answer: v.target,
          options: _optionsFor(v, pool, confusions, meanings: false),
          vocab: v,
          audioText: v.target,
        ));
      } else {
        // hear the word -> pick the Arabic meaning
        exercises.add(Exercise(
          type: ExerciseType.listen,
          prompt: '',
          answer: v.translationAr,
          options: _optionsFor(v, pool, confusions, meanings: true),
          vocab: v,
          audioText: v.target,
        ));
      }
    }

    // 2) Audio build rounds (up to 3): hear the sentence, arrange the words.
    final candidates = pool.where(_canBlank).toList()..shuffle(_rng);
    var builds = 0;
    for (final v in candidates) {
      if (builds >= 3) break;
      final t = v.isSentence ? v.target : v.exampleTarget!;
      final words = t.trim().split(RegExp(r'\s+'));
      if (words.length < 3 || words.length > 8) continue;
      exercises.add(Exercise(
        type: ExerciseType.build,
        prompt:
            v.isSentence ? v.translationAr : (v.exampleAr ?? v.translationAr),
        answer: t,
        tiles: words,
        vocab: v,
        audioText: t,
        hint: v.isSentence ? null : v.target,
      ));
      builds++;
    }

    // 2b) v4.6 dictation (up to 2): hear it -> type it. The typing step of
    // an audio lesson — sound first, then spelling it out. Scans the whole
    // pool so bare-word lessons get one too.
    var dict = 0;
    for (final v in pool) {
      if (dict >= 2) break;
      final d = _makeDictation(v, pool);
      if (d == null) continue;
      exercises.add(d);
      dict++;
    }

    // 3) Hear the whole sentence -> pick it among the lesson's sentences.
    final sentences = candidates.where((v) => v.isSentence).toList()
      ..shuffle(_rng);
    if (sentences.length >= 2) {
      final v = sentences.first;
      final opts = <String>[v.target];
      for (final o in sentences) {
        if (o == v) continue;
        opts.add(o.target);
        if (opts.length >= 3) break;
      }
      opts.shuffle(_rng);
      exercises.add(Exercise(
        type: ExerciseType.listen,
        prompt: '',
        answer: v.target,
        options: opts,
        vocab: v,
        audioText: v.target,
      ));
    }

    // 3b) v4.6 listening comprehension (1): hear the sentence -> its meaning.
    for (final v in candidates) {
      final c = _makeListenComp(v, pool);
      if (c == null) continue;
      exercises.add(c);
      break;
    }

    // Boss: matching pairs with tap-to-hear on the target column.
    _addMatchBoss(exercises, pool);

    return _capped(exercises);
  }

  /// Classic mixed plan (v2.0 behaviour, unchanged).
  static List<Exercise> _classicPlan(
      Lesson lesson, Map<String, int> confusions) {
    final vocab = List<Vocab>.from(lesson.vocab)..shuffle(_rng);
    final pool = lesson.vocab;
    final exercises = <Exercise>[];

    const cycle = [
      ExerciseType.reverse, // see Arabic -> pick word
      ExerciseType.mcq, // see word -> pick meaning
      ExerciseType.listen, // listen -> pick word
      ExerciseType.build, // arrange letters / words
    ];

    // Main pass: one core exercise per word.
    for (var i = 0; i < vocab.length; i++) {
      final v = vocab[i];
      var t = cycle[i % cycle.length];
      if (t == ExerciseType.build && !_canBuild(v)) {
        t = (i.isEven) ? ExerciseType.mcq : ExerciseType.reverse;
      }
      exercises.add(_make(t, v, pool, confusions));
    }

    // --- Interactive picture rounds (up to 2) ---
    // v4.0 audit (M10): skip words whose emoji is shared by another word in
    // the same lesson — a shared picture would make the round ambiguous
    // (two visually-identical correct answers).
    final emojiCounts = <String, int>{};
    for (final v in pool) {
      final e = v.emoji ?? '';
      if (e.isNotEmpty) emojiCounts[e] = (emojiCounts[e] ?? 0) + 1;
    }
    final emojiWords = pool
        .where((v) => (v.emoji ?? '').isNotEmpty && emojiCounts[v.emoji!] == 1)
        .toList()
      ..shuffle(_rng);
    var picAdded = 0;
    for (final v in emojiWords) {
      if (picAdded >= 2) break;
      if (picAdded == 0) {
        // word shown -> pick the emoji picture
        final opts = _emojiOptions(v.emoji!, pool);
        if (opts == null) continue; // not enough distinct pictures
        exercises.add(Exercise(
          type: ExerciseType.wordToPic,
          prompt: v.target,
          answer: v.emoji!,
          options: opts,
          vocab: v,
          audioText: v.target,
        ));
      } else {
        // picture shown -> pick the word
        exercises.add(Exercise(
          type: ExerciseType.picToWord,
          prompt: v.emoji!,
          answer: v.target,
          options: _optionsFor(v, pool, confusions, meanings: false),
          vocab: v,
          audioText: '',
          hint: v.translationAr,
        ));
      }
      picAdded++;
    }

    // --- Fill-in-the-blank rounds (up to 2) ---
    var blanksAdded = 0;
    final blankCandidates = pool.where(_canBlank).toList()..shuffle(_rng);
    for (final v in blankCandidates) {
      if (blanksAdded >= 2) break;
      final blank = _makeBlank(v, pool, confusions);
      if (blank != null) {
        exercises.add(blank);
        blanksAdded++;
      }
    }

    // --- True / false rounds (up to 2) ---
    var tfAdded = 0;
    final tfCandidates = List<Vocab>.from(pool)..shuffle(_rng);
    for (var i = 0; i < tfCandidates.length && tfAdded < 2; i++) {
      final v = tfCandidates[i];
      if (pool.length < 4 && tfAdded > 0) break;
      final shown = _tfShown(v, pool);
      if (shown == null) continue;
      exercises.add(Exercise(
        type: ExerciseType.truefalse,
        prompt: v.target,
        answer: shown.$2 ? 'true' : 'false',
        options: const ['true', 'false'],
        vocab: v,
        audioText: v.target,
        hint: shown.$1, // the meaning shown to judge
      ));
      tfAdded++;
    }

    // --- v4.6 dictation round (1): hear -> type ---
    // Every lesson can afford one dictation: sentence, example or bare
    // word — _makeDictation filters, so scan the whole pool.
    for (final v in pool) {
      final d = _makeDictation(v, pool);
      if (d == null) continue;
      exercises.add(d);
      break;
    }

    // Boss round: matching pairs.
    _addMatchBoss(exercises, pool);

    return _capped(exercises);
  }

  /// Shared boss round: 4 word<->meaning pairs (words only — sentence chips
  /// would overflow the match UI). No-op for tiny lessons.
  static void _addMatchBoss(List<Exercise> exercises, List<Vocab> pool) {
    final wordsOnly = pool.where((v) => !v.isSentence).length >= 4
        ? pool.where((v) => !v.isSentence).toList()
        : pool;
    if (wordsOnly.length < 4) return;
    final four = wordsOnly.toList()..shuffle(_rng);
    final picks = four.take(4).toList();
    final left = picks.map((e) => e.target).toList();
    final right = picks.map((e) => e.translationAr).toList()..shuffle(_rng);
    exercises.add(Exercise(
      type: ExerciseType.match,
      prompt: '',
      answer: '',
      matchLeft: left,
      matchRight: right,
      vocab: picks.first,
      audioText: '',
    ));
  }

  /// Cap length so lessons stay snappy (keep the match boss at the end).
  static List<Exercise> _capped(List<Exercise> exercises) {
    const maxLen = 14;
    if (exercises.length <= maxLen) return exercises;
    final matchEx = exercises.firstWhere((e) => e.type == ExerciseType.match);
    final trimmed =
        exercises.where((e) => e != matchEx).take(maxLen - 1).toList();
    trimmed.add(matchEx);
    return trimmed;
  }

  // ================= v4.6 typed + comprehension helpers =================

  /// Tolerant normalization for typed answers (dictation). Case-insensitive,
  /// punctuation/symbol-insensitive, whitespace-collapsing, and strips Arabic
  /// diacritics (tashkeel) + tatweel — so "Hello, World!", "hello world" and
  /// "مَدْرَسَةٌ" vs "مدرسة" all compare equal. Flutter-free, test-enforced.
  static String normalizeTyped(String s) {
    var t = s.trim().toLowerCase();
    // Arabic diacritics (fathatan..sukun), superscript alef, tatweel.
    t = t.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    // Punctuation & symbols -> spaces (unicode-aware), then collapse.
    t = t.replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// v4.6 — dictation: hear it, type it. Sentence dictation for lessons with
  /// sentence material, single-word dictation for bare words. The Arabic
  /// meaning rides in [Exercise.hint] so the learner knows WHAT to type.
  static Exercise? _makeDictation(Vocab v, List<Vocab> pool) {
    String target;
    String meaning;
    if (v.isSentence) {
      final n = v.target.trim().split(RegExp(r'\s+')).length;
      if (n < 2 || n > 8) return null;
      target = v.target;
      meaning = v.translationAr;
    } else if ((v.exampleTarget ?? '').trim().isNotEmpty) {
      final ex = v.exampleTarget!.trim();
      final n = ex.split(RegExp(r'\s+')).length;
      if (n < 2 || n > 8) return null;
      target = ex;
      meaning = v.exampleAr ?? v.translationAr;
    } else {
      final t = v.target.trim();
      if (t.length < 3 || t.length > 12) return null;
      target = t;
      meaning = v.translationAr;
    }
    return Exercise(
      type: ExerciseType.dictation,
      prompt: '',
      answer: target,
      vocab: v,
      audioText: target,
      hint: meaning,
    );
  }

  /// v4.6 — listening comprehension: hear the whole sentence, choose the
  /// Arabic meaning. Distractors are other sentence/example meanings from
  /// the same lesson; skipped entirely in lessons too poor to supply them.
  static Exercise? _makeListenComp(Vocab v, List<Vocab> pool) {
    final String audio;
    final String correct;
    if (v.isSentence) {
      audio = v.target;
      correct = v.translationAr;
    } else {
      final ex = (v.exampleTarget ?? '').trim();
      final ar = (v.exampleAr ?? '').trim();
      if (ex.isEmpty || ar.isEmpty) return null;
      audio = ex;
      correct = ar;
    }
    final candidates = <String>{};
    for (final p in pool) {
      if (p == v) continue;
      if (p.isSentence) {
        candidates.add(p.translationAr);
      } else {
        final ar = (p.exampleAr ?? '').trim();
        if (ar.isNotEmpty) candidates.add(ar);
      }
    }
    candidates
      ..remove(correct)
      ..removeWhere((s) => s.trim().isEmpty);
    if (candidates.length < 3) return null; // need 3 distinct distractors
    final picked = candidates.toList()..shuffle(_rng);
    final opts = <String>[correct, ...picked.take(3)]..shuffle(_rng);
    return Exercise(
      type: ExerciseType.listenComp,
      prompt: '',
      answer: correct,
      options: opts,
      vocab: v,
      audioText: audio,
    );
  }

  // ================= helpers =================

  static bool _canBuild(Vocab v) {
    final t = v.target.trim();
    if (t.contains(' ')) return true; // phrase -> word tiles
    // Single latin word of reasonable length.
    return t.length >= 3 && t.length <= 8 && _isLatin(t);
  }

  static bool _isLatin(String s) =>
      s.runes.every((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122));

  /// Pick 3 distractor emojis distinct from [correct]; null if impossible.
  static List<String>? _emojiOptions(String correct, List<Vocab> pool) {
    final others = <String>{
      for (final v in pool)
        if ((v.emoji ?? '').isNotEmpty && v.emoji != correct) v.emoji!,
    }..removeWhere((e) => e == correct);
    final list = others.toList()..shuffle(_rng);
    final opts = <String>[correct];
    for (final e in list) {
      if (opts.length >= 4) break;
      opts.add(e);
    }
    for (final f in _fallbackEmojis) {
      if (opts.length >= 4) break;
      if (!opts.contains(f)) opts.add(f);
    }
    opts.shuffle(_rng);
    return opts;
  }

  /// A vocab can be blanked if it has an example containing the word,
  /// or is a multi-word sentence.
  static bool _canBlank(Vocab v) {
    if (v.isSentence) {
      return _blankableTokens(v.target).length >= 2;
    }
    final ex = v.exampleTarget;
    if (ex == null) return false;
    return ex.toLowerCase().contains(v.target.toLowerCase());
  }

  static List<String> _blankableTokens(String sentence) => sentence
      .split(RegExp(r'\s+'))
      .where((t) => t.replaceAll(RegExp(r'[^\w\u0600-\u06FF]'), '').length >= 3)
      .toList();

  static Exercise? _makeBlank(
      Vocab v, List<Vocab> pool, Map<String, int> confusions) {
    String sentence;
    String answer;
    if (v.isSentence) {
      final tokens = _blankableTokens(v.target);
      if (tokens.length < 2) return null;
      // Blank the last long word (usually the keyword), never the first.
      answer = tokens.length > 1 ? tokens.last : tokens.first;
      if (answer == tokens.first && tokens.length > 1) return null;
      final re = RegExp(RegExp.escape(answer), caseSensitive: false);
      sentence = v.target.replaceFirstMapped(re, (_) => '______', 1);
    } else {
      final ex = v.exampleTarget!;
      answer = v.target;
      final re = RegExp(RegExp.escape(answer), caseSensitive: false);
      sentence = ex.replaceFirstMapped(re, (_) => '______', 1);
    }
    if (!sentence.contains('______')) return null;

    // F1.1 distractors: confusion partners first (words this learner mixes
    // up), then look-alikes, then seeded random — single lesson words only,
    // padded by the real-word reserve for tiny lessons. For sentence
    // blanks the answer is a token of the sentence, so options that
    // collide with it are filtered here (pick() only knows the target id).
    final wordPool = pool
        .where((p) => p.id != v.id && !p.isSentence && p.target.length >= 3)
        .toList();
    final picks = Distractors.pick(
      target: v,
      pool: wordPool,
      fieldOf: (x) => x.target,
      confusionPairs: confusions,
      random: _rng,
      reserve: realWordReserve,
    );
    final opts = <String>[answer];
    for (final c in picks) {
      if (c.option != answer && !opts.contains(c.option)) opts.add(c.option);
    }
    for (final r in realWordReserve) {
      if (opts.length >= 4) break;
      if (r != answer && !opts.contains(r)) opts.add(r);
    }
    opts.shuffle(_rng);
    return Exercise(
      type: ExerciseType.fillblank,
      prompt: sentence,
      answer: answer,
      options: opts,
      vocab: v,
      audioText: v.isSentence ? v.target : (v.exampleTarget ?? v.target),
      hint: v.isSentence ? v.translationAr : (v.exampleAr ?? v.translationAr),
    );
  }

  /// Returns (shownMeaning, isTrue).
  static (String, bool)? _tfShown(Vocab v, List<Vocab> pool) {
    final others = pool
        .where((p) => p != v && p.translationAr != v.translationAr)
        .toList();
    if (others.isEmpty) return (v.translationAr, true);
    final makeTrue = _rng.nextBool();
    if (makeTrue) return (v.translationAr, true);
    final wrong = others[_rng.nextInt(others.length)];
    return (wrong.translationAr, false);
  }

  static Exercise _make(ExerciseType type, Vocab v, List<Vocab> pool,
      Map<String, int> confusions) {
    switch (type) {
      case ExerciseType.mcq:
      case ExerciseType.grammar: // v5.18: grammar rounds are built directly
        return Exercise(
          type: type == ExerciseType.grammar ? ExerciseType.mcq : type,
          prompt: v.target,
          answer: v.translationAr,
          options: _optionsFor(v, pool, confusions, meanings: true),
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.reverse:
        return Exercise(
          type: type,
          prompt: v.translationAr,
          answer: v.target,
          options: _optionsFor(v, pool, confusions, meanings: false),
          vocab: v,
          audioText: '',
        );
      case ExerciseType.listen:
        return Exercise(
          type: type,
          prompt: '', // hidden in listen mode
          answer: v.target,
          options: _optionsFor(v, pool, confusions, meanings: false),
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.build:
        final t = v.target.trim();
        final tiles =
            t.contains(' ') ? t.split(' ') : t.toUpperCase().split('');
        return Exercise(
          type: type,
          prompt: v.translationAr,
          answer: v.target,
          tiles: tiles,
          vocab: v,
          audioText: '',
        );
      case ExerciseType.picToWord:
        return Exercise(
          type: type,
          prompt: v.emoji ?? '🎓',
          answer: v.target,
          options: _optionsFor(v, pool, confusions, meanings: false),
          vocab: v,
          audioText: '',
          hint: v.translationAr,
        );
      case ExerciseType.wordToPic:
        final opts =
            _emojiOptions(v.emoji ?? '🎓', pool) ?? ['🎓', '🎨', '🎵', '⚽'];
        return Exercise(
          type: type,
          prompt: v.target,
          answer: v.emoji ?? '🎓',
          options: opts,
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.fillblank:
        final generated = _makeBlank(v, pool, confusions);
        return generated ??
            Exercise(
              type: ExerciseType.mcq,
              prompt: v.target,
              answer: v.translationAr,
              options: _optionsFor(v, pool, confusions, meanings: true),
              vocab: v,
              audioText: v.target,
            );
      case ExerciseType.truefalse:
        final shown = _tfShown(v, pool)!;
        return Exercise(
          type: type,
          prompt: v.target,
          answer: shown.$2 ? 'true' : 'false',
          options: const ['true', 'false'],
          vocab: v,
          audioText: v.target,
          hint: shown.$1,
        );
      case ExerciseType.match:
        return Exercise(
          type: type,
          prompt: '',
          answer: '',
          vocab: v,
          audioText: '',
        );
      case ExerciseType.dictation:
      case ExerciseType.listenComp:
        // v4.6: never dispatched through _make (built by their own makers
        // with plan-level guards); if a caller ever does, degrade to a
        // plain mcq round instead of producing a broken exercise.
        return Exercise(
          type: ExerciseType.mcq,
          prompt: v.target,
          answer: v.translationAr,
          options: _optionsFor(v, pool, confusions, meanings: true),
          vocab: v,
          audioText: v.target,
        );
    }
  }

  /// F1.2: public rebuild entry for the repair flow — a fresh question on
  /// the SAME word whose distractors avoid every string in [avoid] (the
  /// failed round's distractor options), so the learner never faces the
  /// same decoys twice. Pool entries whose target/meaning/emoji string sits
  /// in [avoid] are dropped from the distractor source before rebuilding;
  /// [seed] re-seeds the generator so the repair is reproducible in tests.
  ///
  /// dictation / listenComp never pass through here (the repair retries the
  /// original question instead — see RepairEngine). truefalse degrades to a
  /// meaning mcq when the filtered pool no longer supports a shown-word pair.
  static Exercise remake(
      Vocab v, ExerciseType type, List<Vocab> pool, Map<String, int> confusions,
      {List<String> avoid = const [], int seed = 0}) {
    _rng = Random(seed);
    final banned = avoid.toSet();
    final filtered = pool
        .where((x) =>
            x.id == v.id ||
            (!banned.contains(x.target) &&
                !banned.contains(x.translationAr) &&
                (x.emoji == null || !banned.contains(x.emoji!))))
        .toList();
    var t = type;
    if (t == ExerciseType.truefalse && _tfShown(v, filtered) == null) {
      t = ExerciseType.mcq;
    }
    return _make(t, v, filtered, confusions);
  }

  /// F1.1: confusion-aware option list — [the tested string] first, then up
  /// to three distractors from Distractors.pick (learner confusions →
  /// profile confusions → look-alikes → seeded random → real-word reserve),
  /// then a seeded shuffle of positions. Replaces the old purely-random
  /// _distractors for every option-based round.
  static List<String> _optionsFor(
      Vocab v, List<Vocab> pool, Map<String, int> confusions,
      {required bool meanings}) {
    final String Function(Vocab) fieldOf =
        meanings ? (Vocab x) => x.translationAr : (Vocab x) => x.target;
    final picks = Distractors.pick(
      target: v,
      pool: pool,
      fieldOf: fieldOf,
      confusionPairs: confusions,
      random: _rng,
      reserve: realWordReserve,
    );
    final opts = <String>[fieldOf(v), ...picks.map((p) => p.option)];
    opts.shuffle(_rng);
    return opts;
  }

  /// F1.1 exercise balancing (plan §Q1 "توازن التمرين"):
  ///  1. CAP — no exercise type may exceed 40% of the lesson's rounds.
  ///     Over-cap rounds are first RE-TYPED in place into the scarcest
  ///     feasible under-cap core type (mcq/reverse/listen/build), always
  ///     the LATEST occurrence first so each mode's pedagogic opening
  ///     survives. When every lane is saturated (e.g. audio plans for
  ///     Arabic-script vocab: no build, no mcq), the surplus round is
  ///     REMOVED instead — and types we removed from are frozen as
  ///     conversion targets so the loop cannot ping-pong.
  ///  2. PRODUCTION FLOOR — CEFR A2+ lessons must contain at least one
  ///     production round (dictation or build); satisfied by converting an
  ///     existing round when possible, else inserting one dictation before
  ///     the match boss. A1 lessons are exempt (recognition first).
  ///
  /// Protected rounds: the match boss and listening comprehension (guarded
  /// by their own makers). Dictation may be re-typed only as a cap
  /// last resort — the floor below restores production coverage. Audio-first
  /// plans never receive mcq targets — ears-first by design (test-enforced).
  static List<Exercise> _balanced(
      List<Exercise> plan, List<Vocab> pool, Map<String, int> confusions,
      {required LessonMode mode, required String cefr}) {
    const cap = 0.40;
    const protected = {
      ExerciseType.match,
      ExerciseType.listenComp,
    };

    Exercise retype(Exercise e, ExerciseType t) {
      final ne = _make(t, e.vocab, pool, confusions);
      // Audio-first lessons are TTS-led: a converted round keeps audio.
      if (mode == LessonMode.audio && ne.audioText.isEmpty) {
        return Exercise(
          type: ne.type,
          prompt: ne.prompt,
          answer: ne.answer,
          options: ne.options,
          tiles: ne.tiles,
          matchLeft: ne.matchLeft,
          matchRight: ne.matchRight,
          vocab: ne.vocab,
          audioText: ne.vocab.target,
          hint: ne.hint,
        );
      }
      return ne;
    }

    final out = List<Exercise>.from(plan);
    final frozen = <ExerciseType>{}; // removed-from: never a target again
    var guard = 0;
    while (guard++ < out.length * out.length + 16) {
      final counts = <ExerciseType, int>{};
      for (final e in out) {
        counts[e.type] = (counts[e.type] ?? 0) + 1;
      }
      final total = out.length;
      ExerciseType? over;
      var bestRatio = cap + 1e-9;
      for (final t in ExerciseType.values) {
        final r = (counts[t] ?? 0) / total;
        if (r > bestRatio) {
          over = t;
          bestRatio = r;
        }
      }
      if (over == null) break;

      // Latest convertible occurrence of the over-cap type.
      var idx = -1;
      for (var i = out.length - 1; i >= 0; i--) {
        if (out[i].type == over && !protected.contains(over)) {
          idx = i;
          break;
        }
      }
      if (idx < 0) break; // protected type over cap (defensive)

      // Scarcest feasible under-cap target for this vocab.
      final feasible = <ExerciseType>[
        if (mode != LessonMode.audio) ExerciseType.mcq,
        ExerciseType.reverse,
        ExerciseType.listen,
        if (_canBuild(out[idx].vocab)) ExerciseType.build,
      ];
      ExerciseType? target;
      for (final t in feasible) {
        if (frozen.contains(t)) continue;
        // The target needs ROOM for one more round — otherwise converting
        // into it just pushes the violation next door (ping-pong).
        if (((counts[t] ?? 0) + 1) / total > cap + 1e-9) continue;
        if (t == over) continue;
        if (target == null || (counts[t] ?? 0) < (counts[target] ?? 0)) {
          target = t;
        }
      }
      if (target != null) {
        out[idx] = retype(out[idx], target);
      } else {
        // Every lane is saturated: drop the surplus round entirely.
        frozen.add(over);
        out.removeAt(idx);
      }
    }

    // Production floor for A2+ lessons.
    if (cefr != 'A1') {
      final hasProduction = out.any((e) =>
          e.type == ExerciseType.build || e.type == ExerciseType.dictation);
      if (!hasProduction) {
        final idx = out.indexWhere((e) =>
            !protected.contains(e.type) &&
            (e.type == ExerciseType.mcq ||
                e.type == ExerciseType.reverse ||
                e.type == ExerciseType.listen) &&
            _canBuild(e.vocab));
        if (idx >= 0) {
          out[idx] = retype(out[idx], ExerciseType.build);
        } else if (out.length < 14) {
          for (final v in pool) {
            final d = _makeDictation(v, pool);
            if (d == null) continue;
            final mi = out.indexWhere((e) => e.type == ExerciseType.match);
            if (mi >= 0) {
              out.insert(mi, d); // keep the match boss last
            } else {
              out.add(d);
            }
            break;
          }
        }
      }
    }
    return out;
  }

  /// Real words used only as a last-resort option padding for very small
  /// lessons. Covers common meanings in both interface languages.
  static const realWordReserve = [
    'book',
    'house',
    'water',
    'friend',
    'morning',
    'city',
    'work',
    'school',
    'كتاب',
    'بيت',
    'ماء',
    'صديق',
    'صباح',
    'مدينة',
    'عمل',
    'مدرسة',
  ];
}
