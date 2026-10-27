#!/usr/bin/env python3
"""Q4/F4.1 hand-authored bank for French rows the frame system must not
touch. Keyed by the target string as it appears in course_fr.json
(lower-cased lookup)."""

# id-keyed hook (unused so far — target-keyed bank below)
BANK = {}


TARGET_BANK = {
    # adjectives the FR suffix heuristic mis-caught
    "sucré": ("Ce gâteau est très sucré.", "هذه الكعكة حلوة جداً."),
    "acide": ("Le citron est acide.", "الليمون حامض."),
    "amer": ("Ce thé est amer.", "هذا الشاي مرّ."),
    "salé": ("La soupe est salée.", "الحساء مالح."),
    "frais": ("Le poisson est frais.", "السمك طازج."),
    "frit": ("J'aime le poisson frit.", "أحب السمك المقلي."),
    "grillé": ("Le poulet grillé est prêt.", "الدجاج المشوي جاهز."),
    "cru": ("Je ne mange pas de poisson cru.", "لا آكل السمك نيئاً."),
    "juteux": ("Un fruit juteux et sucré.", "فاكهة عصيرية وحلوة."),
    # nouns miscaught by suffix heuristics (pain→ain, table→able …)
    "pain": ("J'achète du pain chaque matin.", "أشتري خبزاً كل صباح."),
    "table": ("La table est propre.", "الطاولة نظيفة."),
    "cheval": ("Le cheval court vite.", "الحصان يجري بسرعة."),
    "hôpital": ("Elle travaille à l'hôpital.", "تعمل في المستشفى."),
    "train": ("Le train arrive à midi.", "القطار يصل ظهراً."),
    "soif": ("J'ai soif après le sport.", "عطشان بعد الرياضة."),
    # adverbs
    "aujourd'hui": ("Aujourd'hui, il fait beau.", "اليوم الجو جميل."),
    "demain": ("Demain, nous voyageons.", "غداً نسافر."),
    "hier": ("Hier, il pleuvait.", "أمس كانت تمطر."),
    "après-midi": ("Nous dormons l'après-midi.", "ننام بعد الظهر."),
    "à droite": ("La pharmacie est à droite.", "الصيدلية على اليمين."),
    "à gauche": ("Tournez à gauche ici.", "انعطف على اليسار هنا."),
    "tout droit": ("Continuez tout droit jusqu'au feu.", "امش على الأمام حتى الإشارة."),
    # sentences & questions (French spacing before ? preserved)
    "où est la salle de bain ?": ("Excusez-moi, où est la salle de bain ?", "عفواً، أين الحمام ؟"),
    "la clé est sur la table": ("La clé est sur la table, je crois.", "المفتاح على الطاولة، أعتقد."),
    "un verre d'eau, s'il vous plaît": ("Un verre d'eau, s'il vous plaît.", "كأس ماء من فضلك."),
    "un thé à la menthe": ("Un thé à la menthe, s'il vous plaît.", "شاي بالنعناع من فضلك."),
    "on se voit à la fête !": ("On se voit à la fête ! À ce soir.", "نلتقي في الحفلة ! إلى المساء."),
    "et toi ?": ("Je vais bien. Et toi ?", "أنا بخير. وأنت ؟"),
    "comment tu t'appelles ?": ("Comment tu t'appelles ? Dis-moi.", "ما اسمك ؟ أخبرني."),
}
