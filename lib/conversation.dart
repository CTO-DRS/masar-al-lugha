// Conversation trainer (v5.9, Phase 4 skill 4): a role-play chat behind a
// PROVIDER ABSTRACTION (`ConversationProvider`). The shipped provider is
// `OfflineScriptedProvider` — deterministic, on-device, NO network — so the
// feature works with zero connectivity and zero paid APIs (hard invariants).
// Any future AI provider implements the same 4-method interface; wiring it
// would be a user-facing decision because it touches the no-network rule.
//
// HONEST LABEL: the scripted dialogues are machine-authored ("needs human
// review", docs/CONTENT_AUDIT.md); the provider does keyword matching, not
// understanding — the UI says the evaluation is approximate.

class ConversationMsg {
  final bool fromPartner;
  final String text;
  final String? textAr;
  const ConversationMsg.partner(this.text, {this.textAr}) : fromPartner = true;
  const ConversationMsg.user(this.text)
      : fromPartner = false,
        textAr = null;
}

class ConversationStep {
  /// What the role-play partner says next (target language) + its Arabic.
  final String partner;
  final String partnerAr;

  /// Any-of keyword groups: the user's reply is ACCEPTED when at least one
  /// group's every keyword appears (normalized) in it.
  final List<List<String>> acceptAny;

  /// A good sample reply (shown as a hint) + its Arabic.
  final String sampleReply;
  final String sampleReplyAr;
  const ConversationStep(this.partner, this.partnerAr, this.acceptAny,
      this.sampleReply, this.sampleReplyAr);
}

class ConversationScenario {
  final String id;
  final String courseId;
  final String level; // self-referenced band tag
  final String titleAr;
  final String titleEn;
  final String emoji;
  final String roleAr; // who the partner plays
  final List<ConversationStep> steps;
  final String closing;
  final String closingAr;
  const ConversationScenario(
      this.id,
      this.courseId,
      this.level,
      this.titleAr,
      this.titleEn,
      this.emoji,
      this.roleAr,
      this.steps,
      this.closing,
      this.closingAr);

  /// Keyword groups of the CURRENT step the user must satisfy.
  List<List<String>> acceptsFor(int stepIndex) =>
      stepIndex < steps.length ? steps[stepIndex].acceptAny : const [];

  /// v5.18 (Phase-2 Batch D2): the ONE primary target of each step (the
  /// first keyword of the step's first accept group), in step order. This
  /// IS the practiced vocabulary/structures list the completion summary
  /// shows — real data from the scenario, nothing invented. (A group can
  /// list several accepted variants; the summary shows the first.)
  List<String> get practicedKeywords => [
        for (final s in steps)
          if (s.acceptAny.isNotEmpty && s.acceptAny.first.isNotEmpty)
            s.acceptAny.first.first,
      ];
}

/// Provider contract — the ONLY seam a future AI provider implements.
/// Keep it awaitable and stateless: history in, one turn out.
abstract class ConversationProvider {
  String get labelKey; // l10n key shown as the provider badge
  Future<ConversationResult> reply(
      ConversationScenario scenario, int stepIndex, String userText);
}

class ConversationResult {
  final bool accepted;
  final String partnerText;
  final String partnerTextAr;
  final bool scenarioComplete;
  const ConversationResult(this.accepted, this.partnerText, this.partnerTextAr,
      this.scenarioComplete);
}

class ConversationTrainer {
  ConversationTrainer._();

  /// Normalizes user text for keyword matching: lowercase, punctuation
  /// stripped (Arabic + Latin aware), whitespace collapsed.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final r in raw.runes) {
      // Arabic tashkeel/tatweel are stripped (pronunciation-style) so a
      // learner typing without diacritics still matches the keywords.
      if (r >= 0x064B && r <= 0x065F || r == 0x0670 || r == 0x0640) continue;
      final keep = (r >= 0x30 && r <= 0x39) ||
          (r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          (r >= 0x00C0 && r <= 0x024F) ||
          (r >= 0x0600 && r <= 0x06FF) ||
          (r >= 0x0750 && r <= 0x077F) ||
          r == 0x20;
      if (keep) buffer.writeCharCode(r);
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// True when EVERY keyword of at least one group appears in [userText].
  static bool satisfies(List<List<String>> groups, String userText) {
    final hay = normalize(userText);
    if (hay.isEmpty) return false;
    for (final group in groups) {
      if (group.isEmpty) continue;
      final all = group.every((kw) => hay.contains(normalize(kw)));
      if (all) return true;
    }
    return false;
  }
}

/// The shipped provider: deterministic keyword matching over scripted
/// steps, zero network, zero dependencies beyond this file.
class OfflineScriptedProvider implements ConversationProvider {
  const OfflineScriptedProvider();
  @override
  String get labelKey => 'conversationProviderLocal';

  @override
  Future<ConversationResult> reply(
      ConversationScenario scenario, int stepIndex, String userText) async {
    if (stepIndex >= scenario.steps.length) {
      return ConversationResult(
          true, scenario.closing, scenario.closingAr, true);
    }
    final step = scenario.steps[stepIndex];
    final ok = ConversationTrainer.satisfies(step.acceptAny, userText);
    if (!ok) {
      // stay on the same step; the partner repeats with a nudge line
      return ConversationResult(false, step.partner, step.partnerAr, false);
    }
    final next = stepIndex + 1;
    if (next >= scenario.steps.length) {
      return ConversationResult(
          true, scenario.closing, scenario.closingAr, true);
    }
    final n = scenario.steps[next];
    return ConversationResult(true, n.partner, n.partnerAr, false);
  }
}

class ConversationCatalog {
  ConversationCatalog._();

  /// One starter scenario per course (honest scope — grows later).
  static const List<ConversationScenario> scenarios = [
    ConversationScenario(
        'cv_en_cafe',
        'en',
        'A1',
        'في المقهى',
        'At the café',
        '☕',
        'النادل',
        [
          ConversationStep(
            'Good morning! What would you like to drink?',
            'صباح الخير! ماذا تحب أن تشرب؟',
            [
              ['tea'],
              ['coffee'],
              ['water']
            ],
            'I would like a coffee, please.',
            'أريد قهوة من فضلك.',
          ),
          ConversationStep(
            'Great choice. Would you like anything to eat?',
            'اختيار جيد. أتريد شيئاً لتأكله؟',
            [
              ['cake'],
              ['sandwich'],
              ['no', 'thanks'],
              ['nothing']
            ],
            'Yes, a piece of cake, please.',
            'نعم، قطعة كيك من فضلك.',
          ),
          ConversationStep(
            'Anything else for you?',
            'أي شيء آخر؟',
            [
              ['no', 'thank'],
              ['that', 'all'],
              ['nothing', 'else']
            ],
            'No, thank you. That is all.',
            'لا شكراً، هذا كل شيء.',
          ),
        ],
        'Here you are. Enjoy your drink!',
        'تفضل، بالهنا والشفا!'),
    ConversationScenario(
        'cv_en_checkin',
        'en',
        'A2',
        'تسجيل الدخول للفندق',
        'Hotel check-in',
        '🏨',
        'موظف الاستقبال',
        [
          ConversationStep(
            'Welcome! Do you have a reservation?',
            'مرحباً! هل لديك حجز؟',
            [
              ['yes', 'reservation'],
              ['yes', 'booked'],
              ['i', 'have']
            ],
            'Yes, I have a reservation under the name Ali.',
            'نعم، لدي حجز باسم علي.',
          ),
          ConversationStep(
            'Perfect. How many nights will you stay?',
            'ممتاز. كم ليلة ستقيم؟',
            [
              ['night'],
              ['nights']
            ],
            'Three nights, please.',
            'ثلاث ليالٍ من فضلك.',
          ),
          ConversationStep(
            'Your room is on the third floor. Breakfast is from seven.',
            'غرفتك في الطابق الثالث. الفطور من السابعة.',
            [
              ['thank'],
              ['great'],
              ['perfect']
            ],
            'Thank you very much.',
            'شكراً جزيلاً.',
          ),
        ],
        'Enjoy your stay with us!',
        'استمتع بإقامتك معنا!'),
    ConversationScenario(
        'cv_de_baecker',
        'de',
        'A1',
        'عند الخبّاز',
        'In der Bäckerei',
        '🥨',
        'البائع',
        [
          ConversationStep(
            'Guten Tag! Was dürfen es sein?',
            'نهارك سعيد! بماذا أخدمك؟',
            [
              ['brot'],
              ['brötchen'],
              ['kuchen']
            ],
            'Ich möchte zwei Brötchen, bitte.',
            'أريد خبزَين صغيرين من فضلك.',
          ),
          ConversationStep(
            'Sonst noch etwas?',
            'أي شيء آخر؟',
            [
              ['das', 'war'],
              ['nein', 'danke'],
              ['nichts'],
              ['sonst']
            ],
            'Nein, danke. Das war alles.',
            'لا شكراً، هذا كل شيء.',
          ),
          ConversationStep(
            'Das macht drei Euro fünfzig.',
            'المجموع ثلاثة يورو وخمسون سنتاً.',
            [
              ['danke'],
              ['bitte'],
              ['gereicht']
            ],
            'Danke schön, hier bitte.',
            'شكراً جزيلاً، تفضل.',
          ),
        ],
        'Auf Wiedersehen und guten Appetit!',
        'مع السلامة وبالهنا والشفا!'),
    ConversationScenario(
        'cv_de_kino',
        'de',
        'A2',
        'حجز تذكرة سينما',
        'Kinokarte kaufen',
        '🎬',
        'موظف الكاشير',
        [
          ConversationStep(
            'Guten Abend! Für welchen Film?',
            'مساء الخير! لأي فيلم؟',
            [
              ['film'],
              ['uhr'],
              ['karte']
            ],
            'Eine Karte für den Film um acht Uhr, bitte.',
            'تذكرة للفيلم في الثامنة من فضلك.',
          ),
          ConversationStep(
            'Möchten Sie einen Sitzplatz hinten oder vorne?',
            'أتريد مقعداً خلفياً أم أمامياً؟',
            [
              ['hinten'],
              ['vorne'],
              ['mitte']
            ],
            'Hinten, in der Mitte, bitte.',
            'خلفياً في المنتصف من فضلك.',
          ),
          ConversationStep(
            'Das macht zwölf Euro. Zahlungsart?',
            'المجموع اثنا عشر يورو. طريقة الدفع؟',
            [
              ['karte'],
              ['bar'],
              ['paypal']
            ],
            'Mit Karte, bitte.',
            'بالبطاقة من فضلك.',
          ),
        ],
        'Viel Spaß beim Film!',
        'استمتع بالفيلم!'),
    ConversationScenario(
        'cv_fr_cafe',
        'fr',
        'A1',
        'في المقهى',
        'Au café',
        '🥐',
        'النادل',
        [
          ConversationStep(
            'Bonjour! Vous désirez?',
            'صباح الخير! ماذا تريد؟',
            [
              ['café'],
              ['thé'],
              ['eau'],
              ['jus']
            ],
            'Un café, s\'il vous plaît.',
            'قهوة من فضلك.',
          ),
          ConversationStep(
            'Et comme accompagnement?',
            'وماذا معها؟',
            [
              ['croissant'],
              ['pain'],
              ['rien'],
              ['non', 'merci']
            ],
            'Un croissant, s\'il vous plaît.',
            'كرواسون من فضلك.',
          ),
          ConversationStep(
            'C\'est tout?',
            'هذا كل شيء؟',
            [
              ['oui'],
              ['c\'est', 'tout'],
              ['merci']
            ],
            'Oui, c\'est tout, merci.',
            'نعم هذا كل شيء، شكراً.',
          ),
        ],
        'Voilà, bon appétit!',
        'تفضل، بالهنا والشفا!'),
    ConversationScenario(
        'cv_fr_direc',
        'fr',
        'A2',
        'السؤال عن الطريق',
        'Demander son chemin',
        '🗺️',
        'مارة في الشارع',
        [
          ConversationStep(
            'Bonjour, vous cherchez quelque chose?',
            'مرحباً، تبحث عن شيء؟',
            [
              ['gare'],
              ['gare', 'sncf'],
              ['station']
            ],
            'Où est la gare, s\'il vous plaît?',
            'أين المحطة من فضلك؟',
          ),
          ConversationStep(
            'C\'est à dix minutes à pied. Vous préférez marcher ou prendre le bus?',
            'على بُعد عشر دقائق سيراً. تفضّل المشي أم الحافلة؟',
            [
              ['marcher'],
              ['à', 'pied'],
              ['bus']
            ],
            'Je préfère marcher, merci.',
            'أفضّل المشي، شكراً.',
          ),
          ConversationStep(
            'Allez tout droit puis tournez à gauche. C\'est clair?',
            'امشِ على الأمام ثم انعطف يساراً. هل اتضح؟',
            [
              ['oui', 'merci'],
              ['c\'est', 'clair'],
              ['compris']
            ],
            'Oui, c\'est très clair. Merci beaucoup!',
            'نعم اتضح تماماً، شكراً جزيلاً!',
          ),
        ],
        'Bonne journée et bon courage!',
        'نهارك سعيد وبالتوفيق!'),
    ConversationScenario(
        'cv_ur_dukaan',
        'ur',
        'A1',
        'التسوق من دكان',
        'دکان پر خریداری',
        '🛍️',
        'البائع',
        [
          ConversationStep(
            'السلام علیکم! کیا چاہیے آپ کو؟',
            'السلام عليكم! ماذا تريد؟',
            [
              ['سیب'],
              ['کھانا'],
              ['پانی'],
              ['چائے']
            ],
            'مجھے ایک کلو سیب چاہیے۔',
            'أريد كيلو تفاح.',
          ),
          ConversationStep(
            'اور کچھ؟',
            'وأي شيء آخر؟',
            [
              ['نہیں'],
              ['بس'],
              ['کچھ', 'نہیں']
            ],
            'نہیں شکریہ، بس یہی۔',
            'لا شكراً، هذا فقط.',
          ),
          ConversationStep(
            'کل رقم سو روپے ہوا۔',
            'المجموع مئة روبية.',
            [
              ['شکریہ'],
              ['پیسے'],
              ['لو']
            ],
            'بہت شکریہ، پیسے حاضر ہیں۔',
            'شكراً جزيلاً، تفضل النقود.',
          ),
        ],
        'پھر تشریف لائیے، خدا حافظ!',
        'تعال مرة أخرى، مع السلامة!'),
    ConversationScenario(
        'cv_ur_raasta',
        'ur',
        'A2',
        'السؤال عن الطريق',
        'راستہ پوچھنا',
        '🧭',
        'مارة في الشارع',
        [
          ConversationStep(
            'جی، کیا ہدایت چاہیے؟',
            'نعم، أي إرشاد تريد؟',
            [
              ['اسٹیشن'],
              ['راستہ'],
              ['بازار']
            ],
            'اسٹیشن کا راستہ کیا ہے؟',
            'ما طريق المحطة؟',
          ),
          ConversationStep(
            'پیدل دس منٹ ہے، یا بس لے لیجیے۔',
            'عشر دقائق سيراً، أو خذ الحافلة.',
            [
              ['پیدل'],
              ['بس']
            ],
            'میں پیدل جاؤں گا، شکریہ۔',
            'سأذهب سيراً، شكراً.',
          ),
          ConversationStep(
            'پہلے سیدھے جائیں پھر بائیں مڑیے۔ سمجھ آ گئی؟',
            'امشِ مستقيماً ثم انعطف يساراً. فهمت؟',
            [
              ['جی'],
              ['سمجھ'],
              ['شکریہ']
            ],
            'جی، سمجھ آ گئی، بہت شکریہ۔',
            'نعم فهمت، شكراً جزيلاً.',
          ),
        ],
        'اللہ نہ کراڑے، خدا حافظ!',
        'بالتوفيق، مع السلامة!'),
    // ---------- v5.16 (Q4/F4.2): B1/B2 scenarios for every course ----------
    ConversationScenario(
        'cv_en_doctor',
        'en',
        'B1',
        'عند الطبيب',
        'At the doctor',
        '🩺',
        'الطبيب',
        [
          ConversationStep(
            'Good morning. What seems to be the problem?',
            'صباح الخير. ما المشكلة؟',
            [
              ['headache'],
              ['stomach'],
              ['throat'],
              ['pain']
            ],
            'I have a headache and a sore throat.',
            'رأسي يؤلمني وحلقي ملتهب.',
          ),
          ConversationStep(
            'I see. How long have you felt this way?',
            'فهمت. منذ متى تشعر بهذا؟',
            [
              ['day'],
              ['days'],
              ['week'],
              ['since']
            ],
            'For three days now.',
            'منذ ثلاثة أيام.',
          ),
          ConversationStep(
            'Take this medicine twice a day and get some rest.',
            'خذ هذا الدواء مرتين يومياً واسترح.',
            [
              ['thank'],
              ['ok'],
              ['medicine']
            ],
            'Thank you, doctor. I will rest.',
            'شكراً يا دكتور، سأستريح.',
          ),
        ],
        'Get well soon! Come back if it does not improve.',
        'شفاكاً عاجلاً! عد إن لم تتحسن.'),
    ConversationScenario(
        'cv_en_interview',
        'en',
        'B2',
        'مقابلة عمل',
        'Job interview',
        '💼',
        'مسؤول التوظيف',
        [
          ConversationStep(
            'Welcome. Tell me a little about yourself.',
            'أهلاً بك. حدثني قليلاً عن نفسك.',
            [
              ['experience'],
              ['work'],
              ['years'],
              ['study']
            ],
            'I have three years of experience in marketing.',
            'لدي ثلاث سنوات من الخبرة في التسويق.',
          ),
          ConversationStep(
            'Interesting. Why do you want this job?',
            'مثير للاهتمام. لماذا تريد هذه الوظيفة؟',
            [
              ['company'],
              ['learn'],
              ['grow'],
              ['opportunity']
            ],
            'I want to grow and learn new skills in your company.',
            'أريد أن أنمو وأتعلم مهارات جديدة في شركتكم.',
          ),
          ConversationStep(
            'Good answer. When could you start?',
            'إجابة جيدة. متى يمكنك البدء؟',
            [
              ['week'],
              ['month'],
              ['monday'],
              ['immediately']
            ],
            'I can start next week.',
            'يمكنني البدء الأسبوع القادم.',
          ),
        ],
        'We will contact you within a week. Thanks for coming.',
        'سنتصل بك خلال أسبوع. شكراً لمجيئك.'),
    ConversationScenario(
        'cv_de_arzt',
        'de',
        'B1',
        'عند الطبيب',
        'Beim Arzt',
        '🩺',
        'الطبيب',
        [
          ConversationStep(
            'Guten Tag! Was fehlt Ihnen?',
            'نهارك سعيد! ما بك؟',
            [
              ['kopf'],
              ['bauch'],
              ['hals'],
              ['schmerzen']
            ],
            'Ich habe Kopfschmerzen.',
            'رأسي يؤلمني.',
          ),
          ConversationStep(
            'Seit wann haben Sie das?',
            'منذ متى وأنت كذلك؟',
            [
              ['tag'],
              ['tagen'],
              ['woche'],
              ['lange']
            ],
            'Seit zwei Tagen.',
            'منذ يومين.',
          ),
          ConversationStep(
            'Nehmen Sie diese Tabletten zweimal täglich.',
            'خذ هذه الأقراص مرتين يومياً.',
            [
              ['danke'],
              ['gut'],
              ['einverstanden']
            ],
            'Danke, Herr Doktor.',
            'شكراً يا دكتور.',
          ),
        ],
        'Gute Besserung! Wenn es schlimmer wird, kommen Sie wieder.',
        'شفاكاً عاجلاً! عد إن ساء الأمر.'),
    ConversationScenario(
        'cv_de_wohnung',
        'de',
        'B2',
        'البحث عن شقة',
        'Wohnungssuche',
        '🏠',
        'وكيل العقارات',
        [
          ConversationStep(
            'Guten Tag! Sie haben wegen der Wohnung angerufen?',
            'نهارك سعيد! اتصلت بخصوص الشقة؟',
            [
              ['wohnung'],
              ['besichtigen'],
              ['zimmer']
            ],
            'Ja, ich möchte die Wohnung gern besichtigen.',
            'نعم، أود معاينة الشقة.',
          ),
          ConversationStep(
            'Sie hat drei Zimmer, eine Küche und einen Balkon.',
            'فيها ثلاث غرف ومطبخ وشرفة.',
            [
              ['miete'],
              ['kostet'],
              ['preis']
            ],
            'Wie hoch ist die Miete?',
            'كم قيمة الإيجار؟',
          ),
          ConversationStep(
            'Achthundert Euro warm, Nebenkosten inklusive.',
            'ثمانمئة يورو بنفقات التدفئة المشمولة.',
            [
              ['termin'],
              ['wann'],
              ['besichtigen']
            ],
            'Wann können wir einen Termin machen?',
            'متى يمكننا تحديد موعد للمعاينة؟',
          ),
        ],
        'Morgen um vier? Bis dann!',
        'غداً في الرابعة؟ إلى اللقاء!'),
    ConversationScenario(
        'cv_fr_medecin',
        'fr',
        'B1',
        'عند الطبيب',
        'Chez le médecin',
        '🩺',
        'الطبيب',
        [
          ConversationStep(
            'Bonjour, qu\'est-ce qui vous arrive ?',
            'صباح الخير، ماذا بك؟',
            [
              ['tête'],
              ['ventre'],
              ['gorge'],
              ['mal']
            ],
            'J\'ai mal à la tête.',
            'رأسي يؤلمني.',
          ),
          ConversationStep(
            'Depuis quand avez-vous ce symptôme ?',
            'منذ متى لديك هذا العرض؟',
            [
              ['jour'],
              ['jours'],
              ['semaine'],
              ['matin']
            ],
            'Depuis trois jours.',
            'منذ ثلاثة أيام.',
          ),
          ConversationStep(
            'Voici une ordonnance. Reposez-vous bien.',
            'هذه هي الوصفة. استرح جيداً.',
            [
              ['merci'],
              ['d\'accord'],
              ['docteur']
            ],
            'Merci beaucoup, docteur.',
            'شكراً جزيلاً يا دكتور.',
          ),
        ],
        'Bon rétablissement ! Revenez si ça continue.',
        'شفاكاً عاجلاً! عد إن استمر الأمر.'),
    ConversationScenario(
        'cv_fr_entretien',
        'fr',
        'B2',
        'مقابلة عمل',
        'Entretien d\'embauche',
        '💼',
        'مسؤول التوظيف',
        [
          ConversationStep(
            'Bonjour, entrez. Parlez-moi de vous.',
            'صباح الخير، تفضل. حدثني عن نفسك.',
            [
              ['expérience'],
              ['travail'],
              ['ans'],
              ['études']
            ],
            'J\'ai deux ans d\'expérience dans la vente.',
            'لدي سنتان من الخبرة في البيع.',
          ),
          ConversationStep(
            'Pourquoi voulez-vous ce poste ?',
            'لماذا تريد هذا المنصب؟',
            [
              ['entreprise'],
              ['apprendre'],
              ['évoluer'],
              ['défis']
            ],
            'Je veux évoluer et apprendre dans votre entreprise.',
            'أريد أن أتطور وأتعلم في شركتكم.',
          ),
          ConversationStep(
            'Très bien. Quand êtes-vous disponible ?',
            'جيد جداً. متى تكون متاحاً؟',
            [
              ['lundi'],
              ['semaine'],
              ['mois'],
              ['immédiatement']
            ],
            'Je suis disponible la semaine prochaine.',
            'أنا متاح الأسبوع القادم.',
          ),
        ],
        'On vous répond dans la semaine. Merci.',
        'سنرد عليك خلال الأسبوع. شكراً.'),
    ConversationScenario(
        'cv_ur_daktar',
        'ur',
        'B1',
        'عند الطبيب',
        'ڈاکٹر کے پاس',
        '🩺',
        'الطبيب',
        [
          ConversationStep(
            'السلام علیکم! آپ کو کیا تکلیف ہے؟',
            'السلام عليكم! ماذا بك؟',
            [
              ['سر'],
              ['پیٹ'],
              ['گلا'],
              ['درد']
            ],
            'میرا سر درد کر رہا ہے۔',
            'رأسي يؤلمني.',
          ),
          ConversationStep(
            'کب سے یہ تکلیف ہے؟',
            'منذ متى وأنت كذلك؟',
            [
              ['دن'],
              ['ہفتہ'],
              ['صبح']
            ],
            'دو دن سے۔',
            'منذ يومين.',
          ),
          ConversationStep(
            'یہ دوا دن میں دو بار لیں اور آرام کریں۔',
            'خذ هذا الدواء مرتين يومياً واسترح.',
            [
              ['شکریہ'],
              ['ٹھیک'],
              ['دوا']
            ],
            'شکریہ ڈاکٹر صاحب۔',
            'شكراً يا دكتور.',
          ),
        ],
        'جلد صحت یاب ہوں! تکلیف بڑھی تو آ جائیے۔',
        'شفاكاً عاجلاً! عد إن ازداد الأمر.'),
    ConversationScenario(
        'cv_ur_interview',
        'ur',
        'B2',
        'مقابلة عمل',
        'ملازمت کا انٹرویو',
        '💼',
        'مسؤول التوظيف',
        [
          ConversationStep(
            'خوش آمدید۔ اپنے بارے میں بتائیں۔',
            'أهلاً بك. حدثني عن نفسك.',
            [
              ['تجربہ'],
              ['کام'],
              ['سال'],
              ['تعلیم']
            ],
            'میرے پاس تین سال کا تجربہ ہے۔',
            'لدي ثلاث سنوات من الخبرة.',
          ),
          ConversationStep(
            'اچھا۔ آپ یہ نوکری کیوں چاہتے ہیں؟',
            'جيد. لماذا تريد هذه الوظيفة؟',
            [
              ['سیکھ'],
              ['کمپنی'],
              ['ترقی'],
              ['موقع']
            ],
            'میں ترقی اور نئی مہارتیں سیکھنا چاہتا ہوں۔',
            'أريد التطور وتعلم مهارات جديدة.',
          ),
          ConversationStep(
            'بہت خوب۔ آپ کب شروع کر سکتے ہیں؟',
            'ممتاز. متى يمكنك البدء؟',
            [
              ['اتوار'],
              ['ہفتہ'],
              ['مہینہ'],
              ['فوراً']
            ],
            'میں اگلے ہفتے شروع کر سکتا ہوں۔',
            'يمكنني البدء الأسبوع القادم.',
          ),
        ],
        'ہم ایک ہفتے میں رابطہ کریں گے۔ شکریہ۔',
        'سنتصل بك خلال أسبوع. شكراً.'),
  ];

  static List<ConversationScenario> forCourse(String courseId) =>
      scenarios.where((s) => s.courseId == courseId).toList();

  static ConversationScenario? byId(String id) {
    for (final s in scenarios) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Catalog sanity: unique ids, real courses, steps well-formed
  /// (≥3 steps, non-empty lines, non-empty accept groups with ≥1 keyword,
  /// sample replies non-empty).
  static bool verify() {
    final seen = <String>{};
    const courseIds = {'en', 'fr', 'de', 'ur'};
    for (final s in scenarios) {
      if (!seen.add(s.id)) return false;
      if (!courseIds.contains(s.courseId)) return false;
      if (s.steps.length < 3) return false;
      if (s.closing.trim().isEmpty || s.closingAr.trim().isEmpty) return false;
      for (final st in s.steps) {
        if (st.partner.trim().isEmpty || st.partnerAr.trim().isEmpty) {
          return false;
        }
        if (st.sampleReply.trim().isEmpty || st.sampleReplyAr.trim().isEmpty) {
          return false;
        }
        if (st.acceptAny.isEmpty || st.acceptAny.any((g) => g.isEmpty)) {
          return false;
        }
      }
    }
    return true;
  }
}
