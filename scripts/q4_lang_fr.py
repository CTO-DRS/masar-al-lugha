#!/usr/bin/env python3
"""Q4/F4.1 French frames and overrides.

French noun targets carry their article (le pain, la couverture), so noun
frames never add a determiner. Verb carriers lock to 3rd-masc subjects so
the Arabic imperfect translation (يفعل) stays grammatical.
"""
from q4_engine import noun_subtype

try:
    from q4_bank_fr import BANK, TARGET_BANK
except ImportError:  # authored banks arrive in batches
    BANK = {}

OVERRIDES = {
    "bonjour": ("Bonjour, monsieur le professeur!", "صباح الخير يا أستاذي!"),
    "salut": ("Salut, ça va bien?", "مرحباً، هل أنت بخير؟"),
    "bonsoir": ("Bonsoir, entrez s'il vous plaît.", "مساء الخير، تفضل بالدخول."),
    "merci": ("Merci beaucoup pour votre aide.", "شكراً جزيلاً على مساعدتك."),
    "oui": ("Oui, je suis d'accord.", "نعم، أنا موافق."),
    "non": ("Non, merci, je viens de manger.", "لا شكراً، لقد تناولت للتو."),
    "pardon": ("Pardon, où est la gare?", "عفواً، أين المحطة؟"),
    "enchanté": ("Enchanté, je suis Ahmed.", "تشرفت بمعرفتك، أنا أحمد."),
    "bien": ("Il parle français très bien.", "يتحدث الفرنسية جيداً جداً."),
    "ça va ?": ("Ça va ? Et toi?", "هل بخير؟ وأنت؟"),
    "ça va bien": ("Ça va bien, merci beaucoup.", "أنا بخير، شكراً جزيلاً."),
    "et toi ?": ("Je vais bien. Et toi?", "أنا بخير. وأنت؟"),
    "au revoir": ("Au revoir, à demain!", "إلى اللقاء، أراك غداً!"),
    "s'il vous plaît": ("Un café, s'il vous plaît.", "قهوة من فضلك."),
    "je m'appelle...": ("Je m'appelle... Ahmed.", "اسمي... أحمد."),
    "j'habite à...": ("J'habite à... Marseille.", "أسكن في... مرسيليا."),
    "de rien": ("De rien, mon ami!", "لا شكر على واجب يا صديقي!"),
    "bonne nuit": ("Bonne nuit, dors bien.", "تصبح على خير، نم جيداً."),
    "à demain": ("À demain, bonne soirée!", "إلى الغد، أمسية سعيدة!"),
    "je suis arabe": ("Je suis arabe et je parle français.", "أنا عربي وأتحدث الفرنسية."),
    "j'ai vingt ans": ("J'ai vingt ans cette année.", "عمري عشرون عاماً هذا العام."),
    "j'ai deux frères": ("J'ai deux frères et une sœur.", "لدي أخوان وأخت."),
    "très bien": ("Le cours est très bien expliqué.", "الدرس مشروح بشكل جيد جداً."),
    "comment tu t'appelles ?": ("Comment tu t'appelles, monsieur?", "ما اسمك يا سيدي؟"),
    "d'accord": ("D'accord, à ce soir!", "اتفقت، إلى اللقاء مساءً!"),
    "bienvenue": ("Bienvenue dans notre école!", "أهلاً بك في مدرستنا!"),
}

VERB = [
    ("Il veut {w} maintenant.", "يريد أن {t} الآن."),
    ("Il aime {w} le week-end.", "يحب أن {t} في نهاية الأسبوع."),
    ("Il va {w} bientôt.", "س{t} قريباً."),
    ("Il faut {w} pour réussir.", "من الضروري أن {t} لينجح."),
    ("Il commence à {w} ce matin.", "بدأ {t} هذا الصباح."),
    ("Peut-il {w} seul?", "هل يستطيع أن {t} وحده؟"),
    ("Il ne veut pas {w} ici.", "لا يريد أن {t} هنا."),
    ("Il essaye de {w} chaque jour.", "يحاول أن {t} كل يوم."),
    ("Il doit {w} avant midi.", "عليه أن {t} قبل الظهر."),
    ("Il préfère {w} le soir.", "يفضل أن {t} في المساء."),
]

NOUN = [  # targets already carry the article
    ("J'aime {w}.", "أحب {t}."),
    ("Où est {w} ?", "أين {t}؟"),
    ("Il prend {w} chaque matin.", "يأخذ {t} كل صباح."),
    ("Il y a {w} sur la table.", "على الطاولة {t}."),
    ("Je veux {w}, s'il vous plaît.", "أريد {t} من فضلك."),
    ("Il achète {w} au marché.", "يشتري {t} من السوق."),
    ("Je connais {w} très bien.", "أعرف {t} جيداً."),
    ("Elle porte {w} aujourd'hui.", "ترتدي {t} اليوم."),
    ("Nous parlons de {w}.", "نتحدث عن {t}."),
    ("Il met {w} dans le sac.", "يضع {t} في الحقيبة."),
    ("C'est mon {w}.", "إنه {t} الخاص بي."),
    ("Il regarde {w} avec attention.", "ينظر إلى {t} بانتباه."),
]

ADJ = [
    ("Il est très {w}.", "هو {t} جداً."),
    ("C'est un homme {w}.", "إنه رجل {t}."),
    ("Ce garçon est {w}.", "ذلك الولد {t}."),
    ("Le professeur est {w}.", "المعلم {t}."),
    ("Ma ville est {w}.", "مدينتي {t}."),
]

NUM = [
    ("Je peux compter jusqu'à {w}.", "أستطيع العد حتى {t}."),
    ("Le numéro {w} gagne aujourd'hui.", "الرقم {t} يفوز اليوم."),
]

SENTENCE_Q = [
    ("Il demande : {w}", "يسأل: {t}"),
    ("Elle écrit : {w}", "تكتب: {t}"),
    ("{w} Répondez, s'il vous plaît.", "{t} أجب من فضلك."),
]
DIRECT = [
    ("Il dit : {w}", "قال: {t}"),
    ("Elle écrit : {w}", "كتبت: {t}"),
    ("Il me dit : {w}", "قال لي: {t}"),
]
PHRASE_I = [
    ("{w}, mon ami!", "{t} يا صديقي!"),
    ("Il dit : {w}", "قال: {t}"),
]
IMPERATIVE = [
    ("{w}, s'il vous plaît.", "{t} من فضلك."),
    ("Il dit : {w}", "قال: {t}"),
]

# Noun frames routed by semantic subtype of the Arabic translation.
# French targets carry their article, so carriers never contract with the
# target (no "au/de le" — they would break verbatim containment).
NOUN_FRAMES = {
    "person": [
        ("J'ai parlé avec {w} hier.", "تحدثت إلى {t} أمس."),
        ("{w} m'a beaucoup aidé.", "ساعدني {t} كثيراً."),
        ("Connais-tu {w} ?", "هل تعرف {t}؟"),
    ],
    "place": [
        ("Nous avons visité {w} la semaine dernière.", "زرنا {t} الأسبوع الماضي."),
        ("Nous allons à {w} maintenant.", "لنذهب إلى {t} الآن."),
        ("{w} est près de la mosquée.", "{t} قريب من المسجد."),
    ],
    "food": [
        ("J'ai acheté {w} pour le dîner.", "اشتريت {t} للعشاء."),
        ("Il nous faut {w} pour le gâteau.", "نحتاج {t} للكيك."),
        ("Il a mis {w} sur la table.", "وضع {t} على الطاولة."),
    ],
    "animal": [
        ("Nous avons vu {w} pendant le voyage.", "رأينا {t} في الرحلة."),
        ("Regarde {w} !", "انظر إلى {t}!"),
    ],
    "vehicle": [
        ("Il prend {w} pour aller au travail.", "يركب {t} إلى العمل."),
        ("Connais-tu le mot '{w}' ?", "هل تعرف كلمة '{w}'؟"),
    ],
    "time": [
        ("À {w} !", "أراك يوم {t}!"),
        ("{w} est une journée chargée pour nous.", "{t} يوم مشغول بالنسبة لنا."),
    ],
    None: [
        ("Ce cours concerne {w}.", "هذا الدرس عن {t}."),
        ("Le professeur a expliqué {w} aujourd'hui.", "شرح المعلم {t} اليوم."),
        ("J'ai lu un livre sur {w}.", "قرأت عن {t} في الكتاب."),
        ("Trouve {w} dans l'image.", "ابحث عن {t} في الصورة."),
        ("Connais-tu le mot '{w}' ?", "هل تعرف كلمة '{w}'؟"),
        ("Il a écrit une phrase avec {w}.", "كتب جملة بها {t}."),
    ],
}


ARTICLE_PREFIXES = ("le ", "la ", "les ", "l'", "un ", "une ", "des ", "du ", "de la ", "au ", "à la ")

# Article-free frames for bare French targets (fourmi, ciel, autobus).
NOUN_BARE_FR = [
    ("Connais-tu le mot '{w}' ?", "هل تعرف كلمة '{w}'؟"),
    ("Le professeur a expliqué le mot '{w}'.", "شرح المعلم كلمة '{w}' اليوم."),
    ("J'ai lu le mot '{w}' dans le livre.", "قرأت كلمة '{w}' في الكتاب."),
]


def frames_for(cls, word, course):
    if cls == "verb":
        return VERB
    if cls == "num":
        return NUM
    if cls == "noun":
        t = (word.get("translationAr") or "").strip()
        target = (word.get("target") or "").strip().lower()
        if not target.startswith(ARTICLE_PREFIXES):
            return NOUN_BARE_FR
        return NOUN_FRAMES.get(noun_subtype(t), NOUN_FRAMES[None])
    if cls == "phrase_q":
        return SENTENCE_Q
    if cls == "phrase_i":
        return PHRASE_I
    if cls == "imperative":
        return IMPERATIVE
    if cls == "sentence":
        return DIRECT
    return []  # adj/adv/interject are hand-authored in the bank


ADV = [
    ("Il avance {w} dans la rue.", "يمشي {t} في الشارع."),
    ("Il répond {w} au professeur.", "يجيب {t} المعلم."),
]
