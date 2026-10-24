// Learning path builder (v4.11): thematic domains + level tiers on top of
// the CEFR-tagged course units.
//
// Lets the learner declare a focus ("التجارة والأعمال" at "متوسط" level) and
// derives an ordered unit plan from the course content. Pure Dart — no
// Flutter imports; UI lives in screens/path_setup_screen.dart, tests in
// test/path_test.dart. The keyword catalog mirrors
// scripts/domain_mapping_sim.py: Latin keywords match whole words only
// (\b..\b — "\bsea" once matched "Seasons"), Arabic keywords match by
// substring, first domain in catalog order wins, and `daily` is the
// catch-all fallback so every unit belongs to exactly one domain.

import 'models.dart';

/// Coarse learner level — a band over the self-referenced CEFR tags
/// (A1–A2 / B1–B2 / C1+). Not an official certification.
enum LevelTier { beginner, intermediate, expert }

/// Thematic fields the learner can focus their path on.
enum PathDomain {
  basics,
  travel,
  food,
  health,
  tech,
  nature,
  culture,
  business,
  daily,
}

// v4.12: l10n keys + emoji for domains/tiers — pure string maps that live
// here (Flutter-free) so the engine, the learn-path banner, the setup
// wizard AND the placement result screen share one source of truth.
String pathDomainL10nKey(PathDomain d) => const {
      PathDomain.basics: 'domainBasics',
      PathDomain.travel: 'domainTravel',
      PathDomain.food: 'domainFood',
      PathDomain.health: 'domainHealth',
      PathDomain.tech: 'domainTech',
      PathDomain.nature: 'domainNature',
      PathDomain.culture: 'domainCulture',
      PathDomain.business: 'domainBusiness',
      PathDomain.daily: 'domainDaily',
    }[d]!;

String pathDomainEmoji(PathDomain d) => const {
      PathDomain.basics: '🔤',
      PathDomain.travel: '✈️',
      PathDomain.food: '🍽️',
      PathDomain.health: '🩺',
      PathDomain.tech: '💻',
      PathDomain.nature: '🌿',
      PathDomain.culture: '🎬',
      PathDomain.business: '🏪',
      PathDomain.daily: '🏠',
    }[d]!;

String pathTierL10nKey(LevelTier t) => const {
      LevelTier.beginner: 'tierBeginner',
      LevelTier.intermediate: 'tierIntermediate',
      LevelTier.expert: 'tierExpert',
    }[t]!;

String pathTierSubL10nKey(LevelTier t) => const {
      LevelTier.beginner: 'tierBeginnerSub',
      LevelTier.intermediate: 'tierIntermediateSub',
      LevelTier.expert: 'tierExpertSub',
    }[t]!;

class PathPlan {
  final PathDomain domain;

  /// The tier the learner asked for.
  final LevelTier tier;

  /// The tier actually used after relaxation (see [PathEngine.build]).
  final LevelTier effectiveTier;

  /// Unit indices in pedagogical order (CEFR ascending, course order as
  /// tiebreak). Indices refer to [Course.units].
  final List<int> unitIndices;

  final int lessonCount;
  final int wordCount;

  /// True when [effectiveTier] != [tier] because the requested band had no
  /// units in this domain (e.g. expert + basics).
  final bool tierRelaxed;

  const PathPlan({
    required this.domain,
    required this.tier,
    required this.effectiveTier,
    required this.unitIndices,
    required this.lessonCount,
    required this.wordCount,
    required this.tierRelaxed,
  });
}

class PathEngine {
  PathEngine._();

  static const _cefrOrder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  /// A1=0 .. C2=5; unknown tags rank 0 so hand-written units stay beginner.
  static int cefrRank(String cefr) {
    final i = _cefrOrder.indexOf(cefr.trim().toUpperCase());
    return i < 0 ? 0 : i;
  }

  /// A1–A2 → beginner, B1–B2 → intermediate, C1+ → expert.
  static LevelTier tierOfCefr(String cefr) {
    switch (cefrRank(cefr)) {
      case 0:
      case 1:
        return LevelTier.beginner;
      case 2:
      case 3:
        return LevelTier.intermediate;
      default:
        return LevelTier.expert;
    }
  }

  static bool cefrInTier(String cefr, LevelTier tier) =>
      tierOfCefr(cefr) == tier;

  /// Parses a stored tier name; unknown/null names yield null so corrupted
  /// payloads degrade to "no plan" instead of crashing.
  static LevelTier? tierByName(String? name) {
    for (final t in LevelTier.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  static PathDomain? domainByName(String? name) {
    for (final d in PathDomain.values) {
      if (d.name == name) return d;
    }
    return null;
  }

  /// Ordered domain catalog — first match wins. Latin keywords match whole
  /// words (case-insensitive); Arabic keywords match by substring. `daily`
  /// is intentionally absent: it is the fallback for unmatched titles.
  static const Map<PathDomain, List<String>> _catalog = {
    PathDomain.basics: [
      'basics', 'numbers', 'colors', 'days', 'alphabet', 'calendar', //
      'أساسيات', 'أرقام', 'الوقت', 'ألوان', 'أيام', 'تقويم',
    ],
    PathDomain.travel: [
      'travel', 'transport', 'airport', 'flying', 'hotel', 'beach', 'sea', //
      'سفر', 'مواصلات', 'مطار', 'طيران', 'فندق', 'شاطئ', 'بحر',
    ],
    PathDomain.food: [
      'food', 'drink', 'restaurant', 'kitchen', 'cook', 'flavor', 'cafe', //
      'طعام', 'شراب', 'مطعم', 'مطبخ', 'أطعمة', 'نكهات', 'مأكولات', 'حلويات',
    ],
    PathDomain.health: [
      'health', 'body', 'illness', 'medicine', 'doctor', 'emergency',
      'safety', 'symptom', //
      'صحة', 'جسم', 'مرض', 'علاج', 'طبيب', 'طوارئ', 'سلامة', 'أعراض',
    ],
    PathDomain.tech: [
      'technology', 'science', 'laboratory', 'internet', 'devices', //
      'تقنية', 'علوم', 'مختبر', 'أجهزة', 'إنترنت', 'تواصل',
    ],
    PathDomain.nature: [
      'animals', 'nature', 'weather', 'space', 'astronomy', 'geography',
      'farm', 'birds', 'insects', 'seasons', 'climate', 'countryside', //
      'حيوان', 'طبيعة', 'طقس', 'فضاء', 'فلك', 'جغرافيا', 'مزرعة', 'طيور',
      'حشرات', 'فصول', 'مناخ', 'ريف',
    ],
    PathDomain.culture: [
      'music', 'movie', 'entertainment', 'celebrations', 'traditions',
      'idioms', 'poetry', 'media', 'news', 'press', 'literary', //
      'موسيقى', 'أفلام', 'مناسبات', 'تقاليد', 'اصطلاح', 'محاور', 'شعر',
      'إعلام', 'أخبار', 'صحافة', 'ترفيه', 'أدب', 'تعبيرات', 'أعياد',
    ],
    PathDomain.business: [
      'business', 'economics', 'money', 'bank', 'office', 'work', 'job',
      'law', 'government', 'market', 'shopping', 'commerce', 'career', //
      'أعمال', 'تجارة', 'اقتصاد', 'مال', 'بنك', 'عمل', 'مهن', 'مكتب', 'سوق',
      'قانون', 'تسوق', 'حكومة', 'صفقات',
    ],
  };

  static bool _isLatin(String s) => s.runes.every((r) => r < 0x600);

  /// Domain of a single unit. Unmatched titles fall back to
  /// [PathDomain.daily], so every unit belongs to exactly one domain.
  static PathDomain domainOfUnit(Unit unit) {
    final latin = unit.titleEn.toLowerCase();
    for (final entry in _catalog.entries) {
      for (final kw in entry.value) {
        if (_isLatin(kw)) {
          final re = RegExp('\\b${RegExp.escape(kw)}\\b', caseSensitive: false);
          if (re.hasMatch(latin)) return entry.key;
        } else if (unit.titleAr.contains(kw)) {
          return entry.key;
        }
      }
    }
    return PathDomain.daily;
  }

  /// Indices of [course] units belonging to [domain], in course order.
  static List<int> domainUnits(Course course, PathDomain domain) {
    final out = <int>[];
    for (var i = 0; i < course.units.length; i++) {
      if (domainOfUnit(course.units[i]) == domain) out.add(i);
    }
    return out;
  }

  /// Builds the plan for [domain] × [tier]:
  ///  - keeps only units whose CEFR tag sits inside the tier band;
  ///  - when the band is empty in this domain (expert + basics), relaxes one
  ///    band at a time toward beginner before giving up;
  ///  - last resort: the domain's full unit list;
  ///  - orders picked units by CEFR rank (course order as tiebreak) so the
  ///    path always teaches easier material first.
  static PathPlan build(Course course, PathDomain domain, LevelTier tier) {
    final units = domainUnits(course, domain);
    var effective = tier;
    var picked = units
        .where((i) => cefrInTier(course.units[i].cefr, effective))
        .toList();
    const down = {
      LevelTier.expert: LevelTier.intermediate,
      LevelTier.intermediate: LevelTier.beginner,
    };
    while (picked.isEmpty) {
      final lower = down[effective];
      if (lower == null) break;
      effective = lower;
      picked = units
          .where((i) => cefrInTier(course.units[i].cefr, effective))
          .toList();
    }
    if (picked.isEmpty && units.isNotEmpty) {
      // Defensive: the requested tier had nothing even after relaxation —
      // fall back to the domain's whole list in course order.
      effective = tier;
      picked = units;
    }
    picked.sort((a, b) {
      final r = cefrRank(course.units[a].cefr)
          .compareTo(cefrRank(course.units[b].cefr));
      return r != 0 ? r : a.compareTo(b);
    });
    var lessons = 0;
    var words = 0;
    for (final i in picked) {
      for (final l in course.units[i].lessons) {
        lessons++;
        words += l.vocab.length;
      }
    }
    return PathPlan(
      domain: domain,
      tier: tier,
      effectiveTier: effective,
      unitIndices: List.unmodifiable(picked),
      lessonCount: lessons,
      wordCount: words,
      tierRelaxed: effective != tier,
    );
  }
}
