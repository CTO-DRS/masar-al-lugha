#!/usr/bin/env python3
"""Q4/F4.1 shared engine: classify a missing-example word, pick a
meaning-parallel bilingual frame, and validate the result.

Hard rules enforced here:
  - the generated exampleTarget must contain the vocab target verbatim
    (case-insensitive) so `_canBlank` in exercise_gen.dart stays true;
  - 2..8 words so dictation keeps accepting the example;
  - existing examples are NEVER touched (content is append-only);
  - deterministic: frame choice is seeded by the word id hash.
"""
import hashlib

# ---------------- seeding ----------------

def seed_for(course: str, wid: str) -> int:
    h = hashlib.sha1(f"{course}:{wid}".encode("utf-8")).hexdigest()
    return int(h[:8], 16)


def pick(seed: int, seq):
    return seq[seed % len(seq)]


# ---------------- arabic-side helpers ----------------

AR_LETTERS = set("ابتثجحخدذرزسشصضطظعغفقكلمنهويءآأإةى")


def is_arabic(s: str) -> bool:
    return bool(s) and all(
        (c in AR_LETTERS or c in " \u060c؟!.:;،'\"()-ـٌٍََُِّّْٰ") for c in s
    )


def has_al(t: str) -> bool:
    """Does the Arabic translation start with the definite article?"""
    return t.startswith("ال") and len(t) > 3 and not t.startswith("الإ")


def looks_verb_ar(t: str) -> bool:
    """Authored verb translations are 3rd-masc imperfect: يفعل / يُفعل."""
    return t.startswith(("ي", "يُ", "يَ")) and len(t) > 2


def looks_adj_ar(t: str) -> bool:
    for pref in ("متف", "متك", "متو", "متش", "متز", "متل", "متم", "متس", "متط", "متع", "متحد"):
        if t.startswith(pref):
            return True
    return False


NUM_AR = {
    "صفر", "واحد", "واحدة", "اثنان", "اثنتان", "ثلاثة", "أربعة", "خمسة",
    "ستة", "سبعة", "ثمانية", "تسعة", "عشرة", "أحد عشر", "اثنا عشر",
    "عشرون", "ثلاثون", "أربعون", "خمسون", "مئة", "مائة", "ألف",
    "عشرين", "خمسة عشر", "ستة عشر", "سبعة عشر", "ثمانية عشر", "تسعة عشر",
    "ثلاثة عشر", "أربعة عشر", "خمسون", "ستين", "سبعين", "ثمانين", "تسعين",
}
NUM_EN = {
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty",
    "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred",
    "thousand", "million", "first", "second", "third", "half", "dozen",
}

EN_FUNCTION = {
    "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us",
    "them", "my", "your", "his", "its", "our", "their", "mine", "yours",
    "this", "that", "these", "those", "here", "there", "and", "or", "but",
    "if", "because", "so", "not", "very", "too", "also", "always",
    "never", "sometimes", "now", "then", "today", "tomorrow", "yesterday",
    "again", "more", "less", "most", "least", "all", "some", "any", "no",
    "yes", "ok", "okay", "please", "thanks", "thank you", "sorry",
    "hello", "hi", "hey", "goodbye", "bye", "welcome", "good",
    "well", "bad", "yes, please", "of course", "maybe", "really",
    "what", "who", "where", "when", "why", "how", "which", "whose",
    "in", "on", "at", "to", "from", "with", "without", "for", "about",
    "under", "over", "between", "near", "far", "up", "down", "left",
    "right", "straight", "stop", "enough", "done", "ready", "sure",
}


AR_VERB_PREFIX = ("ي", "يُ", "يَ", "تُ", "تَ", "أ", "إ", "اِ", "أُ", "لن ", "لم ", "س", "سو",
                  "كان ", "هذا", "هذه", "هؤلاء", "ذلك", "تلك", "قد ", "هل ", "ما ", "لا ",
                  "عندي ", "عندي")

# possessive pronouns in the TARGET language mark fragment rows ("My name")
POSSESSIVE_EN = {"my", "your", "his", "her", "its", "our", "their"}
POSSESSIVE_FR = {"mon", "ma", "mes", "ton", "ta", "tes", "son", "sa",
                 "ses", "notre", "nos", "votre", "vos", "leur", "leurs"}
POSSESSIVE_UR = {"میرا", "میری", "میرے", "اس کا", "اس کی", "ان کا", "ان کی",
                 "اس کے"}

# Curated common Arabic adverb translations (exact match).
ADV_AR = {
    "بسرعة", "ببطء", "بسهولة", "بصعوبة", "بهدوء", "بصوت عال",
    "بصوت عالٍ", "بصوت منخفض", "معاً", "معا", "دائماً", "أبداً",
    "غالباً", "أحياناً", "نادراً", "للخلف", "للأمام", "إلى الوراء",
    "في المنتصف", "بالكاد", "تقريباً", "جداً", "كثيراً", "قليلاً",
    "في المنتصف تقريباً", "للأسف", "لحسن الحظ", "بالطبع", "أيضاً",
    "فقط", "معاً", "إلى اليمين", "إلى اليسار", "مباشرة", "من جديد",
    "مرة أخرى", "الآن", "قريباً", "متأخراً", "باكراً", "أمس", "اليوم",
}

# Copula words in the TARGET languages mark nominal sentences
# ("My family is big", "La maison est grande", "میں محنتی ہوں").
COPIULA_WORDS = {
    "is", "are", "am", "was", "were", "be", "est", "sont", "es",
    "suis", "ais", "ہے", "ہیں", "ہوں", "تھا", "تھی", "تھے", "ہوتا", "ہوتی",
}

# Multi-word translations that start with س but are NOT future verbs
# (ساعة ذكية، سؤال شائع...) — the س prefix otherwise marks the future.
SA_NOUN_EXCEPTIONS = {
    "ساعة", "سكر", "سكر", "سوق", "سيارة", "سماء", "سؤال", "سلام",
    "سجاد", "سلة", "سمك", "سبورة", "ساحة", "سعر", "سحاب", "سلك",
    "سفر", "سقف", "سرير", "سماعة", "سلسلة", "سلة مهملات", "سواء",
    "سائل", "سمت", "سياسة", "سياحة", "سفر", "سكوت", "سماح",
}
AR_IMPERATIVE = ("اِفعل",)  # not used for classification, kept for clarity


def ar_starts_verbish(t: str) -> bool:
    return t.startswith(AR_VERB_PREFIX) and not t.startswith(("سا", "سي", "سوء"))


# Semantic subtypes keyed on the ARABIC translation (Arabic in all courses),
# matched as prefixes after stripping the definite article.
PERSON_AR = (
    "طبيب", "مهندس", "مزارع", "فلاح", "خياط", "معلم", "أستاذ", "طالب",
    "تلميذ", "جراح", "ممرض", "حارس", "شرطي", "قصاب", "حداد", "نجار",
    "كهربائي", "برقي", "سائق", "طيار", "بحار", "عامل", "موظف", "مدير",
    "مصرفي", "بائع", "تاجر", "قائد", "رئيس", "صيدلي", "دهان", "لحام",
    "ميكانيكي", "مترجم", "صحفي", "محام", "قاض", "راعي", "صياد", "خباز",
    "حلاق", "خادم", "جندي", "ضابط", "كاهن", "خطيب", "ممثل", "مغني",
    "رسام", "كاتب", "شاعر", "عالم", "مخترع", "مستكشف", "رياضي", "لاعب",
    "مدرب", "حكم", "ناظر", "جزار", "لص", "جدة", "جد", "والد", "والدة",
    "أم", "أب", "أخ", "أخت", "ابن", "ابنة", "بنت", "ولد", "عم", "خال",
    "عمة", "خالة", "زوج", "زوجة", "عريس", "عروس", "حبيب", "صديق",
    "صديقة", "رفيق", "جار", "جارة", "رضيع", "طفل", "طفلة", "شاب",
    "فتاة", "رجل", "امرأة", "شخص", "إنسان", "قريب", "زميل", "جار",
)
PLACE_AR = (
    "مستشفى", "مدرسة", "جامعة", "مطعم", "مقهى", "متحف", "مكتبة", "سوق",
    "بازار", "مطار", "محطة", "مصرف", "بنك", "فندق", "حديقة", "مسجد",
    "مكتب", "مصنع", "ورشة", "قرية", "مدينة", "شارع", "ساحة", "ملعب",
    "شاطئ", "صيدلية", "عيادة", "سجن", "ثكنة", "معسكر", "ساحة", "ناد",
    "قصر", "قلعة", "برج", "جسر", "نفق", "ميناء", "كوخ", "بيت ريفي",
)
FOOD_AR = (
    "خبز", "حليب", "تفاح", "موز", "برتقال", "عنب", "بطيخ", "رمان",
    "أرز", "لحم", "دجاج", "سمك", "جبن", "زبادي", "عصير", "شاي", "قهوة",
    "سكر", "ملح", "زيت", "عسل", "تمر", "خضار", "فاكهة", "بطاطس",
    "طماطم", "خيار", "بصل", "ثوم", "فلفل", "بيض", "معكرونة", "بيتزا",
    "شوربة", "حساء", "حلوى", "كيك", "بسكويت", "شوكولاتة", "عصائر",
    "بهار", "كمون", "كركم", "فول", "عدس", "حمص", "شوفان", "ذرة",
)
ANIMAL_AR = (
    "كلب", "قط", "قطة", "أسد", "نمر", "فيل", "زرافة", "حصان", "فرس",
    "بقر", "ثور", "خروف", "ماعز", "جمل", "حيوان", "حمار", "بغل",
    "عصفور", "طائر", "حمامة", "ديك", "دجاجة", "بطة", "إوزة", "نعامة",
    "بجعة", "غراب", "صقر", "نسر", "بوم", "دودة", "ذئب", "ثعلب", "أرنب",
    "فأر", "جرذ", "سنجاب", "قنفذ", "نملة", "نحلة", "فراشة", "ذبابة",
    "بعوضة", "صرصور", "عنكبوت", "أفعى", "حية", "تمساح", "سلحفاة",
    "ضفدع", "سمكة", "حوت", "قرش", "دلفين", "خنفساء", "جرادة", "دلفين",
)
VEHICLE_AR = (
    "سيارة", "شاحنة", "حافلة", "باص", "بوس", "قطار", "طائرة", "هليكوبتر",
    "سفينة", "قارب", "زورق", "دراجة", "موتور", "تكسي", "أجرة", "مترو",
    "ترام", "صاروخ", "قارب شراعي",
)
TIME_AR = (
    "الخميس", "الاثنين", "الثلاثاء", "الأربعاء", "الجمعة",
    "السبت", "الأحد", "خميس", "اثنين", "ثلاثاء", "أربعاء", "جمعة",
    "سبت", "أحد",
)


GREETING_AR = {
    "صباح الخير", "مساء الخير", "مساء النور", "طاب يومك",
    "تصبح على خير", "من فضلك", "لو سمحت", "من فضلكم", "شكرا",
    "شكراً", "شكراً جزيلاً", "ألف شكر", "عفواً", "العفو", "لا شكر",
    "لا شكر على واجب", "السلام عليكم", "أهلاً وسهلاً", "مرحباً",
    "مرحبا", "أهلاً", "إلى اللقاء", "في أمان الله", "مع السلامة",
    "أحسنت", "مبروك", "تهانينا", "عيد سعيد", "كل عام وأنتم بخير",
    "تفضل", "تفضلوا", "بالعافية", "في رعاية الله", "أتمنى لك التوفيق",
    "و عليكم السلام", "وعليكم السلام", "حظاً موفقاً",
    "حظاً سعيداً", "إلى الملتقى",
}
GREETING_PREFIX_EN = (
    "good morning", "good evening", "good afternoon", "good night",
    "thank you", "thanks a lot", "excuse me", "you're welcome",
    "see you", "nice to", "pleased to", "congratulations",
    "happy birthday", "happy new year", "good luck", "goodbye",
    "bless you", "well done", "welcome back",
)
GREETING_PREFIX_FR = (
    "bonjour", "bonsoir", "merci", "s'il vous plaît", "excusez-moi",
    "au revoir", "à bientôt", "à demain", "bonne journée", "bonne nuit",
    "enchanté", "félicitations", "bon anniversaire", "bonne chance",
    "bon appetit", "bon appétit", "à tout à l'heure", "bienvenue",
)
GREETING_PREFIX_UR = (
    "السلام علیکم", "شکریہ", "خوش آمدید", "معاف", "خدا حفاظت",
    "بہت شکریہ", "مہربانی", "الوداع", "پھر ملیں گے",
)

# Curated common Arabic adjective translations (exact match).
ADJ_AR = {
    "حلو", "قوي", "بارد", "حار", "نظيف", "وسخ", "طويل", "قصير",
    "كبير", "صغير", "جديد", "قديم", "سهل", "صعب", "جميل", "قبيح",
    "سعيد", "حزين", "غني", "فقير", "ضعيف", "سريع", "بطيء", "ثقيل",
    "خفيف", "مفتوح", "مغلق", "ممتلئ", "فارغ", "لذيذ", "طازج",
    "ناضج", "مالح", "حامض", "مر", "ناعم", "خشن", "صلب", "لين",
    "مهم", "عادي", "خاص", "صحيح", "خطأ", "ممكن", "مستحيل",
    "متعب", "نشيط", "كسول", "ذكي", "غبي", "طيب", "شرير",
    "شجاع", "جبان", "صبور", "متكبر", "متواضع", "بخيل",
    "حنون", "عنيف", "هادئ", "مزعج", "ممتع", "ممل",
    "مفيد", "ضار", "صالح", "فاسد", "كامل", "ناقص", "واضح", "غامض",
    "مجاني", "مكلف", "رخيص", "غالٍ", "غالي", "ثمين",
    "حديث", "عتيق", "شهير", "مجهول", "غريب", "مألوف", "حقيقي",
    "وهمي", "هش", "كثيف", "عميق", "ضحل", "واسع",
    "ضيق", "مرتفع", "منخفض", "مستقيم", "منحني", "دائري", "مربع",
    "شاغر", "مشغول", "متاح", "جاهز", "خام",
    "طبيعي", "صناعي", "أصلي", "مقلد", "رسمي", "محلي",
    "عالمي", "وطني", "أجنبي", "تاريخي", "معاصر", "شعبي",
    "كلاسيكي", "غليظ", "رفيع", "سميك", "لزج",
    "جاف", "مبلل", "مقرمش", "طري",
    "مجمد", "مسلوق", "مقلي", "مشوي", "نيء",
    "مشمس", "ملغب", "ممطر", "مثلج", "عاصف", "غائم",
    "صاف", "ملوث", "نقي",
}


def noun_subtype(t: str):
    """Classify a noun by its Arabic translation prefix (after ال)."""
    s = t.strip()
    if s.startswith("يوم "):
        s = s[4:]
    for art in ("الإ", "الأ", "الآ", "ال"):
        if s.startswith(art):
            s = s[len(art):]
            break
    for names, kind in (
        (PERSON_AR, "person"), (PLACE_AR, "place"), (FOOD_AR, "food"),
        (ANIMAL_AR, "animal"), (VEHICLE_AR, "vehicle"), (TIME_AR, "time"),
    ):
        for kw in names:
            if s == kw or s.startswith(kw + " "):
                return kind
    return None


IMPERATIVE_EN = {
    "open", "close", "read", "write", "eat", "drink", "go", "come",
    "sit", "stand", "put", "take", "give", "look", "listen", "wash",
    "brush", "clean", "say", "tell", "ask", "turn", "hold", "carry",
    "drop", "pick", "pay", "help", "wait", "call", "stop", "try",
    "hurry", "watch", "check", "sign", "fill", "show", "bring",
    "pass", "move", "keep", "calm", "relax", "enjoy", "answer",
    "choose", "repeat", "spell", "count", "practice", "speak", "think",
    "remember", "forget", "buy", "order", "taste", "smile", "walk",
    "run", "study", "work", "sleep", "wake", "get", "let", "don't",
}
IMPERATIVE_UR = {
    "دو", "دیکھو", "سنو", "بتاؤ", "لاؤ", "کرو", "کھاؤ", "پیو", "جاؤ",
    "آؤ", "بیٹھو", "رکھو", "لو", "دے", "کہو", "پڑھو", "لکھو", "چلو",
    "دیکھ", "سن", "بتا", "لا", "کر", "کھا", "پی", "جا", "آ", "بیٹھ",
    "رکھ", "لکھ", "پڑھ", "بول", "خاموش", "چپ", "انتظار", "ہٹ",
}
IMPERATIVE_FR = {
    "donnez", "mets", "mettez", "prends", "prenez", "ouvre", "ouvrez",
    "ferme", "fermez", "écris", "écrivez", "lis", "lisez", "mange",
    "mangez", "bois", "buvez", "va", "allez", "viens", "venez",
    "regardez", "regarde", "écoutez", "écoute", "attends", "attendez",
    "parle", "parlez", "lève", "levez", "assieds", "asseyez",
    "descends", "monte", "entre", "sors", "achète", "achetez",
    "répète", "répétez", "choisis", "choisissez", "essaye", "essaie",
    "essayez", "excusez", "regardez", "récite",
}


def classify(word: dict, course: str):
    """Return a coarse class used by the language modules.

    Classes: verb, noun, adj, adv, num, interject, phrase_q, phrase_s,
    phrase_i, sentence, unknown.
    """
    target = (word.get("target") or "").strip()
    t = (word.get("translationAr") or "").strip()
    words = target.split()
    low = target.lower()

    if len(words) > 1:
        if target.endswith(("?", "؟")):
            return "phrase_q"
        if target.endswith("..."):
            return "sentence"
        low_t = t.strip()
        gpfx = {"en": GREETING_PREFIX_EN, "fr": GREETING_PREFIX_FR,
                "ur": GREETING_PREFIX_UR}.get(course, ())
        if low_t in GREETING_AR or low.rstrip("!.,") in EN_FUNCTION or \
                low.startswith(gpfx):
            return "phrase_i"
        if ar_starts_verbish(low_t) and \
                low_t.split()[0].lstrip("ال") not in SA_NOUN_EXCEPTIONS:
            return "sentence"
        # copula in the target marks a nominal sentence
        if any(wd.lower().strip("?!,.") in COPIULA_WORDS for wd in words):
            return "sentence"
        # English gerunds mark verbal sentences ("I'm going to bed")
        if any(wd.lower().endswith("ing") and len(wd) > 4 for wd in words):
            return "sentence"
        # any verb-shaped Arabic word (but يوم-phrases are day names)
        ar_probe = low_t.split()
        if ar_probe and ar_probe[0] != "يوم" and any(
                len(x) > 2 and x.startswith(("ي", "يُ", "يَ")) and x != "يوم"
                for x in ar_probe):
            return "sentence"
        # multi-word adverbial phrases (في البنك، على الطاولة، عند الباب)
        if low_t.startswith(("في ", "على ", "إلى ", "من ", "مع ", "عند ",
                             "تحت ", "فوق ", "أمام ", "خلف ", "بين ",
                             "بعد ", "قبل ", "قرب ", "باتجاه ", "لل")):
            return "adv"
        # possessive fragments via target-side pronouns ("My name")
        poss = {"en": POSSESSIVE_EN, "fr": POSSESSIVE_FR,
                "ur": POSSESSIVE_UR}.get(course, set())
        if words[0].lower().strip("?!,.") in poss:
            return "fragment"
        # imperative phrases ("Open the window", "برتن لا دو")
        imp = {"en": IMPERATIVE_EN, "ur": IMPERATIVE_UR,
               "fr": IMPERATIVE_FR}.get(course, set())
        if words[0].lower().strip("?!,.") in imp:
            return "imperative"
        # terminal fallback: short non-verbal Arabic = noun phrase
        ar_words = low_t.split()
        if len(ar_words) <= 3:
            return "noun"
        return "sentence"
    # single word
    ur_function = {
        "شکریہ", "جی ہاں", "جی نہیں", "نہیں", "ہاں", "معاف کیجیے",
        "خدا حفاظت", "برائے مہربانی", "بہت اچھا", "ٹھیک ہے",
    }
    if low in EN_FUNCTION and course in ("en",):
        return "interject"
    if course == "ur" and target in ur_function:
        return "interject"
    if course == "fr" and low in {
        "bonjour", "salut", "bonsoir", "merci", "oui", "non", "pardon",
        "enchanté", "bienvenue", "d'accord", "voilà", "voici", "allons-y",
        "bonne nuit", "de rien", "à demain", "attention", "stop",
    }:
        return "interject"
    if t in NUM_AR or low in NUM_EN:
        return "num"
    if looks_verb_ar(t):
        return "verb"
    if t in ADJ_AR:
        return "adj"
    if t in ADV_AR:
        return "adv"
    if t.startswith(("في ", "لل", "باتجاه", "إلى ", "على ", "من ", "مع ", "تحت ", "فوق ", "أمام ", "خلف ", "بين ", "عند ", "قرب ", "بعد ", "قبل ")) and " " in t.strip():
        return "adv"
    if looks_adj_ar(t) or low.endswith(
        ("ous", "ful", "ive", "able", "ible", "less", "ual", "ial")
    ) or (course == "fr" and low.endswith(("eux", "euse", "if", "ive", "al", "ale", "ain", "ienne"))):
        return "adj"
    return "noun"


def apply_frame(frame, word: dict):
    """Fill (en_pattern, ar_pattern) with the target and its translation.

    Slots: {w} = target verbatim, {w-l} = target with lower-cased first
    letter (mid-sentence embedding), {t} = Arabic translation.
    Returns (exampleTarget, exampleAr) or None when a slot stays empty.
    """
    en, ar = frame
    target = (word.get("target") or "").strip()
    t = (word.get("translationAr") or "").strip()
    if not target or not t:
        return None
    out_en = en.replace("{w-l}", target[:1].lower() + target[1:])
    out_en = out_en.replace("{w}", target)
    out_ar = ar.replace("{w-l}", target[:1].lower() + target[1:])
    out_ar = out_ar.replace("{w}", target)
    out_ar = out_ar.replace("{t}", t)
    if "{w}" in out_en or "{w-l}" in out_en or "{t}" in out_ar or "{w}" in out_ar:
        return None
    return out_en, out_ar


def validate_pair(en: str, ar: str, word: dict):
    """Return an error string, or None when the pair is acceptable."""
    target = (word.get("target") or "").strip()
    if target.lower() not in en.lower():
        return "containment"
    n = len(en.split())
    # the 2..8 dictation gate only applies to single-word targets:
    # multi-word (isSentence) rows never feed dictation from the example.
    if " " not in target and (n < 2 or n > 8):
        return f"wordcount({n})"
    if not en.strip() or not ar.strip():
        return "empty"
    return None
