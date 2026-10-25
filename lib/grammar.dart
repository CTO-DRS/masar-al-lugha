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
        GrammarDrill('I ate ____ apple this morning.', ['a', 'an', 'the'], 1,
            'apple تبدأ بحرف علة إذن an.'),
        GrammarDrill('____ sun rises in the east.', ['A', 'An', 'The'], 2,
            'الشمس شيء فريد — نستخدم the.'),
        GrammarDrill('She bought ____ new phone.', ['a', 'an', 'the'], 0,
            'new تبدأ بحرف ساكن إذن a.'),
        GrammarDrill(
            'We saw ____ movie. ____ movie was great!',
            ['a / The', 'The / A', 'A / A'],
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
            ['go', 'goes', 'going'], 1, 'brother مفرد غائب → goes.'),
        GrammarDrill('She ____ not like coffee.', ['do', 'does', 'is'], 1,
            'النفي مع المفرد الغائب بـdoes not.'),
        GrammarDrill('____ he watch TV at night?', ['Do', 'Does', 'Is'], 1,
            'السؤال مع he يحتاج Does والفعل مجرداً.'),
        GrammarDrill('Ahmad ____ his homework after dinner.',
            ['do', 'dos', 'does'], 2, 'do تنتهي بـo → does.'),
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
        GrammarDrill('____ Mädchen spielt.', ['Der', 'Die', 'Das'], 2,
            'المنتهية بـ-chen محيّد دائماً رغم معناه.'),
        GrammarDrill('____ Zeitung liegt dort.', ['Der', 'Die', 'Das'], 1,
            'المنتهية بـ-ung مؤنث → die Zeitung.'),
        GrammarDrill('____ Tisch ist braun.', ['Der', 'Die', 'Das'], 0,
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
            ['fahren wir', 'wir fahren', 'fahren'],
            0,
            'Morgen أولًا → الفعل الثاني ثم الفاعل.'),
        GrammarDrill(
            'Ich ____ heute lange arbeiten.',
            ['muss', 'muss ich', 'heute muss'],
            0,
            'Ich أولًا → الفعل musss ثانياً مباشرة.'),
        GrammarDrill(
            'Warum ____ du so spät?',
            ['du kommst', 'kommst du', 'kommst'],
            1,
            'السؤال: أداة الاستفهام ثم الفعل ثم الفاعل.'),
        GrammarDrill(
            'Am Sonntag ____ meine Mutter kochen.',
            ['will', 'will meine Mutter', 'meine Mutter will'],
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
        GrammarDrill('____ livre est intéressant.', ['Le', 'La', 'Les'], 0,
            'livre مذكر → le livre.'),
        GrammarDrill('____ école est grande.', ['Le', 'La', "L'"], 2,
            'école تبدأ بحرف علة → l\'école.'),
        GrammarDrill('____ enfants jouent ici.', ['Le', 'La', 'Les'], 2,
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
        GrammarDrill('Je ____ comprends pas.', ['ne', 'pas', "n'"], 0,
            'comprends تبدأ بحرف ساكن → ne.'),
        GrammarDrill("Il ____ aime pas le café.", ['ne', "n'", 'pas'], 1,
            'aime تبدأ بحرف علة → n\'aime.'),
        GrammarDrill('Elle ne parle ____ anglais.', ['ne', 'pas', 'non'], 1,
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
        GrammarDrill('بچے نے سیب ____ ۔', ['کھایا', 'کھائی', 'کھائے'], 0,
            'سیب مذكر مفرد → کھایا يوافق المفعول.'),
        GrammarDrill('علی نے کتابیں ____ ۔', ['خریدی', 'خریدیاں', 'خریدا'], 1,
            'کتابیں مؤنث جمع → خریدیاں.'),
        GrammarDrill(
            'لڑکی گئی — لماذا لا تظهر نے؟',
            ['لأن الفعل لازم بلا نے', 'لأن لڑکی مؤنثة', 'خطأ إملائي'],
            0,
            'الأفعال اللازمة تبقى بلا نے والفعل يوافق الفاعل.'),
        GrammarDrill('مجھے ____ نے خط لکھا۔', ['والد', 'والدہ', 'والدین'], 0,
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
        GrammarDrill('میں اسکول ____ جا رہا ہوں۔', ['کو', 'میں', 'پر'], 0,
            'الغاية → اسکول کو.'),
        GrammarDrill('لڑکے ____ کتاب دو۔', ['کو', 'میں', 'پر'], 0,
            'المفعول به الغائب → کو مع الحالة الإضافية.'),
        GrammarDrill('وہ دہلی ____ آیا۔', ['سے', 'کو', 'میں'], 0,
            'الانطلاق من مكان → سے.'),
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
