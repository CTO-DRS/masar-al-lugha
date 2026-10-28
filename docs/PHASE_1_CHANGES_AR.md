# PHASE 1 — سجل التغييرات (Change Log)

**الإصدار**: v5.17.0+42 | الالتزامات على `phase1/foundation` (أربع دفعات مُلتزمة، ثم دمج في main).

قاعدة السجل: كل ملف متغير له سبب واحد واضح. لا تغييرات تبعيات في وقت التشغيل، ولا تغيير بيانات، ولا تغيير هوية/تخزين.

---

## الدفعة B — الإصلاحات الأساسية (`408bbfc`)

| الملف | التغيير | السبب (معرّف التدقيق) |
|---|---|---|
| `lib/app_state.dart` | +4 حقول في `_resetInMemory`؛ استرداد في `catch` الاستيراد | H-2، M-1 |
| `lib/profile_store.dart` | تصفير حاويات المحرك قبل تطبيق الحمولة في `load()` | H-2 |
| `lib/screens/lesson_screen.dart` | حواجز `answered/_checkBusy/_finished` في `_check/_next/_showComplete/_showFailed` | H-3 |
| `lib/screens/flashcards.dart` | قفل `_rate` بعد الإطار | M-4 |
| `lib/screens/quick_review_screen.dart` | قفل `_rate` بعد الإطار | M-4 |
| `lib/screens/pronunciation_screen.dart` | بوابة `_started` + حالة فارغة + `_pickFocus` مملوك + حارس mounted | H-1، M-2/M-3 |
| `lib/screens/dictionary.dart` | فهرس بحث مخلَّد + ذاكرة (course,query) + directionOf على المدخل + hex محمي + صف العداد مرن | P-1، RTL-1، L-1، M-6 |
| `lib/screens/learn_path.dart` | حساب NBA مرة واحدة + مرشح تنقل + تأكيد إلغاء المسار + صف الـhero مرن | P-2، M-5، L-2، M-6 |
| `lib/screens/profile.dart` | directionOf لسطر الكلمات الضعيفة | RTL-2 |
| `lib/screens/settings.dart` | dispose لمتحكّمي الحوارين (try/finally) | L-4 |
| `lib/widgets/common.dart` | shouldRepaint يقارن track | L-3 |
| `lib/services/stt.dart` | try/catch حول listen | L-5 |
| `lib/l10n.dart` | مفتاحان جدد `pathClearPlanBody` (ع/EN) | L-2 |
| `test/phase1_fixes_test.dart` | **جديد** — 11 اختبار انحدار | إثبات كل إصلاح |

## الدفعة C — الهوية البصرية (`28bb0d7`)

| الملف | التغيير | السبب |
|---|---|---|
| `lib/theme.dart` | AppColors بأكملها بقيم «فضاء مسار» المُتحقق منها (31 زوج WCAG قبل الهبوط) + purpleText جديد | المسار الثالث (توحيد الهوية) |
| `lib/design_system.dart` | **جديد** — MasarDS (مسافات/أنصاف/ارتفاعات/دلالية) + GlassSurface (زجاج انتقائي ببديل صلب) | المساران الثالث والرابع |
| `lib/screens/home_shell.dart` | نافذة تبديل الدورة فوق GlassSurface + استيراد design_system | تطبيق الزجاج الانتقائي |
| `lib/screens/profile.dart` | التدرج السداسي المباشر → رمزا الهوية | PR-1 (انتهاك رموز) |
| `lib/screens/insights_screen.dart` | `Colors.grey` → `context.mutedText` | I2 (انتهاك رموز/وضع داكن) |
| `test/contrast_test.dart` | إعادة تثبيت الأزواج بقيم الهوية (نفس العتبات والتأكيدات السالبة) | تثبيت الكتالوج الجديد |

## الدفعة D — حالة التبويبات والتخطيط (`1773a6c`)

| الملف | التغيير | السبب |
|---|---|---|
| `lib/screens/home_shell.dart` | `pages[tab]` → IndexedStack كسول + `_visited`؛ نقر بلاطة التنقل عبر `switchTab` (انحدار اكتشفه الاختبار)؛ ارتفاع 72 وحشو 14 | D-1، M-6 |
| `lib/screens/learn_path.dart` | صف الـhero بـExpanded | M-6 |
| `test/phase1_fixes_test.dart` | اختبار رحلة تبويب تحفظ استعلام القاموس | D-1 |

## الدفعة E — الأمان وCI

| الملف | التغيير | السبب |
|---|---|---|
| `.github/workflows/build-apk.yml` | خطوة «Sign-check»: إعلان صريح في ملخص التشغيل عند توقيع debug (غياب key.properties) | «لا توقيع debug صامت» |

## الدفعة F — الإصدار والتوثيق

| الملف | التغيير | السبب |
|---|---|---|
| `pubspec.yaml` | `5.16.0+41 → 5.17.0+42` | إصدار المرحلة |
| `lib/l10n.dart` | سلسلتا الإصدار → 5.17.0 | اتساق الواجهة |
| `test/path_test.dart` | تثبيتا الإصدار → 5.17.0 | الاختبار المثبّت |
| `docs/ROADMAP.md` | رأس الجدول + صف v5.17 + قسم v5.17 كامل (بما فيه المتبقي بصدق) | باب التوثيق |
| `docs/PHASE_1_AUDIT_AR.md` / `PHASE_1_DESIGN_SYSTEM_AR.md` / `PHASE_1_TEST_REPORT_AR.md` / `PHASE_1_CHANGES_AR.md` | **جديدة** | مخرجات المرحلة المطلوبة |

## التبعيات والبيانات

- **صفر تغيير في التبعيات** (النطاقات كما هي، `pubspec.lock` كما هو — ملاحظة: 27 إصدارًا أعلى غير متوافق معروف؛ الترقية الجماعية ممنوعة بموجب التكليف).
- **صفر تغيير في المحتوى التعليمي أو مخطط التخزين**: 162 وحدة / 6346 كلمة / schema v2 — متوافق مع ملفات v5.x السابقة (اختبارات المحتوى وvalidator PASS).

## المخاطر المتبقية (بعد المرحلة)

1. إعادة البناء الجذرية المزدوجة (ListenableBuilder+InheritedNotifier) — موثقة بالدليل، القياس أولًا في المرحلة الثانية.
2. keystore الإنتاج غير متوفر — APK موقّع debug (مُعلَن صراحةً في CI الآن).
3. نصوص القراءة/المحادثة الآلية «تحتاج مراجعة بشرية» (مسبق، خارج النطاق).
4. تدوير PAT من جانب المستخدم (ظهر في محادثة سابقة).
5. نصوص صندوق إصدار CI ما زالت تصف ميزات v4.x — تجميلي، للإصدار التالي.
