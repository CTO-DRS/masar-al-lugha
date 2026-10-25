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

class ReadingText {
  final String id;
  final String courseId;
  final String level; // self-referenced band tag
  final String titleAr;
  final String titleEn;
  final String body; // target-language text, sentence-split by [.!?؟۔]
  final List<String> sentencesAr; // aligned with body sentences (best effort)
  const ReadingText(this.id, this.courseId, this.level, this.titleAr,
      this.titleEn, this.body, this.sentencesAr);

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
