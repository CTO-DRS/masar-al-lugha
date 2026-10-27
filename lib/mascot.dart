// Rafiq & Friends — the interactive companion engine (v4.5).
//
// Flutter-free, offline, evidence-gated and explainable — the same
// philosophy as lib/insights.dart: thresholds everywhere, never guesses.
//
// Design contract (docs/ARCHITECTURE.md §4b):
//  * Unlocks read ONLY facts the profile already tracks (xp / streak /
//    lessonsCompleted) — unlocking stores nothing new.
//  * Lines are deterministic per (event, salt): the UI passes a salt
//    (lesson counter, day index…) and gets stable, rotating variety —
//    no randomness that breaks widget tests.
//  * Every line exists in BOTH locales and uses only the documented
//    placeholders ({s} streak, {lvl} level, {p} accuracy, {m} missed days);
//    test/mascot_test.dart enforces shape, parity and substitution.
//  * Placeholder vocabulary: {s} streak, {lvl} level, {p} accuracy %,
//    {m} missed days — {m} is only valid in comeback lines.

/// The five companions — since v4.9 they are the human learning crew
/// (coach, classmates and mentors). Each is unlocked by an evidence rule.
class MascotCharacter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String taglineAr;
  final String taglineEn;
  final int unlockXp; // total XP required (0 = no XP gate)
  final int unlockStreak; // current streak days required
  final int unlockLessons; // lessons completed required

  const MascotCharacter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.taglineAr,
    required this.taglineEn,
    this.unlockXp = 0,
    this.unlockStreak = 0,
    this.unlockLessons = 0,
  });

  String name(String locale) => locale == 'ar' ? nameAr : nameEn;
  String tagline(String locale) => locale == 'ar' ? taglineAr : taglineEn;

  /// 0 when all gates are open, otherwise the strictest remaining
  /// requirement expressed as (kind, amount) for the UI to localize.
  (String, int)? missingRequirement(MascotFacts f) {
    if (unlockXp > 0 && f.xp < unlockXp) return ('xp', unlockXp);
    if (unlockStreak > 0 && f.streak < unlockStreak) {
      return ('streak', unlockStreak);
    }
    if (unlockLessons > 0 && f.lessons < unlockLessons) {
      return ('lessons', unlockLessons);
    }
    return null;
  }
}

const List<MascotCharacter> mascotCast = [
  MascotCharacter(
    id: 'rafiq',
    nameAr: 'رفيق',
    nameEn: 'Rafiq',
    taglineAr: 'مدرّبك الشخصي — يمشي معك خطوة بخطوة',
    taglineEn: 'Your personal coach — step by step with you',
  ),
  MascotCharacter(
    id: 'farah',
    nameAr: 'فرَح',
    nameEn: 'Farah',
    taglineAr: 'زميل مرح يحتفل بكل نجاحاتك',
    taglineEn: 'A cheerful classmate celebrating every win',
    unlockXp: 500,
  ),
  MascotCharacter(
    id: 'nur',
    nameAr: 'نور',
    nameEn: 'Nur',
    taglineAr: 'صديقة هادئة تذكّرك بالمراجعة قبل النوم',
    taglineEn: 'A calm friend nudging you to review at night',
    unlockStreak: 7,
  ),
  MascotCharacter(
    id: 'zayd',
    nameAr: 'زايد',
    nameEn: 'Zayd',
    taglineAr: 'خبير المسار: يعرف كل الطرق… ويرسّخ لك الأساس',
    taglineEn: 'The path expert: knows every route, nails the basics',
    unlockLessons: 50,
  ),
  MascotCharacter(
    id: 'salma',
    nameAr: 'سلمى',
    taglineAr: 'مدرّبة صبورة تشجعك بلطف بعد كل خطأ',
    taglineEn: 'A patient mentor with the gentlest encouragement',
    nameEn: 'Salma',
    unlockXp: 1500,
  ),
];

MascotCharacter mascotById(String id) =>
    mascotCast.firstWhere((c) => c.id == id, orElse: () => mascotCast.first);

/// Snapshot of the profile facts the engine is allowed to see.
class MascotFacts {
  final int xp;
  final int streak;
  final int lessons;
  final int level;
  final int accuracy; // 0..100 lifetime
  final int missedDays; // consecutive fully-missed days (0 = active)

  const MascotFacts({
    required this.xp,
    required this.streak,
    required this.lessons,
    required this.level,
    required this.accuracy,
    required this.missedDays,
  });
}

/// Moments the companion can react to.
enum MascotEvent {
  lessonPerfect, // 100% accuracy
  lessonGreat, // >= 80
  lessonGood, // >= 50
  lessonStruggled, // < 50 — comfort, never shame
  lessonFailed, // hearts ran out
  streakMilestone, // 3/7/14/30/60/100
  levelUp,
  recordBroken, // v4.8: a new bestStreak/bestDayXp was set this lesson
  comeback, // returned after >= 3 missed days
  idle, // profile tip rotation
}

/// Moods understood by the mascot widget.
enum MascotMood { happy, neutral, sad, celebrate }

const Set<int> _milestones = {3, 7, 14, 30, 60, 100};

class MascotEngine {
  /// True when [streak] is a celebrated milestone.
  static bool isMilestone(int streak) => _milestones.contains(streak);

  /// Evidence-based event for a finished lesson.
  static MascotEvent lessonEvent(
      {required bool perfect, required int accuracy}) {
    if (perfect || accuracy >= 100) return MascotEvent.lessonPerfect;
    if (accuracy >= 80) return MascotEvent.lessonGreat;
    if (accuracy >= 50) return MascotEvent.lessonGood;
    return MascotEvent.lessonStruggled;
  }

  /// Highest-priority event for the result screen.
  /// Priority: fresh streak milestone > new personal record (v4.8) >
  /// level up > lesson quality.
  static MascotEvent resultEvent({
    required MascotEvent lessonQuality,
    required bool leveledUp,
    required int streakBefore,
    required int streakAfter,
    bool brokeRecord = false, // v4.8: bestStreak/bestDayXp just grew
  }) {
    if (streakAfter > streakBefore && isMilestone(streakAfter)) {
      return MascotEvent.streakMilestone;
    }
    if (brokeRecord) return MascotEvent.recordBroken;
    if (leveledUp) return MascotEvent.levelUp;
    return lessonQuality;
  }

  /// Mood the widget should render for an event.
  static MascotMood moodFor(MascotEvent e) {
    switch (e) {
      case MascotEvent.lessonPerfect:
      case MascotEvent.streakMilestone:
      case MascotEvent.levelUp:
      case MascotEvent.recordBroken:
        return MascotMood.celebrate;
      case MascotEvent.lessonGreat:
      case MascotEvent.lessonGood:
      case MascotEvent.comeback:
        return MascotMood.happy;
      case MascotEvent.idle:
        return MascotMood.neutral;
      case MascotEvent.lessonStruggled:
      case MascotEvent.lessonFailed:
        return MascotMood.sad;
    }
  }

  /// Deterministic rotating line. [salt] varies per call-site (lesson
  /// number, day index…) so users see variety without randomness.
  static String lineFor(
    MascotEvent e,
    MascotFacts f,
    String locale, {
    required int salt,
  }) {
    final bank = mascotLineCatalog[e]!;
    final tpl = bank[salt % bank.length];
    final raw = locale == 'ar' ? tpl.$1 : tpl.$2;
    return fill(raw, f);
  }

  /// Substitutes documented placeholders:
  /// {s} streak days, {lvl} level, {p} accuracy %, {m} missed days.
  /// Unknown placeholders are left untouched (tests assert none exist).
  static String fill(String tpl, MascotFacts f) => tpl
      .replaceAll('{s}', '${f.streak}')
      .replaceAll('{lvl}', '${f.level}')
      .replaceAll('{p}', '${f.accuracy}')
      .replaceAll('{m}', '${f.missedDays}');

  // ---------------------------------------------------------------------
  // v4.9 — living-speech primitives (typewriter). Flutter-free so widget
  // tests can drive the reveal deterministically.
  // ---------------------------------------------------------------------

  /// Characters of [text] visible after [elapsedMs] of typing at
  /// [charsPerSecond]. Clamps to [0, text.length]; empty text reveals 0.
  static int revealedChars(
    String text, {
    required int elapsedMs,
    int charsPerSecond = 34,
  }) {
    if (text.isEmpty || elapsedMs <= 0) return 0;
    return (elapsedMs * charsPerSecond ~/ 1000).clamp(0, text.length);
  }

  /// Total time the typewriter needs for [text] (0 ms for empty text).
  static Duration revealDuration(String text, {int charsPerSecond = 34}) {
    if (text.isEmpty) return Duration.zero;
    return Duration(milliseconds: (text.length * 1000 / charsPerSecond).ceil());
  }

  /// v4.9: encouragement spoken when the learner taps a companion.
  static String tapLine(MascotFacts f, String locale, {required int salt}) {
    final tpl = mascotTapLines[salt % mascotTapLines.length];
    return fill(locale == 'ar' ? tpl.$1 : tpl.$2, f);
  }

  /// v4.9: time-of-day greeting — morning 5-11, afternoon 12-17, night.
  static String greetingLine({
    required int hour,
    required String locale,
    required int salt,
  }) {
    final bank = mascotGreetings[_greetingSlot(hour)];
    final tpl = bank[salt % bank.length];
    return locale == 'ar' ? tpl.$1 : tpl.$2;
  }

  // ---------------------------------------------------------------------
  // v4.10 — always-talking primitives. The companion now speaks on its
  // own: praise after a correct answer, a gentle nudge after a wrong one,
  // and ambient motivation while a screen simply stays open.
  // ---------------------------------------------------------------------

  /// v4.10: quick encouragement spoken AUTOMATICALLY when an answer is
  /// correct. Short by design — it must never delay the next step.
  static String praiseLine(String locale, {required int salt}) {
    final tpl = mascotPraiseLines[salt % mascotPraiseLines.length];
    return locale == 'ar' ? tpl.$1 : tpl.$2;
  }

  /// v4.10: gentle motivation spoken AUTOMATICALLY when an answer is
  /// wrong. Comforts without shaming (same tone rules as the catalog).
  static String nudgeLine(String locale, {required int salt}) {
    final tpl = mascotNudgeLines[salt % mascotNudgeLines.length];
    return locale == 'ar' ? tpl.$1 : tpl.$2;
  }

  /// F1.2: calm teacher line spoken when a mistake opens the instant
  /// micro-repair card — dedicated bank, neutral tone, never shaming.
  static String repairLine(String locale, {required int salt}) {
    final tpl = mascotRepairLines[salt % mascotRepairLines.length];
    return locale == 'ar' ? tpl.$1 : tpl.$2;
  }

  /// v4.10: ambient chatter — the self-spoken motivation line used by
  /// LiveCompanion between events. Personal: {s}/{lvl} are filled from
  /// the profile facts.
  static String ambientLine(
    MascotFacts f,
    String locale, {
    required int salt,
  }) {
    final tpl = mascotAmbientLines[salt % mascotAmbientLines.length];
    return fill(locale == 'ar' ? tpl.$1 : tpl.$2, f);
  }

  /// v4.10: deterministic ambient cadence, 24–36 s. The salt (turn count)
  /// spreads companions on different screens apart so they never sync
  /// into a chorus, and stays stable for widget tests.
  static int ambientIntervalMs(int salt) => 24000 + (salt % 4) * 4000;

  static int _greetingSlot(int hour) {
    if (hour >= 5 && hour < 12) return 0;
    if (hour >= 12 && hour < 18) return 1;
    return 2;
  }
}

// ---------------------------------------------------------------------------
// Line catalog. 9 events x 6 lines x 2 locales. Kept in-code (not assets)
// so the tests compile-check them and the app stays a single install asset.
// Tone rules: celebrate effort, never mock mistakes, no fake urgency.
// ---------------------------------------------------------------------------
/// Public bilingual line catalog (ar, en) — public so tests enforce the
/// parity/placeholder contract and UI extensions can reuse the lines.
typedef MascotBiLine = (String ar, String en);

const Map<MascotEvent, List<MascotBiLine>> mascotLineCatalog = {
  MascotEvent.lessonPerfect: [
    (
      'ممتاز! درس كامل بلا خطأ واحد — أنت نجم حقيقي ⭐',
      'Flawless! Not a single mistake — you are a real star ⭐'
    ),
    (
      'درس مثالي! ذاكرتي تكبر معك يا بطل',
      'A perfect lesson! My memory grows with you, champ'
    ),
    (
      'أداء ١٠٠٪! هكذا يُبنى الطلاق كلمة بعد كلمة',
      '100% performance! Fluency is built word by word like this'
    ),
    (
      'بلا أخطاء! رفيقك فخور بك اليوم',
      'Zero mistakes! Your companion is proud today'
    ),
    (
      'إتقان كامل! دماغك يحب هذا الإيقاع',
      'Full mastery! Your brain loves this rhythm'
    ),
    (
      'درس مثالي مرة أخرى — ثباتك مذهل!',
      'Another perfect lesson — your consistency is amazing!'
    ),
  ],
  MascotEvent.lessonGreat: [
    (
      'أداء رائع ({p}٪)! تقترب من الدرس المثالي',
      'Great job ({p}%)! You are closing in on perfect'
    ),
    (
      'قوي جداً! الأخطاء القليلة تُقوّي الذاكرة',
      'Strong work! The few mistakes strengthen memory'
    ),
    ('{p}٪ دقة — أنت تتقدم بثبات', '{p}% accuracy — you are moving steadily'),
    ('ممتاز! كلمات اليوم صارت ملكك', 'Excellent! Today\'s words are yours now'),
    (
      'خطوة كبيرة في مسارك، استمر هكذا',
      'A big step on your path — keep this up'
    ),
    (
      'أعجبني تركيزك! لنجعلها مثالية غداً',
      'I loved your focus! Let\'s make it perfect next time'
    ),
  ],
  MascotEvent.lessonGood: [
    (
      'بداية جيدة ({p}٪)! التكرار يجعلها تثبت',
      'Good start ({p}%)! Repetition makes it stick'
    ),
    ('خطوة للأمام — كل جهد يُحسب لك', 'A step forward — every effort counts'),
    (
      'أنجزت الدرس! هذا أهم من الكمال',
      'You finished the lesson! That matters more than perfection'
    ),
    (
      '{p}٪ الآن — عد غداً وستراها ترتفع',
      '{p}% today — come back tomorrow and watch it rise'
    ),
    (
      'التقدم الحقيقي هكذا: خطوة خطوة',
      'Real progress looks like this: step by step'
    ),
    (
      'أحسنت! المراجعة القادمة ستكون أسهل',
      'Well done! The next review will feel easier'
    ),
  ],
  MascotEvent.lessonStruggled: [
    (
      'لا بأس أبداً — الأخطاء هي طريق التعلم نفسه',
      'It is absolutely fine — mistakes ARE the path'
    ),
    (
      'أعرف أن الدرس كان صعباً. سنعيده معاً أهدأ',
      'I know it was hard. We will repeat it, calmer'
    ),
    (
      'كل محترف بدأ يخطئ هنا. أنت في الطريق الصحيح',
      'Every pro started by failing here. You are on track'
    ),
    (
      'القلوب نفدت لكن الحماس لا ينفد — نحن معك',
      'Hearts ran out, but motivation did not — I am with you'
    ),
    (
      'خُذ نفساً. العودة غداً نصف النجاح',
      'Take a breath. Coming back tomorrow is half the win'
    ),
    (
      'أخطاؤك اليوم هي قصص نجاحك غداً',
      'Today\'s mistakes are tomorrow\'s success stories'
    ),
  ],
  MascotEvent.lessonFailed: [
    (
      'لا تستسلم! أعد المحاولة وسنكسر الرقم معاً',
      'Do not give up! Retry and we will beat it together'
    ),
    (
      'الخسارة مؤقتة، والتعلّم دائم. جاهز لدورة أخرى؟',
      'Losing is temporary, learning is permanent. Ready for another round?'
    ),
    (
      'صفر قلوب لا يعني صفر تقدم — تعلمت شيئاً جديداً اليوم',
      'Zero hearts is not zero progress — you learned something today'
    ),
    (
      'نغفو اليوم لنعود أقوى. رفيقك بانتظارك',
      'We rest today to return stronger. Your companion awaits'
    ),
    (
      'الدرس لن يهرب — خذ راحة وحاول مجدداً',
      'The lesson is not going anywhere — rest and retry'
    ),
    (
      'أبطال كثر خسروا مرات قبل أن يفوزوا دائماً',
      'Many champions lost often before winning always'
    ),
  ],
  MascotEvent.streakMilestone: [
    (
      '{s} يوماً متتالياً! هذه العادة تصبح أسطورة',
      '{s} days in a row! This habit is becoming legend'
    ),
    (
      'سلسلة {s} يوم! أنت لا تتعلم، أنت تتحول',
      'A {s}-day streak! You are not learning, you are transforming'
    ),
    (
      '{s} أيام! رفيقك يفتخر بك أمام الجميع',
      '{s} days! Your companion brags about you'
    ),
    (
      'وصلت {s} يوم متواصل — الاستمرارية سرّ الطلاق',
      'You reached {s} straight days — consistency is the secret'
    ),
    (
      '{s} يوم بلا انقطاع! استحققت هذا الاحتفال',
      '{s} days unbroken! You earned this celebration'
    ),
    (
      'سلسلة {s}! دماغك يشكرك على الانتظام',
      'Streak of {s}! Your brain thanks you for the routine'
    ),
  ],
  MascotEvent.levelUp: [
    (
      'المستوى {lvl}! كل ١٠٠ نقطة تصنع فيك فرقاً',
      'Level {lvl}! Every 100 XP makes a real difference'
    ),
    (
      'ترقية! وصلت للمستوى {lvl} — الطريق يتحمس لك',
      'Promotion! Level {lvl} reached — the path is excited'
    ),
    (
      'المستوى {lvl} مفتوح! كلمات جديدة تنتظرك',
      'Level {lvl} unlocked! New words await'
    ),
    (
      'مستوى {lvl}! أنت أقوى مما كنت الأسبوع الماضي',
      'Level {lvl}! You are stronger than last week'
    ),
    (
      'ألف مبروك — المستوى {lvl} في جيبك',
      'Congratulations — level {lvl} in your pocket'
    ),
    (
      'المستوى {lvl}! استمر، القمة ليست بعيدة',
      'Level {lvl}! Keep going, the summit is near'
    ),
  ],
  // v4.8: personal-record celebration. The concrete number is always on
  // the result card next to the mascot, so lines celebrate the moment
  // without inventing new placeholders.
  MascotEvent.recordBroken: [
    (
      'رقم قياسي جديد! إيقاعك اليوم لا يشبه أحداً',
      'A new record! Your pace today is unmatched'
    ),
    (
      'حطّمت حاجزك السابق — الطلاقة تقترب أسرع',
      'You shattered your own best — fluency is getting closer'
    ),
    (
      'ما شاء الله! سجل جديد يُضاف لإنجازاتك',
      'Well done! A new record joins your achievements'
    ),
    (
      'أفضل نسخة منك حتى الآن — سجلّك يقول ذلك!',
      'The best version of you so far — your record proves it!'
    ),
    (
      'إنجاز يستحق الاحتفال: رقم قياسي جديد 🎉',
      'An achievement worth celebrating: a new personal best 🎉'
    ),
    (
      'كل خطوة تُحسب — وسجلّ اليوم أثبت ذلك',
      'Every step counts — and today proved it'
    ),
  ],
  MascotEvent.comeback: [
    (
      'عدت! غبت {m} يوماً وكنا ننتظرك بفارغ الصبر',
      'You are back! We waited {m} days for you'
    ),
    (
      'أهلاً بعودتك! السلسلة الجديدة تبدأ الآن',
      'Welcome back! A new streak starts now'
    ),
    (
      'الغائبون لا يخسرون هنا — استئناف من حيث توقفت',
      'No penalties here — resuming right where you left'
    ),
    (
      'وجدانك عاد أولاً! لنملأ اليوم بمراجعات سهلة',
      'Your spirit returned first! Let us fill today with easy reviews'
    ),
    (
      'سعيد برؤيتك مجدداً بعد {m} يوم — لنكمل المسار',
      'Happy to see you after {m} days — let us continue'
    ),
    ('عودة حلوة! الطريق حفظ مكانك', 'Sweet return! The path kept your place'),
  ],
  MascotEvent.idle: [
    (
      'نصيحة: ٥ دقائق يومياً تتفوق على ساعة أسبوعياً',
      'Tip: 5 minutes daily beats an hour weekly'
    ),
    (
      'جرب وضع «الجُمل» في الدرس لتتعلم الكلمات في سياقها',
      'Try the sentence-mining lesson style to learn words in context'
    ),
    (
      'الكلمات النجمة (المفضلة) تُراجَع من مجموعة خاصة',
      'Starred words get their own flashcard deck'
    ),
    (
      'افتح «رؤى التعلّم» لترى أفضل ساعة دراسة لك',
      'Open Learning Insights to see your best study hour'
    ),
    (
      'النوم الجيد بعد المراجعة يثبّت الكلمات أسرع',
      'Good sleep after reviewing locks words in faster'
    ),
    (
      'انطق الكلمة بصوت عالٍ مع الصوت — يضاعف التذكر',
      'Say the word aloud with the audio — it doubles recall'
    ),
  ],
};

// ---------------------------------------------------------------------------
// v4.9 — tap lines: what a companion says when the learner pokes it.
// 6 lines x 2 locales, no placeholders, same tone rules as the catalog.
// ---------------------------------------------------------------------------
const List<MascotBiLine> mascotTapLines = [
  (
    'هل نشرتَني؟ أنا جاهز دائماً — لنكمل!',
    'Poked me? I am always ready — let us continue!'
  ),
  (
    'أنت تفعل أفضل مما تظن. واصِل!',
    'You are doing better than you think. Keep going!'
  ),
  (
    'خطوة صغيرة اليوم = ثقة كبيرة غداً',
    'A small step today = big confidence tomorrow'
  ),
  (
    'أنا هنا في كل درس — لننجزه معاً',
    'I am here for every lesson — let us finish it together'
  ),
  (
    'تذكّر: الاستمرارية أقوى من الحماس المؤقت',
    'Remember: consistency beats bursts of motivation'
  ),
  (
    'الطريق طويل لكن خطواتك تُحتسب كلها',
    'The path is long, but every step of yours counts'
  ),
];

// ---------------------------------------------------------------------------
// v4.10 — praise bursts (ar, en): spoken automatically after a CORRECT
// answer inside the lesson feedback bar. Short, energetic, no placeholders.
// ---------------------------------------------------------------------------
const List<MascotBiLine> mascotPraiseLines = [
  ('أحسنت! إجابة موفقة تماماً', 'Well done! Spot on'),
  (
    'صحيح! كل كلمة تُتقنها تقرّبك من الطلاقة',
    'Right! Every word mastered brings fluency closer'
  ),
  ('ممتاز! تركيزك واضح اليوم', 'Brilliant! Your focus shows today'),
  ('رائع! هذا إتقان حقيقي', 'Awesome! That is real mastery'),
  ('إجابة صحيحة — استمر على هذا الإيقاع', 'Correct — keep this rhythm going'),
  ('جميل! عقلك يعمل بامتياز', 'Lovely! Your brain is firing on all cylinders'),
];

// ---------------------------------------------------------------------------
// v4.10 — nudge bursts (ar, en): spoken automatically after a WRONG answer.
// Comfort first, never shame — the correct answer is already on screen.
// ---------------------------------------------------------------------------
const List<MascotBiLine> mascotNudgeLines = [
  (
    'لا بأس أبداً — الأخطاء طريق الإتقان نفسه',
    'It is absolutely fine — mistakes ARE the way'
  ),
  (
    'قريب جداً! راجع الإجابة وستثبت المرة القادمة',
    'So close! Review the answer and it will stick next time'
  ),
  (
    'لا مشكلة — الدماغ يتعلّم من الأخطاء أكثر من النجاحات',
    'No problem — the brain learns more from misses than wins'
  ),
  (
    'خذها بسهولة، سنعود لهذه الكلمة قريباً معاً',
    'Take it easy — we will revisit this word together soon'
  ),
  (
    'خطأ صغير اليوم = كلمة محفوظة غداً',
    'A small slip today = a word remembered tomorrow'
  ),
  ('استمر! المثابرة تصنع الفارق دائماً', 'Keep going! Persistence always wins'),
];

// ---------------------------------------------------------------------------
// F1.2 — repair moment (ar, en): spoken when a mistake opens the instant
// micro-repair card. Dedicated bank (8 lines) so the repair never reuses a
// generic nudge: the tone is a calm teacher joining the learner at the exact
// point of confusion — neutral, no shame, no fake urgency. Same contract as
// the other banks: bilingual parity, no placeholders, deterministic rotation.
// ---------------------------------------------------------------------------
const List<MascotBiLine> mascotRepairLines = [
  (
    'لا بأس — لنلقِ نظرة على القاعدة سريعاً معاً',
    'No worries — let us look at the rule together, quickly'
  ),
  (
    'عشرون ثانية الآن توفّر عليك مراجعة لاحقة طويلة',
    'Twenty seconds now saves a long review later'
  ),
  (
    'سنميّز الفرق معاً — أنت على بعد خطوة واحدة',
    'We will tell them apart together — you are one step away'
  ),
  (
    'الأخطاء الذكية هي التي تُبنى عليها الطلاقة',
    'Fluency is built on exactly these smart mistakes'
  ),
  (
    'خذ نفساً، انظر إلى المثال، ثم جرّب سؤالاً جديداً',
    'Take a breath, look at the example, then try a new question'
  ),
  (
    'سأساعدك على التمييز — هذه كلمتان فقط',
    'I will help you tell them apart — it is just two words'
  ),
  (
    'التركيز الآن يجعل هذه الكلمة ملكك للأبد',
    'Focus now and this word becomes yours for good'
  ),
  (
    'لنُصلحها هنا بدل أن تعود لتطاردك لاحقاً',
    'Let us fix it here instead of it chasing you later'
  ),
];

// ---------------------------------------------------------------------------
// v4.10 — ambient chatter (ar, en): the LiveCompanion speaks one of these
// every 24–36 s while a screen stays open. Personal ({s} streak, {lvl}
// level) and calm — motivation without fake urgency.
// ---------------------------------------------------------------------------
const List<MascotBiLine> mascotAmbientLines = [
  (
    'سلسلتك {s} يوماً وتنمو — أنت على الطريق الصحيح',
    'Your streak is {s} days and growing — you are on track'
  ),
  (
    'أنت الآن في المستوى {lvl} — تقدم يستحق الإعجاب',
    'You are level {lvl} now — progress worth admiring'
  ),
  (
    'درس قصير الآن يبني عادة أقوى غداً',
    'One short lesson now builds a stronger habit tomorrow'
  ),
  (
    'المراجعة المنتظمة تخطف الكلمات من النسيان',
    'Regular reviews steal words back from forgetting'
  ),
  (
    'كلماتك النجمة تنتظر مراجعة سريعة',
    'Your starred words await a quick review'
  ),
  (
    'خمس دقائق تكفي — ابدأ درساً قصيراً متى شئت',
    'Five minutes is enough — start a short lesson anytime'
  ),
  (
    'كل يوم تتعلم فيه يجعل هدف الطلاقة أقرب',
    'Every learning day brings your fluency goal closer'
  ),
  (
    'أنا معك في كل خطوة — تقدّم بإيقاعك أنت',
    'I am with you at every step — move at your own pace'
  ),
];

// ---------------------------------------------------------------------------
// v4.9 — time-of-day greetings (ar, en): morning 5-11 / afternoon 12-17 /
// night. Shown by the home-screen companion; rotates with a daily salt.
// ---------------------------------------------------------------------------
const List<List<MascotBiLine>> mascotGreetings = [
  [
    ('صباح الخير! جاهز لدرس اليوم؟', 'Good morning! Ready for today?'),
    (
      'صباح الإنجاز! كل كلمة اليوم تصنع فرقاً',
      'A productive morning — every word counts today'
    ),
  ],
  [
    (
      'مساء الخير! تمرين سريع يرفع مزاجك',
      'Good evening! A quick session lifts your mood'
    ),
    (
      'لديك طاقة عصر — لنستثمرها بكلمات جديدة',
      'Afternoon energy detected — let us spend it on new words'
    ),
  ],
  [
    (
      'ليلة موفقة! مراجعة قصيرة قبل النوم تثبّت الكلمات',
      'Restful night! A short review before sleep locks words in'
    ),
    (
      'ما زلت مستيقظاً؟ خمس دقائق مراجعة تكفي الليلة',
      'Still up? Five minutes of review is enough tonight'
    ),
  ],
];
