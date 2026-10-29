// Grammar module (v5.7, Phase 4 skill 2): short contrastive lessons that
// compare the target language's rule with Arabic, each closed by quick
// multiple-choice drills. Content lives here as DATA (not course JSON) so
// it can ship without touching the append-only course corpora.
//
// HONEST LABEL: all explanations and drills are machine-authored and need
// human review (see docs/CONTENT_AUDIT.md). No CEFR certification is
// claimed; the level tag is self-referenced like the unit ladder.

class GrammarDrill {
  final String prompt; // sentence with ____ blank
  final List<String> options;
  final int correct;
  final String explainAr; // one-line why, in Arabic
  const GrammarDrill(this.prompt, this.options, this.correct, this.explainAr);
}

class GrammarLesson {
  final String id;
  final String courseId;
  final String level; // self-referenced band tag
  final String titleAr;
  final String titleEn;
  final List<String> pointsAr; // short contrastive bullets vs Arabic
  final List<GrammarDrill> drills;
  const GrammarLesson(this.id, this.courseId, this.level, this.titleAr,
      this.titleEn, this.pointsAr, this.drills);
}

class GrammarCatalog {
  GrammarCatalog._();

  /// Per-course lessons — 2 per course in this first wave (honest scope:
  /// a starter set, grown in later waves). Ids are namespaced `gr_` and
  /// never collide with course vocab ids.
  static const List<GrammarLesson> lessons = [
    // ---------- English ----------
    GrammarLesson(
      'gr_en_articles',
      'en',
      'A1',
      'أدوات التعريف a / an / the',
      'Articles: a / an / the',
      [
        'العربية لا تملك أداة تعريف نكرة، بينما الإنجليزية تستخدم a قبل الحرف الساكن وan قبل حرف العلة (an apple).',
        'the للمعرّف أو المذكور سابقاً: I saw a cat. The cat was black.',
        'لا تُستخدم أداة مع أسماء الأكلات العامة بالجمع: I like apples (لا the apples).',
      ],
      [
        GrammarDrill('I ate ____ apple this morning.', ['a', 'the', 'an'], 2,
            'apple تبدأ بحرف علة إذن an.'),
        GrammarDrill('____ sun rises in the east.', ['The', 'An', 'A'], 0,
            'الشمس شيء فريد — نستخدم the.'),
        GrammarDrill('She bought ____ new phone.', ['the', 'an', 'a'], 2,
            'new تبدأ بحرف ساكن إذن a.'),
        GrammarDrill(
            'We saw ____ movie. ____ movie was great!',
            ['a / The', 'A / A', 'The / A'],
            0,
            'نكرة أول ذكر ثم the عند الإعادة.'),
      ],
    ),
    GrammarLesson(
      'gr_en_third_person',
      'en',
      'A1',
      'المضارع البسيط مع المفرد الغائب',
      'Present simple: he/she/it + s',
      [
        'الفعل يأخذ s مع he/she/it: He plays (لا He play) — العربية لا تغيّر الفعل بهذا الشكل بل بالضمائر.',
        'النفي والسؤال يستخدمان does ويعود الفعل مجرداً: He does not play. Does he play?',
        'الأفعال المنتهية بـo/ch/sh تضاف es: goes, watches.',
      ],
      [
        GrammarDrill('My brother ____ to school every day.',
            ['going', 'go', 'goes'], 2, 'brother مفرد غائب → goes.'),
        GrammarDrill('She ____ not like coffee.', ['does', 'do', 'is'], 0,
            'النفي مع المفرد الغائب بـdoes not.'),
        GrammarDrill('____ he watch TV at night?', ['Do', 'Is', 'Does'], 2,
            'السؤال مع he يحتاج Does والفعل مجرداً.'),
        GrammarDrill('Ahmad ____ his homework after dinner.',
            ['does', 'do', 'dos'], 0, 'do تنتهي بـo → does.'),
      ],
    ),
    // ---------- German ----------
    GrammarLesson(
      'gr_de_der_die_das',
      'de',
      'A1',
      'جنس الاسم: der / die / das',
      'Noun gender: der / die / das',
      [
        'لكل اسم ألماني جنس ثابت يجب حفظه مع الاسم نفسه — العربية ليس لها هذا التمايز (هو/هي للعاقل فقط).',
        'der مذكر، die مؤنث (وجمع)، das محيّد — الجنس يغيّر أدوات الإعراب كلها لاحقاً.',
        'لوائح مساعدة: الأسماء المنتهية بـ-ung/-heit/-schaft مؤنثة die، والمتناهية بـ-chen محيّدة das.',
      ],
      [
        GrammarDrill('____ Lampe ist neu.', ['Der', 'Die', 'Das'], 1,
            'المنتهية بـ-e غالباً مؤنث → die Lampe.'),
        GrammarDrill('____ Mädchen spielt.', ['Das', 'Die', 'Der'], 0,
            'المنتهية بـ-chen محيّد دائماً رغم معناه.'),
        GrammarDrill('____ Zeitung liegt dort.', ['Das', 'Der', 'Die'], 2,
            'المنتهية بـ-ung مؤنث → die Zeitung.'),
        GrammarDrill('____ Tisch ist braun.', ['Die', 'Der', 'Das'], 1,
            'Tisch مذكر محفوظ → der.'),
      ],
    ),
    GrammarLesson(
      'gr_de_v2_order',
      'de',
      'A2',
      'الفعل في المركز الثاني',
      'Verb-second (V2) word order',
      [
        'في الجملة الخبرية يأتي الفعل المصرّف في المركز الثاني حرفياً أياً كان ما بدأت به — العربية ترتب فاعلاً ثم فعلاً غالباً.',
        'Heute gehe ich ins Kino. — اليوم بدأت بـHeute فجاء الفعل ثانياً ثم الفاعل.',
        'في السؤال بأداة استفهام يبقى الفعل ثانياً: Warum kommst du nicht?',
      ],
      [
        GrammarDrill(
            'Morgen ____ wir nach Berlin.',
            ['fahren', 'wir fahren', 'fahren wir'],
            2,
            'Morgen أولًا → الفعل الثاني ثم الفاعل.'),
        GrammarDrill(
            'Ich ____ heute lange arbeiten.',
            ['muss ich', 'muss', 'heute muss'],
            1,
            'Ich أولًا → الفعل musss ثانياً مباشرة.'),
        GrammarDrill(
            'Warum ____ du so spät?',
            ['du kommst', 'kommst', 'kommst du'],
            2,
            'السؤال: أداة الاستفهام ثم الفعل ثم الفاعل.'),
        GrammarDrill(
            'Am Sonntag ____ meine Mutter kochen.',
            ['will', 'meine Mutter will', 'will meine Mutter'],
            0,
            'الظرف أولًا → الفعل second.'),
      ],
    ),
    // ---------- French ----------
    GrammarLesson(
      'gr_fr_articles',
      'fr',
      'A1',
      'أدوات التعريف le / la / les',
      'Definite articles: le / la / les',
      [
        'الفرنسية تفرّق الجنس كما تفعل الإشارة في العربية (هذا/هذه) لكن لكل اسم: le مذكر، la مؤنث، les للجمع بلا تفرقة جنس.',
        'قبل حرف العلة تُختصر: le + ami → l\'ami، la + école → l\'école.',
        'de + le → du و de + les → des (أدوات نكرة جزئية لاحقاً).',
      ],
      [
        GrammarDrill('____ livre est intéressant.', ['La', 'Le', 'Les'], 1,
            'livre مذكر → le livre.'),
        GrammarDrill('____ école est grande.', ['La', 'Le', "L'"], 2,
            'école تبدأ بحرف علة → l\'école.'),
        GrammarDrill('____ enfants jouent ici.', ['Les', 'Le', 'La'], 0,
            'جمع → les بلا تفرقة.'),
        GrammarDrill('____ maison est blanche.', ['Le', 'La', 'Les'], 1,
            'maison مؤنث → la.'),
      ],
    ),
    GrammarLesson(
      'gr_fr_negation',
      'fr',
      'A2',
      'النفي ne … pas',
      'Negation: ne … pas',
      [
        'النفي الفرنسي محيط بالفعل: ne قبل الفعل وpas بعده — بينما العربية تكفيها ما/لا واحدة قبل الفعل.',
        'Je parle → Je ne parle pas. مع المذكّر الصوتي: ne تتحول n\' قبل حرف العلة: Je n\'aime pas.',
        'في المضارع يُنفي الفعل المصرّف فقط لا المصدر: Il ne veut pas manger.',
      ],
      [
        GrammarDrill('Je ____ comprends pas.', ["n'", 'pas', 'ne'], 2,
            'comprends تبدأ بحرف ساكن → ne.'),
        GrammarDrill("Il ____ aime pas le café.", ["n'", 'pas', 'ne'], 0,
            'aime تبدأ بحرف علة → n\'aime.'),
        GrammarDrill('Elle ne parle ____ anglais.', ['non', 'pas', 'ne'], 1,
            'pas تأتي بعد الفعل.'),
        GrammarDrill(
            'Nous ne ____ pas ici.',
            ['habitons', 'pas habitons', 'habiter'],
            0,
            'النفي يحيط بالفعل المصرّف.'),
      ],
    ),
    // ---------- Urdu ----------
    GrammarLesson(
      'gr_ur_ergative',
      'ur',
      'A2',
      'بنية الماضي الفاعلية: نے',
      'Ergative past: نے',
      [
        'في الماضي المتعدي يصبح الفاعل مرفوعاً بعلامة نے والفعل يطابق المفعول في الجنس والعدد — خلافاً للعربية حيث يطابق الفعل الفاعل.',
        'لڑکے نے کتاب پڑھی — الفعل پڑھی يوافق کتاب (مؤنث) لا لڑکا (مذكر).',
        'الأفعال اللازمة تستثنى: لڑکا گیا (بلا نے) والفعل يوافق الفاعل.',
      ],
      [
        GrammarDrill('بچے نے سیب ____ ۔', ['کھائے', 'کھایا', 'کھائی'], 1,
            'سیب مذكر مفرد → کھایا يوافق المفعول.'),
        GrammarDrill('علی نے کتابیں ____ ۔', ['خریدی', 'خریدا', 'خریدیاں'], 2,
            'کتابیں مؤنث جمع → خریدیاں.'),
        GrammarDrill(
            'لڑکی گئی — لماذا لا تظهر نے؟',
            ['لأن الفعل لازم بلا نے', 'لأن لڑکی مؤنثة', 'خطأ إملائي'],
            0,
            'الأفعال اللازمة تبقى بلا نے والفعل يوافق الفاعل.'),
        GrammarDrill('مجھے ____ نے خط لکھا۔', ['والدہ', 'والد', 'والدین'], 1,
            'خط مذكر → الفعل يوافقه لا الفاعل؛ والد مذكر مناسب هنا.'),
      ],
    ),
    GrammarLesson(
      'gr_ur_postpositions',
      'ur',
      'A1',
      'الاحرف بعد الاسم: کو / میں / سے',
      'Urdu postpositions',
      [
        'الأردية تضع الحرف الإضافي بعد الاسم لا قبله: مائز پر (على الطاولة) — عكس العربية التي تستخدم حروف جر سابقة.',
        'کو للمصدر/الغاية، میں للمكان، سے للأداة أو الانطلاق، پر للسطح.',
        'الاسم يبقى بحالته الإضافية Oblique مع هذه الحروف: گھر میں، لڑکے کو (لا لڑکا کو).',
      ],
      [
        GrammarDrill(
            'کتاب میز ____ ہے۔', ['پر', 'کو', 'سے'], 0, 'على السطح → پر.'),
        GrammarDrill('میں اسکول ____ جا رہا ہوں۔', ['پر', 'کو', 'میں'], 1,
            'الغاية → اسکول کو.'),
        GrammarDrill('لڑکے ____ کتاب دو۔', ['میں', 'پر', 'کو'], 2,
            'المفعول به الغائب → کو مع الحالة الإضافية.'),
        GrammarDrill('وہ دہلی ____ آیا۔', ['سے', 'کو', 'میں'], 0,
            'الانطلاق من مكان → سے.'),
      ],
    ),
    // ---------- v5.16 (Q4/F4.2): B1/B2 depth for every course ----------
    // ---------- English ----------
    GrammarLesson(
      'gr_en_past_simple',
      'en',
      'B1',
      'الماضي البسيط',
      'Past simple',
      [
        'الأفعال النظامية تأخذ ed في الماضي: watched, played — والأفعال الشاذة تُحفظ كما هي: go → went, see → saw.',
        'النفي والسؤال يستخدمان did ويعود الفعل مجرداً: I did not go. Did you go?',
        'الكلمات الدالة: yesterday, last week, two days ago, in 2020.',
      ],
      [
        GrammarDrill('Yesterday we ____ to the market.', ['go', 'gone', 'went'],
            2, 'go فعل شاذ: ماضيه went.'),
        GrammarDrill('She ____ not come to class last week.',
            ['did', 'is', 'does'], 0, 'النفي في الماضي بـdid not.'),
        GrammarDrill('I ____ my keys last night.', ['losed', 'lost', 'lose'], 1,
            'lose فعل شاذ: ماضيه lost.'),
        GrammarDrill('Did you ____ the film yesterday?',
            ['watch', 'watched', 'watches'], 0, 'بعد Did يعود الفعل مجرداً.'),
      ],
    ),
    GrammarLesson(
      'gr_en_conditionals',
      'en',
      'B2',
      'جمل الشرط: النوع الأول والثاني',
      'Conditionals: first & second',
      [
        'النوع الأول (واقع): If + مضارع بسيط → will + مصدر. If it rains, we will stay home.',
        'النوع الثاني (افتراضي): If + ماضي بسيط → would + مصدر. If I were rich, I would travel.',
        'في النوع الثاني نفضّل were مع جميع الضمائر: If I were you…',
      ],
      [
        GrammarDrill(
            'If it rains tomorrow, we ____ stay home.',
            ['would', 'will', 'would have'],
            1,
            'شرط واقع → will (النوع الأول).'),
        GrammarDrill('If I ____ rich, I would travel the world.',
            ['were', 'am', 'was'], 0, 'النوع الثاني يفضل were مع كل الضمائر.'),
        GrammarDrill('If you study hard, you ____ pass the exam.',
            ['would', 'will', 'would be'], 1, 'شرط واقع وممكن → will.'),
        GrammarDrill(
            'If he had more time, he ____ help you.',
            ['would', 'will', 'does'],
            0,
            'افتراض غير واقع → would (النوع الثاني).'),
      ],
    ),
    // ---------- German ----------
    GrammarLesson(
      'gr_de_perfekt',
      'de',
      'B1',
      'الماضي المركّب Perfekt',
      'Perfect tense (Perfekt)',
      [
        'الماضي المحكي الشائع: haben أو sein في المركز الثاني + Partizip II في النهاية: Ich habe gegessen.',
        'نستخدم sein مع أفعال الحركة والتغيّر: gehen, fahren, kommen — وhaben مع الباقي.',
        'أفعال نظامية تأخذ ge…t: gemacht، والشاذة غالباً ge…en: gegangen.',
      ],
      [
        GrammarDrill('Ich ____ nach Berlin gefahren.', ['ist', 'bin', 'habe'],
            1, 'fahren فعل حركة → sein.'),
        GrammarDrill('Wir ____ Pizza gegessen.', ['haben', 'sind', 'sein'], 0,
            'essen ليس حركة → haben.'),
        GrammarDrill('Sie ____ gestern spät gekommen.', ['habe', 'ist', 'hat'],
            1, 'kommen فعل حركة → ist.'),
        GrammarDrill('Er ____ die Hausaufgaben gemacht.',
            ['haben', 'ist', 'hat'], 2, 'machen فعل عادي → hat.'),
      ],
    ),
    GrammarLesson(
      'gr_de_relativ',
      'de',
      'B2',
      'الجمل الموصولة',
      'Relativsätze',
      [
        'الضمير الموصول der/die/das يطابق جنس الاسم وعدده، وحالته تتبع وظيفته داخل الجملة الموصولة.',
        'الفعل يذهب إلى نهاية الجملة الموصولة: Der Mann, der dort steht, ist mein Onkel.',
        'المفعول به يصبح den/die/das، وبعد حروف الجر تتغير الأداة (dem/der).',
      ],
      [
        GrammarDrill('Der Mann, ____ dort steht, ist mein Onkel.',
            ['den', 'der', 'dem'], 1, 'الفاعل مذكر → der.'),
        GrammarDrill('Die Frau, ____ ich kenne, lehrt Deutsch.',
            ['die', 'den', 'dem'], 0, 'مفعول به مؤنث → die.'),
        GrammarDrill('Das Buch, ____ ich lese, ist spannend.',
            ['dem', 'das', 'den'], 1, 'مفعول به محيّد → das.'),
        GrammarDrill('Der Freund, ____ ich helfe, wohnt hier.',
            ['den', 'der', 'dem'], 2, 'helfen تأخذ Dativ → dem.'),
      ],
    ),
    // ---------- French ----------
    GrammarLesson(
      'gr_fr_passe_compose',
      'fr',
      'B1',
      'الماضي المركّب',
      'Passé composé',
      [
        'الماضي المركّب = avoir أو être + participe passé: J\'ai mangé. Je suis allé.',
        'نستخدم être مع أفعال الحركة (aller, venir, partir) والأفعال الانعكاسية (se lever).',
        'مع être يوافق الاسم اللاحق في الجنس والعدد: Elle est allée. Ils sont partis.',
      ],
      [
        GrammarDrill('J\'____ mangé une pomme.', ['vais', 'ai', 'suis'], 1,
            'manger تأخذ avoir → j\'ai mangé.'),
        GrammarDrill('Elle ____ allée au marché.', ['va', 'a', 'est'], 2,
            'aller تأخذ être + توافق مؤنث → allée.'),
        GrammarDrill('Nous avons ____ un film.', ['voir', 'vu', 'voyu'], 1,
            'participe passé de voir → vu.'),
        GrammarDrill('Ils se ____ levés très tôt.', ['sont', 'ont', 'ont eu'],
            0, 'فعل انعكاسي → être → sont.'),
      ],
    ),
    GrammarLesson(
      'gr_fr_pronoms',
      'fr',
      'B2',
      'الضمائر المفعولية',
      'Pronoms compléments',
      [
        'le / la / les للمفعول المباشر، وlui / leur للمفعول غير المباشر بعد à (à lui / à eux).',
        'مكان الضمير قبل الفعل دائماً: Je te vois. Je lui parle.',
        'النفي يحيط بالفعل والضمير معاً: Je ne le vois pas.',
      ],
      [
        GrammarDrill('Tu vois Marie ? — Oui, je ____ vois.',
            ['lui', 'la', 'le'], 1, 'Marie مؤنث مفعول مباشر → la.'),
        GrammarDrill('Je parle à Paul. Je ____ parle souvent.',
            ['lui', 'leur', 'le'], 0, 'parler à → غير مباشر مفرد → lui.'),
        GrammarDrill('Les livres ? Je ____ lis ce soir.', ['la', 'leur', 'les'],
            2, 'مفعول مباشر جمع → les.'),
        GrammarDrill('Elle écrit à ses parents. Elle ____ écrit.',
            ['leur', 'les', 'lui'], 0, 'à ses parents جمع → leur.'),
      ],
    ),
    // ---------- Urdu ----------
    GrammarLesson(
      'gr_ur_past',
      'ur',
      'B1',
      'الماضي المطلق',
      'ماضی مطلق',
      [
        'يُبنى الماضي بحذف نا من المصدر وإضافة حرف بحسب الجنس: کھانا → کھایا (مذكر) / کھائی (مؤنث).',
        'مع فاعل جمع يأتي النهاية بـے: ہم نے کھائے.',
        'الفاعل المفعولي يأخذ نے: لڑکے نے کتاب پڑھی.',
      ],
      [
        GrammarDrill('میں نے کھانا ____ ۔', ['کھائی', 'کھایا', 'کھائے'], 1,
            'کھانا مذكر → کھایا.'),
        GrammarDrill(
            'اس نے چائے ____ ۔', ['پیا', 'پینا', 'پی'], 2, 'چائے مؤنث → پی.'),
        GrammarDrill('ہم نے فلم ____ ۔', ['دیکھی', 'دیکھے', 'دیکھا'], 0,
            'فلم مؤنث → دیکھی.'),
        GrammarDrill(
            'اس نے خط ____ ۔', ['لکھی', 'لکھے', 'لکھا'], 2, 'خط مذكر → لکھا.'),
      ],
    ),
    GrammarLesson(
      'gr_ur_shart',
      'ur',
      'B2',
      'الجمل الشرطية',
      'شرطی جملے',
      [
        'الشرط الواقعي: اگر + مضارع … تو + مستقبل: اگر بارش ہو تو ہم جائیں گے.',
        'الشرط الافتراضي: اگر + ماضي … تو + ماضي استمراري: اگر میں امیر ہوتا تو سفر کرتا.',
        'تتفق الاردو مع العربية في ترتيب الشرط والجواب مع تو في الوسط.',
      ],
      [
        GrammarDrill('اگر بارش ہو تو ہم ____ ۔', ['جائیں گے', 'جاتے', 'گئے'], 0,
            'شرط واقع → مستقبل.'),
        GrammarDrill('اگر میں امیر ہوتا تو سفر ____ ۔',
            ['کیا', 'کرتا', 'کروں گا'], 1, 'شرط افتراضي → ماضي استمراري.'),
        GrammarDrill('اگر تم پڑھو گے تو کامیاب ____ ۔',
            ['ہو گا', 'ہوتی', 'ہو گے'], 2, 'جمع مخاطب → ہو گے.'),
        GrammarDrill('اگر وہ آتا تو میں خوش ____ ۔', ['ہوتا', 'ہوا', 'ہوں گا'],
            0, 'افتراض ماضٍ → ہوتا.'),
      ],
    ),
  ];

  /// Lessons for a course, in catalog order.
  static List<GrammarLesson> forCourse(String courseId) =>
      lessons.where((l) => l.courseId == courseId).toList();

  /// Finds a lesson by id (null-safe for foreign/tampered ids).
  static GrammarLesson? byId(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Catalog-wide sanity: every lesson has content, drills are
  /// well-formed, ids are unique, and course ids are real course ids.
  static bool verify() {
    final seen = <String>{};
    const courseIds = {'en', 'fr', 'de', 'ur'};
    for (final l in lessons) {
      if (!seen.add(l.id)) return false;
      if (!courseIds.contains(l.courseId)) return false;
      if (l.pointsAr.isEmpty || l.drills.isEmpty) return false;
      if (l.titleAr.trim().isEmpty || l.titleEn.trim().isEmpty) return false;
      for (final d in l.drills) {
        if (d.correct < 0 || d.correct >= d.options.length) return false;
        if (!d.prompt.contains('____') && !d.prompt.contains('—')) {
          return false;
        }
        if (d.explainAr.trim().isEmpty) return false;
      }
    }
    return true;
  }
}
