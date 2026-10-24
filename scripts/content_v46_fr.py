#!/usr/bin/env python3
"""v4.6 content expansion — FRENCH: units 24-25 (B2 -> C1).

u24 Argumentation & Médias  (3 lessons x 10 words)
u25 Monde professionnel     (3 lessons x 10 words)
Every vocab item: id, target, translationAr, phonetic (Arabic
transliteration), emoji (unique within its lesson), exampleTarget,
exampleAr. Appends to course_fr.json (append-only rule: existing ids
untouched). Pre-flight collision check aborts before writing. Run:
python3 scripts/content_v46_fr.py
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
PATH = os.path.join(ROOT, 'assets', 'data', 'course_fr.json')


def v(vid, target, ar, ph, emoji, ex_t, ex_a):
    return {
        'id': f'fr_{vid}',
        'target': target,
        'translationAr': ar,
        'phonetic': ph,
        'emoji': emoji,
        'exampleTarget': ex_t,
        'exampleAr': ex_a,
    }


U24 = {
    'id': 'fr_u24',
    'color': '#2563EB',
    'titleAr': 'الحجاج والإعلام',
    'titleEn': 'Argumentation & Médias',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'fr_u24_l1',
            'titleAr': 'التعبير عن الرأي',
            'titleEn': 'Exprimer son opinion',
            'vocab': [
                v('selon_moi', 'Selon moi', 'في رأيي', 'سُلون موا', '💭',
                  "Selon moi, ce choix est sage.",
                  'في رأيي هذا اختيار حكيم.'),
                v('a_mon_avis', "À mon avis", 'برأيي', 'آ مون أفّي', '🗨️',
                  "À mon avis, il a raison.",
                  'برأيي إنه محق.'),
                v('en_fait', 'En fait', 'في الحقيقة', 'أون فِه', '🔎',
                  "En fait, tout a changé.",
                  'في الحقيقة تغير كل شيء.'),
                v('toutefois', 'Toutefois', 'ومع ذلك', 'توتفوا', '🔁',
                  "Toutefois, le risque demeure.",
                  'ومع ذلك يبقى الخطر.'),
                v('neanmoins', 'Néanmoins', 'بيد أن', 'نيّآنموان', '🎭',
                  "Néanmoins, nous avançons.",
                  'بيد أننا نمضي قدماً.'),
                v('par_contre', 'Par contre', 'في المقابل', 'بار كونتر', '🔀',
                  "Par contre, le prix monte.",
                  'في المقابل يرتفع السعر.'),
                v('d_ailleurs', "D'ailleurs", 'علاوة على ذلك', 'دارير', '➕',
                  "D'ailleurs, il l'a dit lui-même.",
                  'علاوة على ذلك قالها بنفسه.'),
                v('en_revanche', 'En revanche', 'بالمقابل', 'أون رُفّانش', '⚖️',
                  "En revanche, la qualité baisse.",
                  'بالمقابل تنخفض الجودة.'),
                v('autrement_dit', 'Autrement dit', 'بعبارة أخرى', 'أوترمون دي', '♻️',
                  "Autrement dit, il faut choisir.",
                  'بعبارة أخرى يجب أن نختار.'),
                v('en_somme', 'En somme', 'خلاصة القول', 'أون سوم', '📝',
                  "En somme, l'expérience réussit.",
                  'خلاصة القول التجربة تنجح.'),
            ],
        },
        {
            'id': 'fr_u24_l2',
            'titleAr': 'فن النقاش',
            'titleEn': 'Débattre',
            'vocab': [
                v('argument', 'Un argument', 'حجة', 'أن أرغيومون', '🗡️',
                  "Son argument était solide.",
                  'كانت حجته متينة.'),
                v('debattre', 'Débattre', 'يجادل ويناقش', 'دِيباتر', '🥊',
                  "Nous débattrons la question demain.",
                  'سنناقش المسألة غداً.'),
                v('refuter', 'Réfuter', 'يدحّض', 'ريفيوتِه', '🛡️',
                  "Elle a réfuté chaque objection.",
                  'دحضت كل اعتراض.'),
                v('appuyer', 'Appuyer', 'يدعم ويؤيّد', 'أپوييه', '🤝',
                  "Je vais appuyer cette réforme.",
                  'سأؤيد هذا الإصلاح.'),
                v('objecter', 'Objecter', 'يعترض بحجة', 'أوبجكتِيه', '❌',
                  "Objectez-vous cette décision ?",
                  'هل تعترض على هذا القرار؟'),
                v('trancher', 'Trancher', 'يحسم النقاش', 'ترانشيه', '🎯',
                  "Le débatteur a tranché la question.",
                  'حسم المُناقش المسألة.'),
                v('point_de_vue', 'Un point de vue', 'وجهة نظر', 'أن بوان دو فو', '👓',
                  "Partagez votre point de vue.",
                  'شارك وجهة نظرك.'),
                v('relativiser', 'Relativiser', 'يضع في النسب', 'رُولاتيفيزيه', '🎚️',
                  "Il faut relativiser ce jugement.",
                  'يجب ضبط هذا الحكم في النسب.'),
                v('objection', 'Une objection', 'اعتراض', 'أن أوبجكسيون', '✋',
                  "Avez-vous une objection ?",
                  'هل لديك اعتراض؟'),
                v('conclure', 'Conclure', 'يخلص ويستنتج', 'كونكلير', '🏁',
                  "Concluons par un accord.",
                  'لنخلص إلى اتفاق.'),
            ],
        },
        {
            'id': 'fr_u24_l3',
            'titleAr': 'الصحافة والأخبار',
            'titleEn': 'Médias et actualité',
            'vocab': [
                v('manchette', 'Une manchette', 'عنوان رئيسي', 'أن مَنشيت', '📰',
                  "La manchette a choqué le pays.",
                  'فاجأ العنوان الرئيسي البلاد.'),
                v('journaliste', 'Un journaliste', 'صحفي', 'أن جورناليست', '🎤',
                  "Le journaliste a vérifié les faits.",
                  'تحقق الصحفي من الوقائع.'),
                v('source', 'Une source', 'مصدر', 'أن سُرس', '🕳️',
                  "Cite toujours ta source.",
                  'اذكر مصدرك دائماً.'),
                v('couverture', 'La couverture', 'تغطية إعلامية', 'لا كوفَرتير', '📡',
                  "La couverture était en direct.",
                  'كانت التغطية مباشرة.'),
                v('faits', 'Les faits', 'الوقائع', 'ليه فِه', '📌',
                  "Les faits parlent d'eux-mêmes.",
                  'الوقائع تتحدث عن نفسها.'),
                v('rumeur', 'Une rumeur', 'إشاعة', 'أن رُيمِر', '🌀',
                  "La rumeur s'est répandue vite.",
                  'انتشرت الإشاعة بسرعة.'),
                v('sondage', 'Un sondage', 'استطلاع رأي', 'أن سونداج', '📊',
                  "Le sondage prédit un changement.",
                  'يتوقع الاستطلاع تحولاً.'),
                v('censure', 'La censure', 'رقابة', 'لا سانسير', '🚫',
                  "La censure a gêné le débat.",
                  'أعاقت الرقابة النقاش.'),
                v('interview', 'Une interview', 'مقابلة صحفية', 'أن إنترڤيو', '🎬',
                  "Son interview a marqué les esprits.",
                  'تركت مقابلته أثراً في الأذهان.'),
                v('depeche', 'Une dépêche', 'نبأة إخبارية', 'أن دِيبيش', '🌍',
                  "La dépêche est arrivée à l'instant.",
                  'وصلت النبأة الإخبارية للحظة.'),
            ],
        },
    ],
}

U25 = {
    'id': 'fr_u25',
    'color': '#9333EA',
    'titleAr': 'عالم العمل',
    'titleEn': 'Monde professionnel',
    'cefr': 'C1',
    'lessons': [
        {
            'id': 'fr_u25_l1',
            'titleAr': 'التوظيف والمقابلات',
            'titleEn': 'Recrutement',
            'vocab': [
                v('embauche', 'Une embauche', 'توظيف', 'أن أونبوش', '🪑',
                  "L'embauche a été rapide.",
                  'كان التوظيف سريعاً.'),
                v('cv', 'Un CV', 'سيرة ذاتية', 'أن سِي فِه', '📄',
                  "Mettez à jour votre CV.",
                  'حدّث سيرتك الذاتية.'),
                v('candidature', 'Une candidature', 'طلب وظيفة', 'أن كانديداتير', '📬',
                  "Ma candidature a été acceptée.",
                  'قُبل طلبي للوظيفة.'),
                v('competence', 'Une compétence', 'مهارة', 'أن كومبيطانس', '🛠️',
                  "Cette compétence est recherchée.",
                  'هذه المهارة مطلوبة.'),
                v('experience', "L'expérience", 'خبرة', 'ليكسبيريونس', '🧭',
                  "L'expérience compte autant.",
                  'الخبرة تُحسب أيضاً.'),
                v('recruter', 'Recruter', 'يوظّف', 'روكرِوتِه', '🧲',
                  "L'équipe recrute trois ingénieurs.",
                  'توظف الفريق ثلاثة مهندسين.'),
                v('salaire', 'Un salaire', 'راتب', 'أن سالير', '💰',
                  "Le salaire est négociable.",
                  'الراتب قابل للتفاوض.'),
                v('periode_essai', "Une période d'essai", 'فترة تجربة',
                  'أن بييريود دِسيه', '⏳',
                  "La période d'essai dure trois mois.",
                  'تدوم فترة التجربة ثلاثة أشهر.'),
                v('poste', 'Un poste', 'منصب', 'أن بوست', '🪧',
                  "Ce poste exige du voyage.",
                  'يتطلب هذا المنصب سفراً.'),
                v('postuler', 'Postuler', 'يتقدّم لوظيفة', 'بوستيوليه', '📨',
                  "Postulez avant vendredi.",
                  'تقدّم قبل الجمعة.'),
            ],
        },
        {
            'id': 'fr_u25_l2',
            'titleAr': 'الاجتماعات والمشاريع',
            'titleEn': 'Réunions et projets',
            'vocab': [
                v('ordre_jour', "Un ordre du jour", 'جدول أعمال', 'أن أوردر دو جور', '📋',
                  "Voici l'ordre du jour.",
                  'هذا جدول الأعمال.'),
                v('echeance', 'Une échéance', 'موعد نهائي', 'أن إيشانس', '⏰',
                  "L'échéance approche vite.",
                  'يقترب الموعد النهائي بسرعة.'),
                v('compte_rendu', 'Un compte rendu', 'محضر اجتماع', 'أن كونت رونديو', '🖊️',
                  "Rédigez le compte rendu.",
                  'اكتب محضر الاجتماع.'),
                v('deleguer', 'Déléguer', 'يفوّض', 'دِليغيه', '🤲',
                  "Savoir déléguer est un art.",
                  'معرفة التفويض فن.'),
                v('objectif', 'Un objectif', 'هدف', 'أن أوبجكتيف', '🎯',
                  "L'objectif est clair.",
                  'الهدف واضح.'),
                v('productivite', 'La productivité', 'إنتاجية', 'لا برودكتيفيتيه', '⚙️',
                  "La productivité a augmenté.",
                  'ارتفعت الإنتاجية.'),
                v('retard', 'Un retard', 'تأخير', 'أن روطار', '🐢',
                  "Un retard de deux semaines.",
                  'تأخير بأسبوعين.'),
                v('avancer', 'Avancer', 'يتقدّم بالعمل', 'أفّانسيه', '🏗️',
                  "Le projet avance bien.",
                  'يتقدم المشروع جيداً.'),
                v('reunion', 'Une réunion', 'اجتماع', 'أن رييونيون', '🚪',
                  "La réunion commence à neuf heures.",
                  'يبدأ الاجتماع في التاسعة.'),
                v('budget', 'Un budget', 'ميزانية', 'أن بيوجيه', '🧮',
                  "Le budget a été approuvé.",
                  'قُبلت الميزانية.'),
            ],
        },
        {
            'id': 'fr_u25_l3',
            'titleAr': 'المسار المهني',
            'titleEn': 'Carrière',
            'vocab': [
                v('promotion_fr', 'Une promotion', 'ترقية', 'أن بروموسيون', '🚀',
                  "Elle mérite une promotion.",
                  'إنها تستحق ترقية.'),
                v('echelon', 'Un échelon', 'درجة وظيفية', 'أن إيشلون', '🪜',
                  "Il a gravi chaque échelon.",
                  'صعد كل درجة وظيفية.'),
                v('reconversion', 'La reconversion', 'تحول مهني', 'لا رُوكونفِرسيون', '🔄',
                  "Sa reconversion a réussi.",
                  'نجح تحوله المهني.'),
                v('formation', 'Une formation', 'تدريب وتكوين', 'أن فورماسيون', '🎓',
                  "Une formation est prévue en mai.",
                  'تدريب مقرر في مايو.'),
                v('retraite', 'La retraite', 'تقاعد', 'لا رُوترِيت', '🌅',
                  "Il part à la retraite en juin.",
                  'يتقاعد في يونيو.'),
                v('concurrent', 'Un concurrent', 'منافس', 'أن كونكورَون', '🏇',
                  "Un concurrent a ouvert à côté.",
                  'افتتح منافسٌ بجوارنا.'),
                v('syndicat', 'Un syndicat', 'نقابة عمالية', 'أن سانديكا', '✊',
                  "Le syndicat a négocié.",
                  'تفاوضت النقابة.'),
                v('greve', 'Une grève', 'إضراب', 'أن غريف', '✋',
                  "La grève a duré trois jours.",
                  'استمر الإضراب ثلاثة أيام.'),
                v('entreprise', 'Une entreprise', 'شركة', 'أن أونتربريز', '🏢',
                  "Son entreprise emploie cinquante personnes.",
                  'توظف شركته خمسين شخصاً.'),
                v('dirigeant', 'Un dirigeant', 'تنفيذي رئيسي', 'أن ديريجان', '👑',
                  "Le dirigeant a démissionné.",
                  'استقال الرئيس التنفيذي.'),
            ],
        },
    ],
}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    existing_units = {u['id'] for u in data['units']}
    existing_ids = {
        item['id']
        for u in data['units']
        for l in u.get('lessons', [])
        for item in l.get('vocab', [])
    }
    collisions = [
        item['id']
        for unit in (U24, U25)
        for l in unit['lessons']
        for item in l['vocab']
        if item['id'] in existing_ids
    ]
    if collisions:
        print('FATAL: vocab id collisions:', sorted(set(collisions)))
        sys.exit(1)
    added = 0
    for unit in (U24, U25):
        if unit['id'] not in existing_units:
            data['units'].append(unit)
            added += 1
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    words = sum(
        len(l['vocab']) for unit in (U24, U25) for l in unit['lessons'])
    print(f'fr: appended {added} units, {words} words '
          f'(total units now {len(data["units"])})')


if __name__ == '__main__':
    main()
