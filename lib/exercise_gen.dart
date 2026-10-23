// Generates varied interactive exercises from lesson vocabulary.
import 'dart:math';

import 'models.dart';

class ExerciseGen {
  static final Random _rng = Random();

  static List<Exercise> forLesson(Lesson lesson) {
    final vocab = List<Vocab>.from(lesson.vocab)..shuffle(_rng);
    final exercises = <Exercise>[];
    const cycle = [
      ExerciseType.reverse, // see Arabic -> pick word
      ExerciseType.mcq, // see word -> pick meaning
      ExerciseType.listen, // listen -> pick word
      ExerciseType.build, // arrange letters / words
    ];

    for (var i = 0; i < vocab.length; i++) {
      final v = vocab[i];
      var t = cycle[i % cycle.length];
      if (t == ExerciseType.build && !_canBuild(v)) {
        t = (i.isEven) ? ExerciseType.mcq : ExerciseType.reverse;
      }
      exercises.add(_make(t, v, vocab));
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

    // Cap length so lessons stay snappy.
    if (exercises.length > 10) {
      final matchEx = exercises.whereType<Exercise>().last;
      final trimmed = exercises.sublist(0, 9);
      trimmed.add(matchEx);
      return trimmed;
    }
    return exercises;
  }

  static bool _canBuild(Vocab v) {
    final t = v.target.trim();
    if (t.contains(' ')) return true; // phrase -> word tiles
    // Single latin word of reasonable length.
    return t.length >= 3 && t.length <= 8 && _isLatin(t);
  }

  static bool _isLatin(String s) =>
      s.runes.every((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122));

  static Exercise _make(
      ExerciseType type, Vocab v, List<Vocab> pool) {
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
      case ExerciseType.match:
        // handled in forLesson
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
