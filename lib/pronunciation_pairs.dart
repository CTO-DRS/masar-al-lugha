// Confusable sound pairs (v5.16, Q4/F4.4): per-course curated pairs of
// REAL corpus words that differ by one sound/spelling step — the classic
// pronunciation-practice fodder (lait/lit, ش/ه,Nein/neun). Every pair
// references targets that actually exist in the course JSON, so the
// pronunciation screen can resolve both sides to real Vocab entries; a
// catalog test pins that invariant (a pair pointing at a missing word is
// a broken promise to the learner).
//
// HONEST SCOPE: pairs are spelling-neighbor pairs (edit-distance one)
// chosen for sound contrast; the screen's scoring stays the same
// approximate transcript comparison as any word practice.
class PronPair {
  final String id;
  final String courseId;
  final String a;
  final String b;

  /// One-line Arabic hint: WHAT to listen for, not a lecture.
  final String hintAr;
  const PronPair(this.id, this.courseId, this.a, this.b, this.hintAr);
}

class PronPairCatalog {
  PronPairCatalog._();

  static const List<PronPair> pairs = [
    // ---------- English ----------
    PronPair('pp_en_along_among', 'en', 'Along', 'Among',
        'الفرق حرف واحد يغيّر المعنى كلياً: على طول / بين.'),
    PronPair('pp_en_ant_art', 'en', 'Ant', 'Art', 'نضيف r بعد a: نملة / فن.'),
    PronPair('pp_en_bag_big', 'en', 'Bag', 'Big',
        'صوت a قصير مقابل i: حقيبة / كبير.'),
    PronPair('pp_en_beach_peach', 'en', 'Beach', 'Peach',
        'b مقابل p في البداية: شاطئ / خوخة.'),
    PronPair('pp_en_band_sand', 'en', 'Band', 'Sand', 'b مقابل s: فرقة / رمل.'),
    PronPair('pp_en_batter_butter', 'en', 'Batter', 'Butter',
        'a مقابل u في الوسط: عجينة / زبدة.'),
    PronPair(
        'pp_en_back_black', 'en', 'Back', 'Black', 'l يغير الصوت: ظهر / أسود.'),
    PronPair(
        'pp_en_beak_weak', 'en', 'Beak', 'Weak', 'b مقابل w: منقار / ضعيف.'),
    // ---------- French ----------
    PronPair('pp_fr_amer_aimer', 'fr', 'Amer', 'aimer',
        'حرف a يضاف في البداية: مرّ / يحب.'),
    PronPair(
        'pp_fr_lait_lit', 'fr', 'lait', 'lit', 'صوت é مقابل i: حليب / سرير.'),
    PronPair(
        'pp_fr_mer_mere', 'fr', 'mer', 'mère', 'الهمزة تقلب المعنى: بحر / أم.'),
    PronPair('pp_fr_sel_sol', 'fr', 'sel', 'sol', 'e مقابل o: ملح / أرض.'),
    PronPair('pp_fr_soif_soir', 'fr', 'soif', 'soir',
        'f مقابل r في النهاية: عطش / مساء.'),
    PronPair(
        'pp_fr_fille_ville', 'fr', 'fille', 'ville', 'f مقابل v: بنت / مدينة.'),
    PronPair(
        'pp_fr_cuit_nuit', 'fr', 'Cuit', 'nuit', 'c مقابل n: مطبوخ / ليل.'),
    PronPair('pp_fr_jouer_jour', 'fr', 'jouer', 'jour',
        'er ساكنة النهاية: يلعب / يوم.'),
    // ---------- German ----------
    PronPair('pp_de_nein_neun', 'de', 'Nein', 'neun', 'i مقابل eu: لا / تسعة.'),
    PronPair('pp_de_alt_kalt', 'de', 'alt', 'kalt', 'a مقابل ka: قديم / بارد.'),
    PronPair('pp_de_backen_packen', 'de', 'backen', 'packen',
        'b مقابل p: يخبز / يحزم.'),
    PronPair('pp_de_fahren_fuhren', 'de', 'fahren', 'führen',
        'a مقابل ü: يقود سيارة / يقود إدارة.'),
    PronPair(
        'pp_de_heiss_weiss', 'de', 'heiß', 'weiß', 'h مقابل w: ساخن / أبيض.'),
    PronPair('pp_de_lieben_sieben', 'de', 'lieben', 'sieben',
        'l مقابل s: يحب / سبعة.'),
    PronPair('pp_de_sauber_sauer', 'de', 'sauber', 'sauer',
        'b مقابل r في النهاية: نظيف / حامض.'),
    PronPair('pp_de_neu_neun', 'de', 'neu', 'neun',
        'n واحدة مقابل n+e: جديد / تسعة.'),
    // ---------- Urdu ----------
    PronPair('pp_ur_asptal_hasptal', 'ur', 'اسپتال', 'ہسپتال',
        'ركّز على صوت السين مقابل الهاء في أول الكلمة.'),
    PronPair('pp_ur_alu_aaru', 'ur', 'آلو', 'آڑو', 'ل مقابل ڑ: بطاطس / خوخ.'),
    PronPair('pp_ur_oont_aint', 'ur', 'اونٹ', 'اینٹ',
        'o مقابل ai في البداية: جمل / طوب.'),
    PronPair('pp_ur_umeed_ameer', 'ur', 'امید', 'امیر',
        'd مقابل r في النهاية: أمل / غني.'),
    PronPair('pp_ur_anaar_inkaar', 'ur', 'انار', 'انکار',
        'الر مقابل الکاف: رمان / رفض.'),
    PronPair(
        'pp_ur_aik_nek', 'ur', 'ایک', 'نیک', 'n تُبدّل المعنى: واحد / صالح.'),
    PronPair('pp_ur_baeen_baeleen', 'ur', 'بائیں', 'بالیں',
        'ي مقابل ل: يسار / أذرع.'),
    PronPair(
        'pp_ur_anda_panda', 'ur', 'انڈا', 'پانڈا', 'ان مقابل پان: بيضة / دب.'),
  ];

  static List<PronPair> forCourse(String courseId) =>
      pairs.where((p) => p.courseId == courseId).toList();

  /// Resolves the pair side to a corpus Vocab (null when the target is
  /// not a real single word in this course — the UI filters those out).
  static bool resolvable(Iterable<String> targets, PronPair p) =>
      targets.contains(p.a.toLowerCase()) &&
      targets.contains(p.b.toLowerCase());
}
