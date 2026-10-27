#!/usr/bin/env python3
"""Q4/F4.3: add a 4th lesson to the eight core (A1/A2) three-lesson units
of the EN and UR courses. New lesson ids + new vocab ids are append-only;
existing rows are never touched. New rows ship WITHOUT examples — the
q4_gen_examples.py pass backfills them with containment-guaranteed frames
(same style as the rest of the corpus).
"""
import json
import os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "data")

NEW_LESSONS = {
    "en": [
        ("en_u13_l4", "في العمل اليومي", "A Day at Work", [
            ("en_u13_l4_engineer", "Engineer", "مهندس", "إن-جي-نير", "👷"),
            ("en_u13_l4_nurse", "Nurse", "ممرضة", "نيرس", "👩‍⚕️"),
            ("en_u13_l4_waiter", "Waiter", "نادل", "واي-تر", "🍽️"),
            ("en_u13_l4_driver", "Driver", "سائق", "دري-فر", "🚗"),
            ("en_u13_l4_teacher", "Teacher", "معلم", "تي-شر", "👨‍🏫"),
            ("en_u13_l4_painter", "Painter", "دهان", "بين-تر", "🎨"),
            ("en_u13_l4_office", "Office", "مكتب", "أو-فس", "🏢"),
            ("en_u13_l4_uniform", "Uniform", "زي رسمي", "يو-ني-فورم", "🧑‍✈️"),
            ("en_u13_l4_break", "Break", "استراحة", "بريك", "☕"),
            ("en_u13_l4_shift", "Shift", "وردية عمل", "شفت", "🕘"),
        ]),
        ("en_u14_l4_l4", None, None, []),  # placeholder removed below
        ("en_u14_l4", "مشترٍ حريص", "A Careful Shopper", [
            ("en_u14_l4_wallet", "Wallet", "محفظة نقود", "وال-لت", "👛"),
            ("en_u14_l4_coin", "Coin", "عملة معدنية", "كوين", "🪙"),
            ("en_u14_l4_change", "Change", "فكة", "تشينج", "🔁"),
            ("en_u14_l4_assistant", "Shop assistant", "مساعد المتجر", "أ-سيست-نت", "🧑‍🛍️"),
            ("en_u14_l4_cashier", "Cashier", "أمين الصندوق", "كاش-ير", "💵"),
            ("en_u14_l4_basket", "Basket", "سلة تسوق", "باس-كت", "🧺"),
            ("en_u14_l4_trolley", "Trolley", "عربة تسوق", "ترول-لي", "🛒"),
            ("en_u14_l4_bill", "Bill", "فاتورة", "بيل", "🧾"),
            ("en_u14_l4_online", "Online shopping", "تسوق إلكتروني", "أون-لاين", "💻"),
            ("en_u14_l4_queue", "Queue", "طابور انتظار", "كيو", "⏳"),
        ]),
        ("en_u15_l4", "جسمك يطلب صحتك", "Ask Your Body", [
            ("en_u15_l4_dentist", "Dentist", "طبيب أسنان", "دن-تيست", "🦷"),
            ("en_u15_l4_patient", "Patient", "مريض", "باي-شنت", "🛏️"),
            ("en_u15_l4_heart", "Heart", "قلب", "هارت", "❤️"),
            ("en_u15_l4_blood", "Blood", "دم", "بلاد", "🩸"),
            ("en_u15_l4_bone", "Bone", "عظم", "بون", "🦴"),
            ("en_u15_l4_muscle", "Muscle", "عضلة", "مس-ل", "💪"),
            ("en_u15_l4_brain", "Brain", "دماغ", "برين", "🧠"),
            ("en_u15_l4_throat", "Throat", "حلق", "ثروت", "🗣️"),
            ("en_u15_l4_lung", "Lung", "رئة", "لانغ", "🫁"),
            ("en_u15_l4_checkup", "Checkup", "فحص طبي", "تشيك-أب", "📋"),
        ]),
        ("en_u16_l4", "فصول السنة", "The Four Seasons", [
            ("en_u16_l4_spring", "Spring", "ربيع", "سب-رينغ", "🌸"),
            ("en_u16_l4_summer", "Summer", "صيف", "سا-مر", "☀️"),
            ("en_u16_l4_autumn", "Autumn", "خريف", "أو-تم", "🍂"),
            ("en_u16_l4_winter", "Winter", "شتاء", "وين-تر", "❄️"),
            ("en_u16_l4_cloud", "Cloud", "سحابة", "كلاود", "☁️"),
            ("en_u16_l4_snow", "Snow", "ثلج", "سنو", "🌨️"),
            ("en_u16_l4_ice", "Ice", "جليد", "آيس", "🧊"),
            ("en_u16_l4_breeze", "Breeze", "نسيم عليل", "بريز", "🍃"),
            ("en_u16_l4_frost", "Frost", "صقيع", "فرروست", "🥶"),
            ("en_u16_l4_seed", "Seed", "بذرة", "سيد", "🌱"),
        ]),
    ],
    "ur": [
        ("ur_u32_l4", "أفعال كل يوم", "روز کے فعل", [
            ("ur_u32_l4_uthna", "اٹھنا", "ينهض", "اٹھ-نا", "🛏️"),
            ("ur_u32_l4_baithna", "بیٹھنا", "يجلس", "بیٹھ-نا", "🪑"),
            ("ur_u32_l4_daalna", "ڈالنا", "يضع", "ڈال-نا", "📥"),
            ("ur_u32_l4_pakana", "پکانا", "يطبخ", "پکا-نا", "🍳"),
            ("ur_u32_l4_dhona", "دھونا", "يغسل", "دھو-نا", "🧼"),
            ("ur_u32_l4_bhoolna", "بھولنا", "ينسى", "بھول-نا", "🤦"),
            ("ur_u32_l4_yaad_karna", "یاد کرنا", "يتذكر", "یاد کر-نا", "💭"),
            ("ur_u32_l4_samajhna", "سمجھنا", "يفهم", "سمجھ-نا", "💡"),
            ("ur_u32_l4_sikhaana", "سکھانا", "يعلّم", "سکھا-نا", "📖"),
            ("ur_u32_l4_bulana", "بلانا", "ينادي", "بلا-نا", "📣"),
        ]),
        ("ur_u33_l4", "مشاعر أخرى", "مزید جذبات", [
            ("ur_u33_l4_naraaz", "ناراض", "غاضب", "نا-راض", "😠"),
            ("ur_u33_l4_mutmain", "مطمئن", "مطمئن", "مطم-ئن", "😌"),
            ("ur_u33_l4_pareshan", "پریشان", "قلق", "پری-شان", "😟"),
            ("ur_u33_l4_khushhaal", "خوشحال", "مبتهج", "خوش-حال", "🥳"),
            ("ur_u33_l4_ghareeb", "غریب", "فقير", "غری-ب", "🫙"),
            ("ur_u33_l4_ameer", "امیر", "غني", "ا-میر", "💰"),
            ("ur_u33_l4_sakhi", "سخی", "كريم", "سخ-ی", "🤲"),
            ("ur_u33_l4_bakheel", "بخیل", "بخيل", "بخ-یل", "🪙"),
            ("ur_u33_l4_hamdrad", "ہمدرد", "رحيم", "ہم-در-د", "🫶"),
            ("ur_u33_l4_umeedwar", "امیدوار", "متفائل", "امی-دوار", "🌤️"),
        ]),
        ("ur_u7_l4", "أرجاء البيت", "گھر کے حصے", [
            ("ur_u7_l4_kamra", "کمرہ", "غرفة", "کمر-ہ", "🚪"),
            ("ur_u7_l4_kitchen", "باورچی خانہ", "مطبخ", "باور-چی خانہ", "🍲"),
            ("ur_u7_l4_sahn", "صحن", "صحن", "صح-ن", "🏡"),
            ("ur_u7_l4_chhat", "چھت", "سقف", "چھت", "🏠"),
            ("ur_u7_l4_seerhi", "سیڑھی", "سلم", "سیڑھ-ی", "🪜"),
            ("ur_u7_l4_khirki", "کھڑکی", "نافذة", "کھڑ-کی", "🪟"),
            ("ur_u7_l4_bijli", "بجلی", "كهرباء", "بج-لی", "💡"),
            ("ur_u7_l4_paani", "پانی", "ماء", "پا-نی", "💧"),
            ("ur_u7_l4_gali", "گلی", "زقاق", "گ-لی", "🏘️"),
            ("ur_u7_l4_dukaan", "دکان", "متجر", "دکا-ن", "🏪"),
        ]),
        ("ur_u8_l4", "مذاق المطبخ", "رن گ کے ذائقے", [
            ("ur_u8_l4_namak", "نمک", "ملح", "نمک", "🧂"),
            ("ur_u8_l4_kali_mirch", "کالی مرچ", "فلفل أسود", "کالی مر-چ", "🖤"),
            ("ur_u8_l4_tail", "تیل", "زيت", "تی-ل", "🫗"),
            ("ur_u8_l4_aata", "آٹا", "طحين", "آٹا", "🌾"),
            ("ur_u8_l4_chawal", "چاول", "أرز", "چا-ول", "🍚"),
            ("ur_u8_l4_daal", "دال", "عدس", "دا-ل", "🥣"),
            ("ur_u8_l4_salad", "سلاد", "سلطة", "سلا-ڈ", "🥗"),
            ("ur_u8_l4_sharbat", "شربت", "شراب مُحلّى", "شر-بت", "🥤"),
            ("ur_u8_l4_baraf", "برف", "ثلج", "بر-ف", "🧊"),
            ("ur_u8_l4_massala", "مسالا", "بهار", "مسا-لا", "🍛"),
        ]),
    ],
}


def main():
    for lang, lessons in NEW_LESSONS.items():
        path = os.path.join(BASE, f"course_{lang}.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        by_id = {u["id"]: u for u in data["units"]}
        for lid, title_ar, title_en, vocab in lessons:
            if title_en is None:  # skip placeholder
                continue
            unit_id = lid.rsplit("_l", 1)[0]
            unit = by_id[unit_id]
            if any(l["id"] == lid for l in unit["lessons"]):
                print(f"  skip (exists): {lid}")
                continue
            unit["lessons"].append({
                "id": lid,
                "titleAr": title_ar,
                "titleEn": title_en,
                "vocab": [
                    {
                        "id": wid,
                        "target": target,
                        "translationAr": tar,
                        "phonetic": ph,
                        "emoji": em,
                    }
                    for (wid, target, tar, ph, em) in vocab
                ],
            })
            print(f"  added: {lid} ({len(vocab)} words)")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")


if __name__ == "__main__":
    main()
