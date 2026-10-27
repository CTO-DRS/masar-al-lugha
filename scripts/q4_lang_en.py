#!/usr/bin/env python3
"""Q4/F4.1 English frames and overrides.

Every frame is a meaning-parallel (en, ar) pair: the Arabic side locks the
authored translation (3rd-masc imperfect for verbs) into a carrier that
stays grammatical, while the English side embeds the target verbatim.
"""
from q4_engine import has_al, noun_subtype

try:
    from q4_bank_en import BANK, TARGET_BANK
except ImportError:  # authored banks arrive in batches
    BANK = {}

# Hand-authored examples for function words / interjections — the words a
# learner meets on day one deserve real sentences, not generated ones.
# key: target as in JSON (lower-case lookup); value: (exampleTarget, exampleAr)
OVERRIDES = {
    "hi": ("Hi, Sara! How are you?", "مرحباً سارة! كيف حالك؟"),
    "hello": ("Hello, my friend!", "مرحباً يا صديقي!"),
    "hey": ("Hey, wait for me!", "مهلناً! انتظرني!"),
    "welcome": ("Welcome to our school!", "أهلاً بك في مدرستنا!"),
    "goodbye": ("He said goodbye and left.", "قال وداعاً وانصرف."),
    "bye": ("Bye, see you tomorrow!", "إلى اللقاء غداً!"),
    "please": ("Please, open the window.", "من فضلك افتح النافذة."),
    "thank you": ("Thank you for your help.", "شكراً على مساعدتك."),
    "thanks": ("Thanks a lot, Ahmed!", "شكراً جزيلاً يا أحمد!"),
    "sorry": ("Sorry, I am late today.", "آسف، لقد تأخرت اليوم."),
    "yes": ("Yes, that is the answer.", "نعم، هذه هي الإجابة."),
    "no": ("No, this is not mine.", "لا، هذا ليس لي."),
    "ok": ("OK, let us start now.", "حسناً، لنبدأ الآن."),
    "okay": ("Okay, I will call him.", "حسناً، سأتصل به."),
    "sure": ("Sure, ask me anything.", "بالتأكيد، اسألني أي شيء."),
    "maybe": ("Maybe he is at home.", "ربما هو في البيت."),
    "really": ("Really? I did not know!", "حقاً؟ لم أكن أعرف!"),
    "stop": ("Stop the car here, please.", "أوقف السيارة هنا من فضلك."),
    "enough": ("Enough talk, let us work.", "يكفي كلاماً، لنعمل."),
    "done": ("The work is done today.", "انتهى العمل اليوم."),
    "ready": ("I am ready for the exam.", "أنا مستعد للامتحان."),
    "i": ("You and I are friends.", "أنت وأنا صديقان."),
    "you": ("You are my best friend.", "أنت أفضل أصدقائي."),
    "he": ("He is my older brother.", "هو أخي الأكبر."),
    "she": ("She is a kind doctor.", "هي طبيبة طيبة."),
    "it": ("It is a small cat.", "إنها قطة صغيرة."),
    "we": ("We live in the same city.", "نسكن في المدينة نفسها."),
    "they": ("They are my cousins.", "هم أبناء عمومتي."),
    "me": ("Give the book to me, please.", "أعطني الكتاب من فضلك."),
    "him": ("I saw him at the mosque.", "رأيته في المسجد."),
    "her": ("Tell her the news today.", "أخبرها الخبر اليوم."),
    "us": ("Come with us to the park.", "تعال معنا إلى الحديقة."),
    "them": ("I know them very well.", "أعرفهم جيداً."),
    "my": ("My father works in a bank.", "أبي يعمل في مصرف."),
    "your": ("Your bag is on the chair.", "حقيبتك على الكرسي."),
    "his": ("His room is always clean.", "غرفته نظيفة دائماً."),
    "our": ("Our school opens at eight.", "مدرستنا تفتح الثامنة."),
    "their": ("Their house has a garden.", "بيتهم فيه حديقة."),
    "this": ("This is my new phone.", "هذا هاتفي الجديد."),
    "that": ("That man is my teacher.", "ذلك الرجل معلمي."),
    "these": ("These are fresh dates.", "هذه تمرات طازجة."),
    "those": ("Those birds fly south.", "تلك الطيور تطير جنوباً."),
    "here": ("Come here, little one!", "تعال هنا يا صغيري!"),
    "there": ("The mosque is over there.", "المسجد هناك."),
    "and": ("Ali and Omar are here.", "علي وعمر هنا."),
    "or": ("Tea or coffee, sir?", "شاي أم قهوة؟"),
    "but": ("I called, but no answer.", "اتصلت لكن لم يوجد رد."),
    "if": ("If it rains, we stay home.", "إن أمطرت نبقُ في البيت."),
    "because": ("I ran because I was late.", "ركضت لأنني تأخرت."),
    "so": ("I was tired, so I slept.", "كنت متعباً فنمت."),
    "not": ("This is not my book.", "هذا ليس كتابي."),
    "very": ("The exam was very easy.", "كان الامتحان سهلاً جداً."),
    "too": ("The tea is too hot now.", "الشاي ساخن أكثر من اللازم."),
    "also": ("He also wants to come.", "يريد أن يأتي أيضاً."),
    "always": ("She always helps the poor.", "كانت تساعد الفقراء دائماً."),
    "never": ("He never forgets his keys.", "لا ينسى مفاتيحه أبداً."),
    "sometimes": ("Sometimes I walk to work.", "أحياناً أمشي إلى العمل."),
    "now": ("Now it is time to eat.", "حان وقت الطعام الآن."),
    "then": ("First eat, then study.", "كُل أولاً ثم ادرس."),
    "today": ("Today is a beautiful day.", "اليوم يوم جميل."),
    "tomorrow": ("Tomorrow we visit grandfather.", "غداً نزور الجد."),
    "yesterday": ("Yesterday it rained hard.", "أمطرت بغزارة أمس."),
    "again": ("Please say it again slowly.", "أعد قولها ببطء من فضلك."),
    "more": ("I need more time, please.", "أحتاج وقتاً أكثر من فضلك."),
    "most": ("Most students passed the exam.", "معظم الطلاب نجحوا."),
    "all": ("All the doors are closed.", "كل الأبواب مغلقة."),
    "some": ("Some people love winter.", "بعض الناس يحبون الشتاء."),
    "any": ("Do you have any questions?", "ألديك أي أسئلة؟"),
    "what": ("What is your name, please?", "ما اسمك من فضلك؟"),
    "who": ("Who is at the door, mother?", "من على الباب يا أمي؟"),
    "where": ("Where do you live now?", "أين تسكن الآن؟"),
    "when": ("When does the train leave?", "متى يتحرك القطار؟"),
    "why": ("Why are you sad today?", "لماذا أنت حزين اليوم؟"),
    "how": ("How do you say this in Arabic?", "كيف نقول هذا بالعربية؟"),
    "which": ("Which book do you want?", "أي كتاب تريد؟"),
    "in": ("The keys are in the drawer.", "المفاتيح في الدرج."),
    "on": ("The cup is on the table.", "الفنجان على الطاولة."),
    "at": ("We meet at the mosque gate.", "نتقابل عند باب المسجد."),
    "to": ("I go to the market daily.", "أذهب إلى السوق يومياً."),
    "from": ("He is from a small town.", "هو من بلدة صغيرة."),
    "with": ("I went with my brother.", "ذهبت مع أخي."),
    "without": ("Tea without sugar, please.", "شاي بدون سكر من فضلك."),
    "for": ("This gift is for mother.", "هذه الهدية لأمي."),
    "about": ("We talked about the trip.", "تحدثنا عن الرحلة."),
    "under": ("The cat sleeps under the bed.", "القطة تنام تحت السرير."),
    "over": ("The lamp hangs over the desk.", "المصباح معلق فوق المكتب."),
    "between": ("The shop is between two banks.", "المتجر بين مصرفين."),
    "near": ("We live near the school.", "نسكن قرب المدرسة."),
    "far": ("The airport is not far.", "المطار ليس بعيداً."),
    "up": ("Climb up the stairs slowly.", "اصعد الدرج ببطء."),
    "down": ("Please sit down here.", "اجلس هنا من فضلك."),
    "left": ("Turn left after the mosque.", "انعطف يساراً بعد المسجد."),
    "right": ("The bank is on the right.", "المصرف على اليمين."),
    "straight": ("Go straight for two streets.", "امشِ مستقيماً لشارعين."),
    "good": ("Good work, keep going!", "عمل جيد، واصل!"),
    "well": ("He speaks Arabic well.", "يتحدث العربية جيداً."),
    "bad": ("The weather is bad today.", "الجو سيء اليوم."),
    "of course": ("Of course, I will help you.", "بالتأكيد سأساعدك."),
    "good morning": ("Good morning, teacher!", "صباح الخير يا معلم!"),
    "good evening": ("Good evening, everyone.", "مساء الخير جميعاً."),
    "good night": ("Good night, sleep well.", "تصبح على خير، نم جيداً."),
    "excuse me": ("Excuse me, where is the bank?", "عفواً، أين المصرف؟"),
    "how are you": ("How are you today, uncle?", "كيف حالك اليوم يا عم؟"),
    "nice to meet you": ("Nice to meet you, professor.", "سعيد بلقائي يا أستاذ."),
    "see you later": ("See you later, my friend.", "أراك لاحقاً يا صديقي."),
    "how much?": ("He asked: 'How much?'", "سأل: بكم؟"),
    "how much": ("He asked: 'How much?'", "سأل: بكم؟"),
    "no problem": ("No problem, take your time.", "لا مشكلة، خذ وقتك."),
    "you're welcome": ("You're welcome, dear guest.", "عفواً أيها الضيف الكريم."),
    "come on": ("Come on, we are late!", "هيا، لقد تأخرنا!"),
    "let's go": ("Let's go to the mosque.", "هيا بنا إلى المسجد."),
    "let us go": ("Let us go to the mosque.", "هيا بنا إلى المسجد."),
    "wait": ("Wait for me at the gate.", "انتظرني عند البوابة."),
    "listen": ("Listen to the teacher carefully.", "أنصت للمعلم بانتباه."),
    "look": ("Look at this beautiful view!", "انظر إلى المنظر الجميل!"),
    "help": ("Help me lift this box, please.", "ساعدني في رفع الصندوق."),
    "come": ("Come to my house tonight.", "تعال إلى بيتي الليلة."),
    "go": ("Go home before dark, son.", "عُد إلى البيت قبل الغروب."),
    "eat": ("Eat your breakfast every day.", "تناول فطورك كل يوم."),
    "drink": ("Drink water after the walk.", "اشرب ماءً بعد المشي."),
    "sleep": ("Sleep early before the trip.", "نم باكراً قبل الرحلة."),
    "read": ("Read one page every night.", "اقرأ صفحة كل ليلة."),
    "write": ("Write your name at the top.", "اكتب اسمك في الأعلى."),
    "speak": ("Speak slowly, please.", "تحدث ببطء من فضلك."),
    "open": ("Open the book to page ten.", "افتح الكتاب في صفحة عشرة."),
    "close": ("Close the door behind you.", "أغلق الباب خلفك."),
    "sit": ("Sit next to me, please.", "اجلس بجانبي من فضلك."),
    "stand": ("Stand up when the teacher comes.", "قف عندما يدخل المعلم."),
    "give": ("Give me the red pen, please.", "أعطني القلم الأحمر."),
    "take": ("Take your umbrella, it rains.", "خذ مظلتك، إنها تمطر."),
    "put": ("Put the milk in the fridge.", "ضع الحليب في الثلاجة."),
    "buy": ("Buy bread on your way home.", "اشترِ خبزاً في طريقك للبيت."),
    "study": ("Study for one hour daily.", "ادرس ساعة كل يوم."),
    "work": ("Work hard and be patient.", "اعمل بجد وكن صبوراً."),
    "run": ("Run in the park every morning.", "اركض في الحديقة كل صباح."),
    "walk": ("Walk with me to the mosque.", "امشِ معي إلى المسجد."),
    "yes, please": ("Yes, please, one more cup.", "نعم من فضلك، فنجان آخر."),
    "here you are": ("Here you are, one ticket.", "تفضل، تذكرة واحدة."),
    "i don't know": ("I don't know this word yet.", "لا أعرف هذه الكلمة بعد."),
    "i am sorry": ("I am sorry for the delay.", "أنا آسف على التأخير."),
    "one moment": ("One moment, I am coming.", "لحظة واحدة، أني قادم."),
    "just a moment": ("Just a moment, please.", "لحظة من فضلك."),
    "what time is it?": ("He asked: 'What time is it?'", "سأل: كم الساعة؟"),
    "where are you from?": ("She asked: 'Where are you from?'", "سألت: من أين أنت؟"),
    "my name is...": ("My name is... Ahmed.", "اسمي... أحمد."),
}

# Meaning-parallel frames per class. {w} = target, {t} = translationAr.
VERB = [
    ("Does he {w} every day?", "هل {t} كل يوم؟"),
    ("He does not {w} here.", "هو لا {t} هنا."),
    ("He wants to {w-l} now.", "يريد أن {t} الآن."),
    ("He likes to {w-l} with us.", "يحب أن {t} معنا."),
    ("It is nice to {w-l}.", "من الجميل أن {t}."),
    ("I saw him {w-l} yesterday.", "رأيته {t} أمس."),
    ("Let him {w-l} in peace.", "دعه {t} براحة."),
    ("He began to {w-l} early.", "بدأ {t} مبكراً."),
    ("Try to {w-l} this time.", "حاول أن {t} هذه المرة."),
    ("He must {w-l} today.", "يجب أن {t} اليوم."),
    ("Can he {w-l} alone?", "هل يستطيع أن {t} وحده؟"),
    ("He plans to {w-l} soon.", "ينوي أن {t} قريباً."),
]

NOUN_BARE = [  # translationAr without ال
    ("I need a {w} today.", "أحتاج {t} اليوم."),
    ("I bought a {w} yesterday.", "اشتريت {t} أمس."),
    ("I saw a {w} in the market.", "رأيت {t} في السوق."),
    ("We have a {w} at home.", "عندي {t} في البيت."),
    ("Give me a {w}, please.", "أعطني {t} من فضلك."),
    ("Do you want a {w}?", "هل تريد {t}؟"),
    ("He is holding a {w}.", "يحمل {t} في يده."),
    ("She gave him a {w}.", "أعطته {t}."),
    ("They talked about a {w}.", "تحدثوا عن {t}."),
    ("Put the {w} on the table.", "ضع {t} على الطاولة."),
    ("A {w} is on the chair.", "{t} على الكرسي."),
    ("He drew a {w} on paper.", "رسم {t} على الورق."),
]

NOUN_DEF = [  # translationAr starts with ال
    ("What do you think of the {w}?", "ما رأيك في {t}؟"),
    ("We talked about the {w} today.", "تحدثنا اليوم عن {t}."),
    ("Where is the {w}, mother?", "أين {t} يا أمي؟"),
    ("I know the {w} very well.", "أعرف {t} جيداً."),
    ("{t} is very useful here.", "{t} مفيد جداً هنا."),
    ("He wrote about the {w}.", "كتب عن {t}."),
]

ADJ = [
    ("He is very {w}.", "هو {t} جداً."),
    ("My friend is {w}.", "صديقي {t}."),
    ("That boy is {w}.", "ذلك الولد {t}."),
    ("He is a {w} man.", "إنه رجل {t}."),
    ("His brother is {w}.", "أخوه {t}."),
    ("Ahmed is {w} today.", "أحمد {t} اليوم."),
    ("The old man is {w}.", "الرجل العجوز {t}."),
    ("This story is {w}.", "هذه القصة {t}."),
]

ADV_STEP = [  # pure adverbs
    ("He stepped {w} from the door.", "خطا {t} عن الباب."),
    ("The car moved {w} slowly.", "تحركت السيارة {t} ببطء."),
    ("Look {w} before you answer.", "انظر {t} قبل أن تجيب."),
]
ADV_GOAL = [  # directional adverbials followed by a place
    ("He walked {w} the old market.", "مشى {t} السوق القديم."),
    ("She pointed {w} the mosque.", "أشارت {t} المسجد."),
    ("The road goes {w} the river.", "الطريق يذهب {t} النهر."),
]

NUM = [
    ("I have {w} books at home.", "عندي {t} كتب في البيت."),
    ("He waited {w} minutes there.", "انتظر هناك {t} دقائق."),
    ("The class has {w} students.", "الصف فيه {t} طلاب."),
    ("We stayed {w} days in Cairo.", "بقينا في القاهرة {t} أيام."),
    ("She bought {w} apples.", "اشترت {t} تفاحات."),
]

SENTENCE_Q = [
    ("He asked: '{w}'", "سأل: {t}"),
    ("{w} Tell me, please.", "{t} أخبرني من فضلك."),
    ("She wrote: '{w}'", "كتبت: {t}"),
    ("He asked me: '{w}'", "سألني: {t}"),
]
DIRECT = [
    ("He said: '{w}'", "قال: {t}"),
    ("She wrote: '{w}'", "كتبت: {t}"),
    ("He told me: '{w}'", "أخبرني: {t}"),
    ("He said, '{w}' and smiled.", "قال: {t} وابتسم."),
]
PHRASE_I = [
    ("{w}, my friend!", "{t} يا صديقي!"),
    ("He said: '{w}'", "قال: {t}"),
    ("{w}, dear teacher.", "{t} يا أستاذي العزيز."),
]
IMPERATIVE = [
    ("{w}, please.", "{t} من فضلك."),
    ("Please, {w-l}.", "من فضلك، {t}."),
    ("He told me: '{w}'", "قال لي: {t}"),
]

# Noun frames routed by semantic subtype of the Arabic translation.
NOUN_FRAMES = {
    "person": [
        ("I talked to the {w} yesterday.", "تحدثت إلى {t} أمس."),
        ("The {w} helped us a lot.", "ساعدنا {t} كثيراً."),
        ("Do you know the {w}?", "هل تعرف {t}؟"),
    ],
    "place": [
        ("We visited the {w} last week.", "زرنا {t} الأسبوع الماضي."),
        ("Let us go to the {w} now.", "لنذهب إلى {t} الآن."),
        ("The {w} is near the mosque.", "{t} قريب من المسجد."),
    ],
    "food": [
        ("I bought {w} for dinner.", "اشتريت {t} للعشاء."),
        ("We need {w} for the cake.", "نحتاج {t} للكيك."),
        ("He put {w} on the table.", "وضع {t} على الطاولة."),
    ],
    "animal": [
        ("We saw a {w} on the trip.", "رأينا {t} في الرحلة."),
        ("Look at that {w}!", "انظر إلى {t}!"),
    ],
    "vehicle": [
        ("He rides the {w} to work.", "يركب {t} إلى العمل."),
        ("The {w} stopped at the gate.", "توقف {t} عند البوابة."),
    ],
    "time": [
        ("See you on {w}!", "أراك يوم {t}!"),
        ("{w} is a busy day for us.", "{t} يوم مشغول بالنسبة لنا."),
    ],
    None: [
        ("This lesson is about the {w}.", "هذا الدرس عن {t}."),
        ("The teacher explained the {w} today.", "شرح المعلم {t} اليوم."),
        ("I read about {w-l} in the book.", "قرأت عن {t} في الكتاب."),
        ("Find the {w} in the picture.", "ابحث عن {t} في الصورة."),
        ("Do you know the word '{w}'?", "هل تعرف كلمة '{w}'؟"),
        ("He wrote a sentence with {w-l}.", "كتب جملة بها {t}."),
    ],
}

# Article-free universal frames for targets that already start with a/an/the.
NOUN_BARE_EN = [
    ("Do you know the word '{w}'?", "هل تعرف كلمة '{w}'؟"),
    ("The teacher explained the word '{w}'.", "شرح المعلم كلمة '{w}' اليوم."),
    ("I read the word '{w}' in the book.", "قرأت كلمة '{w}' في الكتاب."),
]


def frames_for(cls: str, word: dict, course: str):
    if cls == "verb":
        return VERB
    if cls == "num":
        return NUM
    if cls == "noun":
        target = (word.get("target") or "").strip().lower()
        if target.startswith(("a ", "an ", "the ")):
            return NOUN_BARE_EN
        t = (word.get("translationAr") or "").strip()
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
