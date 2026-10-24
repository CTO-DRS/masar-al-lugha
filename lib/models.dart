// Models for Masar Al-Lugha app.
// Course / Unit / Lesson / Vocab / Exercise / CardData

class Vocab {
  final String id;
  final String target; // word in the target language
  final String translationAr; // Arabic translation
  final String? phonetic; // Arabic transliteration (optional)
  final String? emoji; // illustration for interactive picture exercises
  final String? exampleTarget;
  final String? exampleAr;

  const Vocab({
    required this.id,
    required this.target,
    required this.translationAr,
    this.phonetic,
    this.emoji,
    this.exampleTarget,
    this.exampleAr,
  });

  bool get isSentence => target.trim().contains(' ');

  factory Vocab.fromJson(Map<String, dynamic> j) => Vocab(
        id: j['id'] as String,
        target: j['target'] as String,
        translationAr: j['translationAr'] as String,
        phonetic: j['phonetic'] as String?,
        emoji: j['emoji'] as String?,
        exampleTarget: j['exampleTarget'] as String?,
        exampleAr: j['exampleAr'] as String?,
      );
}

class Lesson {
  final String id;
  final String titleAr;
  final String titleEn;
  final List<Vocab> vocab;

  const Lesson({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.vocab,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        vocab: (j['vocab'] as List).map((e) => Vocab.fromJson(e)).toList(),
      );
}

class Unit {
  final String id;
  final String titleAr;
  final String titleEn;
  final String colorHex;
  final List<Lesson> lessons;

  /// Self-referenced CEFR level tag (A1..C2). NOT an official certification —
  /// see docs/CONTENT_AUDIT.md. Defaults to 'A1' so hand-written JSON or
  /// older assets without the tag still load.
  final String cefr;

  const Unit({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.colorHex,
    required this.lessons,
    this.cefr = 'A1',
  });

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        colorHex: j['color'] as String,
        lessons: (j['lessons'] as List).map((e) => Lesson.fromJson(e)).toList(),
        cefr: (j['cefr'] as String?) ?? 'A1',
      );
}

class Course {
  final String id;
  final String nameAr;
  final String nameEn;
  final String flag;
  final String ttsLang;
  final List<Unit> units;

  const Course({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.flag,
    required this.ttsLang,
    required this.units,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String,
        flag: j['flag'] as String,
        ttsLang: j['ttsLang'] as String,
        units: (j['units'] as List).map((e) => Unit.fromJson(e)).toList(),
      );

  List<Vocab> get allVocab =>
      units.expand((u) => u.lessons).expand((l) => l.vocab).toList();

  List<Lesson> get allLessons => units.expand((u) => u.lessons).toList();
}

// ---------------- Exercises ----------------

enum ExerciseType {
  mcq,
  reverse,
  listen,
  build,
  match,
  picToWord, // emoji shown -> pick the word
  wordToPic, // word shown  -> pick the emoji picture
  fillblank, // sentence with ___ -> pick the missing word
  truefalse, // word + shown meaning -> true or false?
}

class Exercise {
  final ExerciseType type;
  final String prompt; // main text shown to learner
  final String answer; // correct answer text
  final List<String> options; // for mcq / reverse / listen / pic / tf
  final List<String> tiles; // for build
  final List<String> matchLeft; // for match
  final List<String> matchRight; // for match
  final Vocab vocab; // related vocab (for TTS / feedback)
  final String audioText; // what TTS should say
  final String? hint; // extra context (sentence translation, etc.)

  const Exercise({
    required this.type,
    required this.prompt,
    required this.answer,
    this.options = const [],
    this.tiles = const [],
    this.matchLeft = const [],
    this.matchRight = const [],
    required this.vocab,
    required this.audioText,
    this.hint,
  });
}

// ---------------- SRS card ----------------

class CardData {
  double ease;
  int intervalDays;
  int dueEpochMs;
  int reps;
  int lapses;
  String state; // new | learning | review

  CardData({
    this.ease = 2.5,
    this.intervalDays = 0,
    int? dueEpochMs,
    this.reps = 0,
    this.lapses = 0,
    this.state = 'new',
  }) : dueEpochMs = dueEpochMs ?? DateTime.now().millisecondsSinceEpoch;

  bool get isDue => dueEpochMs <= DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'ivl': intervalDays,
        'due': dueEpochMs,
        'reps': reps,
        'lapses': lapses,
        'state': state,
      };

  factory CardData.fromJson(Map<String, dynamic> j) => CardData(
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (j['ivl'] as num?)?.toInt() ?? 0,
        dueEpochMs: (j['due'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        lapses: (j['lapses'] as num?)?.toInt() ?? 0,
        state: (j['state'] as String?) ?? 'new',
      );
}
