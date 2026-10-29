// Reading module (v5.8, Phase 4 skill 3): leveled short texts per course
// with tap-a-word → meaning lookup against the course corpus, and one-tap
// "add to review" that feeds the REAL SRS (via AppState.rateCard — an
// honest "hard" self-rating, same path as the flashcards).
//
// HONEST LABEL: the texts are machine-authored ("needs human review",
// docs/CONTENT_AUDIT.md) and reuse course vocabulary where natural so the
// tap-to-lookup works for most words; words outside the corpus simply
// show no gloss (the UI says so) — no invented translations.
import 'models.dart';

/// v5.18 (Phase-2 Batch D1): one comprehension question for a reading
/// text. Questions are authored AGAINST the text body (answerable from the
/// text alone — no outside knowledge, no invented linguistics) and live as
/// const DATA like the texts themselves.
class ReadingQuestion {
  final String promptAr;
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int correct;
  const ReadingQuestion(this.promptAr, this.options, this.correct);
}

class ReadingText {
  final String id;
  final String courseId;
  final String level; // self-referenced band tag
  final String titleAr;
  final String titleEn;
  final String body; // target-language text, sentence-split by [.!?؟۔]
  final List<String> sentencesAr; // aligned with body sentences (best effort)

  /// v5.18 (Batch D1): comprehension questions (0..2 per text). Empty for
  /// older payloads is fine — the section simply does not render.
  final List<ReadingQuestion> questions;
  const ReadingText(this.id, this.courseId, this.level, this.titleAr,
      this.titleEn, this.body, this.sentencesAr,
      {this.questions = const []});

  /// Sentences of the body, trimmed, empty dropped.
  List<String> sentences() => body
      .split(RegExp(r'(?<=[.!?؟۔])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class ReadingCatalog {
  ReadingCatalog._();

  /// 2 starter texts per course (honest scope — grows in later waves).
  static const List<ReadingText> texts = [
    // ---------- English ----------
    ReadingText(
      'rd_en_morning',
      'en',
      'A1',
      'صباح أحمد',
      'Ahmed\'s Morning',
      'Ahmed wakes up at six every day. He drinks water and eats an apple '
          'for breakfast. His brother goes to school with him. They walk '
          'because the school is near.',
      [
        'يستيقظ أحمد في السادسة كل يوم.',
        'يشرب ماءً ويأكل تفاحة على الفطور.',
        'أخوه يذهب إلى المدرسة معه.',
        'سيراً على الأقدام لأن المدرسة قريبة.',
      ],
      questions: [
        ReadingQuestion('متى يستيقظ أحمد كل يوم؟',
            ['في الثامنة', 'في السابعة', 'في السادسة'], 2),
        ReadingQuestion('لماذا يذهبون سيراً على الأقدام؟',
            ['لأن المدرسة قريبة', 'لأن السيارة معطلة', 'لأن الجو جميل'], 0),
      ],
    ),
    ReadingText(
      'rd_en_market',
      'en',
      'A2',
      'يوم في السوق',
      'A Day at the Market',
      'On Friday, my mother goes to the market. She buys fresh vegetables, '
          'bread and cheese. The price is good and the seller is friendly. '
          'At home, she cooks a big family meal.',
      [
        'يوم الجمعة تذهب أمي إلى السوق.',
        'تشتري خضاراً طازجة وخبزاً وجبناً.',
        'السعر جيد والبائع ودود.',
        'في البيت تطبخ وجبة عائلية كبيرة.',
      ],
      questions: [
        ReadingQuestion('ماذا تشتري أمي من السوق؟',
            ['فطائراً وحلوى', 'لحماً وأرزاً', 'خضاراً طازجة وخبزاً وجبناً'], 2),
        ReadingQuestion('كيف يكون البائع؟', ['متعباً', 'ودوداً', 'غاضباً'], 1),
      ],
    ),
    // ---------- German ----------
    ReadingText(
      'rd_de_schule',
      'de',
      'A1',
      'يوم علي في المدرسة',
      'Alis Schultag',
      'Ali ist Schüler in Berlin. Die Schule beginnt um acht Uhr. Er hat '
          'Mathe und Deutsch heute. In der Pause spielt er mit seinem Freund.',
      [
        'علي تلميذ في برلين.',
        'المدرسة تبدأ في الثامنة.',
        'لديه اليوم رياضيات وألمانية.',
        'في الاستراحة يلعب مع صديقه.',
      ],
      questions: [
        ReadingQuestion(
            'متى تبدأ المدرسة؟', ['في الثامنة', 'في التاسعة', 'في السابعة'], 0),
        ReadingQuestion(
            'بمن يلعب علي في الاستراحة؟', ['وحده', 'مع صديقه', 'مع أخيه'], 1),
      ],
    ),
    ReadingText(
      'rd_de_urlaub',
      'de',
      'A2',
      'العطلة عند البحر',
      'Urlaub am Meer',
      'Im Sommer fahren wir ans Meer. Das Hotel hat einen Meerblick und '
          'das Wetter ist warm. Am Strand spielen die Kinder und schwimmen. '
          'Am Abend essen wir Fisch im Restaurant.',
      [
        'في الصيف نسافر إلى البحر.',
        'الفندق له إطلالة على البحر والجو دافئ.',
        'على الشاطئ يلعب الأطفال ويسبحون.',
        'في المساء نأكل السمك في المطعم.',
      ],
      questions: [
        ReadingQuestion('إلى أين نسافر في الصيف؟',
            ['إلى البحر', 'إلى الجبل', 'إلى المدينة'], 0),
        ReadingQuestion(
            'ماذا نأكل في المساء؟', ['اللحم', 'السمك', 'الدجاج'], 1),
      ],
    ),
    // ---------- French ----------
    ReadingText(
      'rd_fr_famille',
      'fr',
      'A1',
      'عائلة ليلى',
      'La famille de Leila',
      'Leila habite avec sa famille. Son père travaille dans un bureau. '
          'Sa mère cuisine très bien. Le week-end, ils visitent le parc '
          'ensemble.',
      [
        'تعيش ليلى مع عائلتها.',
        'والدها يعمل في مكتب.',
        'أمها تطبخ بشكل رائع.',
        'في نهاية الأسبوع يزورون الحديقة معاً.',
      ],
      questions: [
        ReadingQuestion(
            'أين يعمل والد ليلى؟', ['في مستشفى', 'في مدرسة', 'في مكتب'], 2),
        ReadingQuestion('إلى أين يذهبون في نهاية الأسبوع؟',
            ['إلى الحديقة', 'إلى المتحف', 'إلى الشاطئ'], 0),
      ],
    ),
    ReadingText(
      'rd_fr_ville',
      'fr',
      'A2',
      'في المدينة',
      'Dans la ville',
      'Ma ville est grande et belle. Il y a un musée, une bibliothèque et '
          'un grand marché. Le matin, le bus est rapide et pas cher. Le '
          'soir, les rues sont calmes.',
      [
        'مدينتي كبيرة وجميلة.',
        'فيها متحف ومكتبة عامة وسوق كبير.',
        'في الصباح الحافلة سريعة وغير مكلفة.',
        'في المساء تكون الشوارع هادئة.',
      ],
      questions: [
        ReadingQuestion('كيف هي الحافلة في الصباح؟',
            ['مزدحمة وصاخبة', 'سريعة وغير مكلفة', 'بطيئة ومكلفة'], 1),
        ReadingQuestion(
            'كيف تكون الشوارع في المساء؟', ['مزدحمة', 'مغلقة', 'هادئة'], 2),
      ],
    ),
    // ---------- Urdu ----------
    ReadingText(
      'rd_ur_ghar',
      'ur',
      'A1',
      'بيتنا',
      'ہمارا گھر',
      'ہمارا گھر چھوٹا ہے مگر صاف ہے۔ میری ماں صبح چائے بناتی ہیں۔ میرا '
          'بھائی اسکول جاتا ہے۔ شام کو ہم سب مل کر کھانا کھاتے ہیں۔',
      [
        'بيتنا صغير لكنه نظيف.',
        'أمي تحضّر الشاي في الصباح.',
        'أخي يذهب إلى المدرسة.',
        'في المساء نأكل معاً جميعاً.',
      ],
      questions: [
        ReadingQuestion('كيف هو البيت؟',
            ['كبير لكنه قديم', 'صغير لكنه نظيف', 'بعيد لكنه جميل'], 1),
        ReadingQuestion(
            'ماذا تحضّر أمي في الصباح؟', ['القهوة', 'العصير', 'الشاي'], 2),
      ],
    ),
    ReadingText(
      'rd_ur_bazar',
      'ur',
      'A2',
      'السوق الجمعة',
      'جمعے کا بازار',
      'جمعے کے دن بازار گنجان ہوتا ہے۔ امی تازہ سبزی اور پھل خریدتی ہیں۔ '
          'دکاندار مہربان ہوتا ہے۔ گھر آ کر امی مزیدار کھانا پکاتی ہیں۔',
      [
        'يوم الجمعة يكون السوق مزدحماً.',
        'تشتري أمي خضاراً وفواكه طازجة.',
        'يكون البائع لطيفاً.',
        'تعود للبيت وتطبخ أمي طعاماً لذيذاً.',
      ],
      questions: [
        ReadingQuestion('متى يكون السوق مزدحماً؟',
            ['يوم الجمعة', 'يوم الأربعاء', 'يوم الاثنين'], 0),
        ReadingQuestion('ماذا تشتري أمي؟',
            ['لحماً وخبزاً', 'حليباً وجبناً', 'خضاراً وفواكه طازجة'], 2),
      ],
    ),
    // ---------- v5.16 (Q4/F4.2): B1/B2 depth for every course ----------
    // ---------- English ----------
    ReadingText(
      'rd_en_journey',
      'en',
      'B1',
      'رحلة أحمد إلى لندن',
      'Ahmed\'s Journey',
      'Last summer, Ahmed traveled to London for the first time. The '
          'flight took four hours, and he was nervous at the airport. In '
          'the city, he visited a famous museum and practiced English '
          'with local people. He says traveling is the best teacher, and '
          'he wants to return next year.',
      [
        'في الصيف الماضي، سافر أحمد إلى لندن لأول مرة.',
        'استغرقت الرحلة الجوية أربع ساعات، وكان متوتراً في المطار.',
        'في المدينة زار متحفاً شهيراً وتدرب على الإنجليزية مع أهلها.',
        'يقول إن السفر أفضل معلم، ويريد العودة السنة القادمة.',
      ],
      questions: [
        ReadingQuestion('كم استغرقت الرحلة الجوية؟',
            ['أربع ساعات', 'ست ساعات', 'ساعتين'], 0),
        ReadingQuestion('مع من تدرّب أحمد على الإنجليزية؟',
            ['مع الطيارين', 'مع أهل المدينة', 'مع عائلته'], 1),
      ],
    ),
    ReadingText(
      'rd_en_career',
      'en',
      'B2',
      'مسار سارة المهني',
      'Sara\'s Career',
      'Sara works for a large company in the city center. Her salary is '
          'good, but the schedule is busy and the pressure is real. Last '
          'month, she got a promotion and now manages a small team. She '
          'believes the secret of success is patience, honest work, and '
          'respect for colleagues.',
      [
        'تعمل سارة في شركة كبيرة في وسط المدينة.',
        'راتبها جيد، لكن جدولها مزدحم والضغط حقيقي.',
        'الشهر الماضي حصلت على ترقية وتدير الآن فريقاً صغيراً.',
        'تعتقد أن سر النجاح هو الصبر والعمل الأمين واحترام الزملاء.',
      ],
      questions: [
        ReadingQuestion('ماذا حصلت عليه سارة الشهر الماضي؟',
            ['ترقية', 'وظيفة جديدة', 'إجازة طويلة'], 0),
        ReadingQuestion('ماذا تدير سارة الآن؟',
            ['مكتباً في بيتها', 'شركة كاملة', 'فريقاً صغيراً'], 2),
      ],
    ),
    // ---------- German ----------
    ReadingText(
      'rd_de_arbeit',
      'de',
      'B1',
      'علي في العمل',
      'Alis neue Arbeit',
      'Ali hat eine neue Arbeit in einem Büro gefunden. Er beginnt um '
          'neun Uhr und endet um fünf. Nach der Arbeit geht er ins '
          'Fitnessstudio oder liest in der Bibliothek. Am Wochenende '
          'besucht er seine Familie und kocht für alle.',
      [
        'وجد علي عملاً جديداً في مكتب.',
        'يبدأ العمل في التاسعة وينتهي في الخامسة.',
        'بعد العمل يذهب إلى النادي الرياضي أو يقرأ في المكتبة.',
        'في نهاية الأسبوع يزور عائلته ويطبخ للجميع.',
      ],
      questions: [
        ReadingQuestion('متى يبدأ علي عمله؟',
            ['في التاسعة', 'في الثامنة', 'في العاشرة'], 0),
        ReadingQuestion('ماذا يفعل علي في نهاية الأسبوع؟',
            ['يسافر بعيداً', 'يعمل في المكتب', 'يزور عائلته ويطبخ للجميع'], 2),
      ],
    ),
    ReadingText(
      'rd_de_umwelt',
      'de',
      'B2',
      'البيئة تبدأ منك',
      'Umwelt beginnt bei dir',
      'Die Umwelt ist vielen Menschen heutzutage wichtig. Manche fahren '
          'mit dem Fahrrad zur Arbeit, andere kaufen regionale Produkte '
          'und sparen Energie. In unserer Stadt gibt es jetzt mehr '
          'Fahrradwege und weniger Abfall. Jeder kann einen kleinen '
          'Beitrag leisten, und zusammen zählt jeder Beitrag.',
      [
        'البيئة مهمة لكثير من الناس اليوم.',
        'بعضهم يذهب إلى العمل بالدراجة، وآخرون يشترون منتجات محلية ويوفرون الطاقة.',
        'في مدينتنا توجد الآن مسارات دراجات أكثر ونفايات أقل.',
        'يمكن للجميع أن يقدم مساهمة صغيرة، ومعاً تحسب كل مساهمة.',
      ],
      questions: [
        ReadingQuestion('كيف يذهب بعض الناس إلى العمل؟',
            ['بالدراجة', 'بالقارب', 'بالطائرة'], 0),
        ReadingQuestion(
            'ما الجديد في المدينة الآن؟',
            [
              'طرق أكثر ونفايات أكثر',
              'مسارات أقل وحدائق أقل',
              'مسارات دراجات أكثر ونفايات أقل'
            ],
            2),
      ],
    ),
    // ---------- French ----------
    ReadingText(
      'rd_fr_etudes',
      'fr',
      'B1',
      'دراسة كريم',
      'Les études de Karim',
      'Karim étudie l\'informatique à l\'université. Il a des cours le '
          'matin et travaille l\'après-midi dans un petit café. Ses '
          'professeurs sont exigeants mais justes. Il espère trouver un '
          'bon emploi l\'année prochaine et rester près de sa famille.',
      [
        'يدرس كريم علوم الحاسوب في الجامعة.',
        'لديه دروس في الصباح ويعمل بعد الظهر في مقهى صغير.',
        'أساتذته مطلبون لكنهم منصفون.',
        'يأمل أن يجد عملاً جيداً السنة القادمة ويبقى قرب عائلته.',
      ],
      questions: [
        ReadingQuestion('ماذا يدرس كريم في الجامعة؟',
            ['الحقوق', 'علوم الحاسوب', 'الطب'], 1),
        ReadingQuestion('أين يعمل كريم بعد الظهر؟',
            ['في مقهى صغير', 'في مطعم كبير', 'في مكتبة'], 0),
      ],
    ),
    ReadingText(
      'rd_fr_voyage',
      'fr',
      'B2',
      'رحلة إلى الجنوب',
      'Voyage dans le sud',
      'L\'année dernière, nous avons visité le sud de la France. Nous '
          'avons loué une voiture et découvert de petits villages sur la '
          'colline. Le climat était chaud, la nourriture délicieuse et '
          'les gens très accueillants. Ce voyage reste notre meilleur '
          'souvenir de famille.',
      [
        'في السنة الماضية زرنا جنوب فرنسا.',
        'استأجرنا سيارة واكتشفنا قرى صغيرة على التلة.',
        'كان المناخ حاراً والطعام لذيذاً والناس ترحيبيين جداً.',
        'تبقى هذه الرحلة أجمل ذكرى عائلية لنا.',
      ],
      questions: [
        ReadingQuestion('ماذا استأجرت العائلة؟', ['شقة', 'سيارة', 'دراجات'], 1),
        ReadingQuestion('أين كانت القرى الصغيرة؟',
            ['على التلة', 'في الغابة', 'على الشاطئ'], 0),
      ],
    ),
    // ---------- Urdu ----------
    ReadingText(
      'rd_ur_taleem',
      'ur',
      'B1',
      'تعليم علي',
      'علی کی تعلیم',
      'علی یونیورسٹی میں کمپیوٹر سائنس پڑھتا ہے۔ اس کے کلاس روم صبح کو '
          'ہوتے ہیں اور شام کو وہ کتابخانه میں پڑھتا ہے۔ اس کے استاد محنتی '
          'اور مہربان ہیں۔ وہ اگلے سال ایک اچھی نوکری چاہتا ہے۔',
      [
        'يدرس علي علوم الحاسوب في الجامعة.',
        'حصصه في الصباح ويقرأ في المكتبة في المساء.',
        'أساتذته مجتهدون ولطيفون.',
        'يريد وظيفة جيدة في السنة القادمة.',
      ],
      questions: [
        ReadingQuestion(
            'متى تكون حصص علي؟', ['بعد العشاء', 'في الصباح', 'في المساء'], 1),
        ReadingQuestion('ماذا يريد علي السنة القادمة؟',
            ['وظيفة جيدة', 'فتح متجر', 'السفر للخارج'], 0),
      ],
    ),
    ReadingText(
      'rd_ur_sehat',
      'ur',
      'B2',
      'الصحة أولاً',
      'صحت سب سے پہلے',
      'صحت ہر انسان کے لیے سب سے اہم چیز ہے۔ روزانہ ورزش اور اچھی غذا '
          'ضروری ہے۔ ڈاکٹر کہتے ہیں کہ کافی سونا بھی جسم کے لیے ضروری ہے۔ '
          'ہمیں چاہیے کہ زیادہ پانی پیں اور فون کا استعمال کم کریں۔',
      [
        'الصحة أهم شيء لكل إنسان.',
        'الرياضة اليومية والغذاء الجيد ضروريان.',
        'يقول الأطباء إن النوم الكافي ضروري أيضاً للجسد.',
        'ينبغي أن نشرب ماءً أكثر ونقلل استخدام الهاتف.',
      ],
      questions: [
        ReadingQuestion('ماذا يقول الأطباء عن النوم؟',
            ['ضار بالجسد', 'الكافي منه ضروري للجسد', 'غير مهم إطلاقاً'], 1),
        ReadingQuestion('مما ينبغي أن نقلل؟',
            ['الرياضة', 'شرب الماء', 'استخدام الهاتف'], 2),
      ],
    ),
  ];

  static List<ReadingText> forCourse(String courseId) =>
      texts.where((t) => t.courseId == courseId).toList();

  static ReadingText? byId(String id) {
    for (final t in texts) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Finds a course vocab entry whose target matches the tapped token
  /// (case-insensitive, surrounding punctuation stripped). Returns null
  /// for words outside the corpus — the caller shows an honest "not in
  /// the course" sheet rather than inventing a meaning.
  static Vocab? lookup(Course course, String rawToken) {
    final token =
        rawToken.replaceAll(RegExp(r'[^\w\u0600-\u06FF\u00C0-\u024F]'), '');
    if (token.isEmpty) return null;
    final lower = token.toLowerCase();
    for (final v in course.allVocab) {
      if (v.target.toLowerCase() == lower) return v;
    }
    // plural-ish fallback: strip a trailing 's' for Latin courses
    if (lower.endsWith('s') && lower.length > 3) {
      final stem = lower.substring(0, lower.length - 1);
      for (final v in course.allVocab) {
        if (v.target.toLowerCase() == stem) return v;
      }
    }
    return null;
  }

  /// Catalog sanity: unique ids, real courses, aligned-ish Arabic
  /// sentences (at least half the body sentence count), non-empty bodies.
  static bool verify() {
    final seen = <String>{};
    const courseIds = {'en', 'fr', 'de', 'ur'};
    for (final t in texts) {
      if (!seen.add(t.id)) return false;
      if (!courseIds.contains(t.courseId)) return false;
      if (t.body.trim().isEmpty) return false;
      final s = t.sentences();
      if (s.length < 3) return false;
      if (t.sentencesAr.length < (s.length / 2).floor()) return false;
      if (t.sentencesAr.any((a) => a.trim().isEmpty)) return false;
    }
    return true;
  }
}
