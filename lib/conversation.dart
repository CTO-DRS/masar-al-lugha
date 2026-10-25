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
