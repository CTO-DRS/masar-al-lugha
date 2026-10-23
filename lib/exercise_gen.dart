// Generates varied interactive exercises from lesson vocabulary.
// v2.0: adds interactive picture rounds (word<->emoji), fill-in-the-blank
// and true/false alongside the classic mcq / reverse / listen / build / match.
import 'dart:math';

import 'models.dart';

class ExerciseGen {
  static final Random _rng = Random();

  static const _fallbackEmojis = ['🎓', '🎨', '🎵', '⚽', '📚', '🌟'];

  /// Full exercise plan for a lesson.
  static List<Exercise> forLesson(Lesson lesson) {
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
      exercises.add(_make(t, v, pool));
    }

    // --- Interactive picture rounds (up to 2) ---
    final emojiWords =
        pool.where((v) => (v.emoji ?? '').isNotEmpty).toList()..shuffle(_rng);
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
          options: _distractors(
              correct: v.target,
              pool: pool.map((e) => e.target).toList()),
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
      final blank = _makeBlank(v, pool);
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

    // Boss round: matching pairs.
    if (vocab.length >= 4) {
      final picks = <Vocab>[...vocab]..shuffle(_rng);
      final four = picks.take(4).toList();
      final left = four.map((e) => e.target).toList();
      final right = four.map((e) => e.translationAr).toList()..shuffle(_rng);
      exercises.add(Exercise(
        type: ExerciseType.match,
        prompt: '',
        answer: '',
        matchLeft: left,
        matchRight: right,
        vocab: four.first,
        audioText: '',
      ));
    }

    // Cap length so lessons stay snappy (keep the match boss at the end).
    const maxLen = 14;
    if (exercises.length > maxLen) {
      final matchEx =
          exercises.firstWhere((e) => e.type == ExerciseType.match);
      final trimmed = exercises.where((e) => e != matchEx).take(maxLen - 1).toList();
      trimmed.add(matchEx);
      return trimmed;
    }
    return exercises;
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

  static List<String> _blankableTokens(String sentence) =>
      sentence
          .split(RegExp(r'\s+'))
          .where((t) => t.replaceAll(RegExp(r'[^\w\u0600-\u06FF]'), '').length >= 3)
          .toList();

  static Exercise? _makeBlank(Vocab v, List<Vocab> pool) {
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

    // Distractors: single words of similar nature from the lesson.
    final candidates = <String>{
      for (final p in pool)
        if (p != v && !p.isSentence && p.target.length >= 3) p.target,
    }.toList()
      ..remove(answer)
      ..shuffle(_rng);
    final opts = <String>[answer];
    for (final c in candidates) {
      if (opts.length >= 4) break;
      opts.add(c);
    }
    final fallback = ['always', 'never', 'water', 'today'];
    for (final f in fallback) {
      if (opts.length >= 4) break;
      if (!opts.contains(f)) opts.add(f);
    }
    opts.shuffle(_rng);
    return Exercise(
      type: ExerciseType.fillblank,
      prompt: sentence,
      answer: answer,
      options: opts,
      vocab: v,
      audioText: v.isSentence
          ? v.target
          : (v.exampleTarget ?? v.target),
      hint: v.isSentence ? v.translationAr : (v.exampleAr ?? v.translationAr),
    );
  }

  /// Returns (shownMeaning, isTrue).
  static (String, bool)? _tfShown(Vocab v, List<Vocab> pool) {
    final others =
        pool.where((p) => p != v && p.translationAr != v.translationAr).toList();
    if (others.isEmpty) return ('${v.translationAr}', true);
    final makeTrue = _rng.nextBool();
    if (makeTrue) return (v.translationAr, true);
    final wrong = others[_rng.nextInt(others.length)];
    return (wrong.translationAr, false);
  }

  static Exercise _make(ExerciseType type, Vocab v, List<Vocab> pool) {
    switch (type) {
      case ExerciseType.mcq:
        return Exercise(
          type: type,
          prompt: v.target,
          answer: v.translationAr,
          options: _distractors(
              correct: v.translationAr,
              pool: pool.map((e) => e.translationAr).toList()),
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.reverse:
        return Exercise(
          type: type,
          prompt: v.translationAr,
          answer: v.target,
          options: _distractors(
              correct: v.target, pool: pool.map((e) => e.target).toList()),
          vocab: v,
          audioText: '',
        );
      case ExerciseType.listen:
        return Exercise(
          type: type,
          prompt: '', // hidden in listen mode
          answer: v.target,
          options: _distractors(
              correct: v.target, pool: pool.map((e) => e.target).toList()),
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.build:
        final t = v.target.trim();
        final tiles = t.contains(' ')
            ? t.split(' ')
            : t.toUpperCase().split('');
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
          options: _distractors(
              correct: v.target, pool: pool.map((e) => e.target).toList()),
          vocab: v,
          audioText: '',
          hint: v.translationAr,
        );
      case ExerciseType.wordToPic:
        final opts = _emojiOptions(v.emoji ?? '🎓', pool) ??
            ['🎓', '🎨', '🎵', '⚽'];
        return Exercise(
          type: type,
          prompt: v.target,
          answer: v.emoji ?? '🎓',
          options: opts,
          vocab: v,
          audioText: v.target,
        );
      case ExerciseType.fillblank:
        final generated = _makeBlank(v, pool);
        return generated ??
            Exercise(
              type: ExerciseType.mcq,
              prompt: v.target,
              answer: v.translationAr,
              options: _distractors(
                  correct: v.translationAr,
                  pool: pool.map((e) => e.translationAr).toList()),
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
    }
  }

  static List<String> _distractors(
      {required String correct, required List<String> pool}) {
    final candidates =
        pool.where((e) => e != correct).toSet().toList()..shuffle(_rng);
    final opts = <String>[correct];
    for (final c in candidates) {
      if (opts.length >= 4) break;
      opts.add(c);
    }
    // Pad with generic fallbacks if pool too small.
    final fallback = ['___', '____', '_____'];
    var fi = 0;
    while (opts.length < 4 && fi < fallback.length) {
      opts.add(fallback[fi++]);
    }
    opts.shuffle(_rng);
    return opts;
  }
}
