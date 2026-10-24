// App state: courses, progress, gamification, badges.
// v4.1: persistence (load/save/debounce/migration) extracted to ProfileStore
// — AppState delegates to [store] and stays the domain + notification layer.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'insights.dart';
import 'models.dart';
import 'profile_store.dart';
import 'srs.dart';
import 'theme.dart';

class BadgeDef {
  final String id;
  final IconData icon;
  final Color color;
  const BadgeDef(this.id, {required this.icon, required this.color});
}

class AppState extends ChangeNotifier {
  // ---- content ----
  final Map<String, Course> courses = {};
  String courseId = 'en';

  // ---- ui ----
  String uiLocale = 'ar'; // 'ar' | 'en'

  // ---- progress ----
  int xp = 0;
  int streak = 0;
  String? lastActiveDay; // yyyy-MM-dd
  int dailyGoal = 20;
  int dailyXp = 0;
  String dailyXpDay = '';
  Map<String, int> xpLog = {}; // yyyy-MM-dd -> xp earned (last 30 days)
  int cardsReviewed = 0;
  int totalAnswers = 0;
  int correctAnswers = 0;
  Map<String, int> lessonStars = {}; // lessonId -> stars 1..3
  Map<String, CardData> cards = {}; // vocabId -> card
  List<String> badges = [];

  bool onboardingDone = false;
  bool loaded = false;

  // ---- v4.0 settings & engine ----
  bool darkMode = false; // null-aware tri-state handled by settings UI
  bool reduceMotion = false;
  bool ttsEnabled = true;
  double ttsRate = 0.9;
  Map<String, bool> placementDone = {}; // courseId -> placed
  Map<String, int> wordMistakes = {}; // vocabId -> lifetime mistake count
  Map<String, int> placementSkip =
      {}; // courseId -> flat lesson index unlocked by placement
  int newCardsToday = 0; // new SRS cards introduced today
  String newCardsDay = '';

  // ---- v4.4 local intelligence (all on-device, see lib/insights.dart) ----
  /// "vocabIdA|vocabIdB" (lexically sorted) -> times the learner picked B
  /// when A was correct. Bounded by [_maxConfusionPairs].
  Map<String, int> confusionPairs = {};

  /// Answers per hour-of-day bucket (0..23) for the best-study-time rule.
  List<int> hourTotal = List<int>.filled(24, 0);
  List<int> hourCorrect = List<int>.filled(24, 0);

  /// dayKey -> [total, correct] answers (last 30 days) — accuracy trend.
  Map<String, List<int>> answerLog = {};

  /// courseId -> starred vocab ids (newest first) — favorites deck.
  Map<String, List<String>> favorites = {};

  static const int _maxConfusionPairs = 60;
  static const int _keepConfusionPairs = 40;

  /// Current progress schema version (marker lives in ProfileStore).
  static const int progressSchema = ProfileStore.progressSchema;

  /// v4.1: persistence backend (keys, migration, debounced writes).
  /// One store per AppState; created lazily because field initializers
  /// cannot reference `this`.
  late final ProfileStore store = ProfileStore(this);

  // ---- badges registry (v2.0: 15 badges) ----
  static const List<BadgeDef> badgeDefs = [
    BadgeDef('first_lesson', icon: Icons.emoji_events, color: AppColors.blue),
    BadgeDef('five_lessons',
        icon: Icons.local_fire_department, color: AppColors.orange),
    BadgeDef('lessons_20', icon: Icons.school, color: AppColors.green),
    BadgeDef('xp_100', icon: Icons.star, color: AppColors.yellow),
    BadgeDef('xp_500', icon: Icons.stars, color: AppColors.yellow),
    BadgeDef('xp_1000', icon: Icons.diamond, color: AppColors.blue),
    BadgeDef('streak_3', icon: Icons.whatshot, color: AppColors.red),
    BadgeDef('streak_7', icon: Icons.bolt, color: AppColors.red),
    BadgeDef('streak_14',
        icon: Icons.local_fire_department, color: AppColors.red),
    BadgeDef('perfect', icon: Icons.military_tech, color: AppColors.green),
    BadgeDef('perfect_5',
        icon: Icons.workspace_premium, color: AppColors.yellow),
    BadgeDef('cards_50', icon: Icons.style, color: AppColors.purple),
    BadgeDef('cards_200', icon: Icons.auto_stories, color: AppColors.purple),
    BadgeDef('all_en_units', icon: Icons.flag, color: AppColors.green),
    BadgeDef('all_ur_units', icon: Icons.flag, color: AppColors.green),
    BadgeDef('all_fr_units', icon: Icons.flag, color: AppColors.yellow),
    BadgeDef('both_courses', icon: Icons.verified, color: AppColors.blue),
    BadgeDef('polyglot', icon: Icons.translate, color: AppColors.purple),
  ];

  // Newly earned badges waiting to be celebrated in UI.
  final List<String> pendingBadges = [];

  Course get course => courses[courseId] ?? courses.values.first;

  int get accuracyPct {
    if (totalAnswers == 0) return 0;
    return ((correctAnswers / totalAnswers) * 100).round();
  }

  int get wordsLearned => cards.values.where((c) => c.state == 'review').length;

  int get lessonsCompleted => lessonStars.length;

  int get perfectLessons => lessonStars.values.where((s) => s == 3).length;

  // Level system: 100 XP per level (v2.0).
  int get level => (xp / 100).floor() + 1;

  double get levelProgress => (xp % 100) / 100;

  int get xpToNextLevel => 100 - (xp % 100);

  /// XP earned on each of the last 7 days (oldest first).
  List<(String, int)> get last7Days {
    final now = DateTime.now();
    final out = <(String, int)>[];
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      var v = xpLog[key] ?? 0;
      if (i == 0 && dailyXpDay == key) v = dailyXp; // today is live
      out.add((key, v));
    }
    return out;
  }

  bool isGoalDone(String day) => dailyXpDay == day && dailyXp >= dailyGoal;

  // ================= lifecycle (delegated to ProfileStore, v4.1) ==========

  Future<void> load() async {
    await store.load();
    notifyListeners();
  }

  Future<void> save() => store.save();

  /// Marks state dirty and schedules a debounced save. Heavy callers
  /// (every answer tap) should use this instead of awaiting [save].
  void scheduleSave() => store.scheduleSave();

  /// True when there are unsaved changes (debug/diagnostics, tests).
  bool get dirty => store.dirty;

  /// v4.0: new SRS cards introduced per day (audit H3).
  static const int dailyNewCardLimit = 10;

  int get newCardsRemainingToday {
    if (newCardsDay != todayKey()) return dailyNewCardLimit;
    return (dailyNewCardLimit - newCardsToday).clamp(0, dailyNewCardLimit);
  }

  /// Force-write now if dirty (call on app pause / critical moments).
  Future<void> flush() => store.flush();

  // ================= helpers =================

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String yesterdayKey() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Rolls daily counters and lazily resets a broken streak. Public since
  /// v4.1: ProfileStore.load() calls it after restoring the payload.
  void ensureDaily() {
    final today = todayKey();
    if (dailyXpDay != today) {
      dailyXp = 0;
      dailyXpDay = today;
      // Streak check: if the user skipped a day, reset streak lazily.
      if (lastActiveDay != null &&
          lastActiveDay != today &&
          lastActiveDay != yesterdayKey()) {
        streak = 0;
      }
    }
  }

  void setLocale(String l) {
    uiLocale = l;
    save();
    notifyListeners();
  }

  void setDarkMode(bool on) {
    darkMode = on;
    save();
    notifyListeners();
  }

  void setReduceMotion(bool on) {
    reduceMotion = on;
    save();
    notifyListeners();
  }

  void setTtsEnabled(bool on) {
    ttsEnabled = on;
    save();
    notifyListeners();
  }

  void setTtsRate(double r) {
    ttsRate = r;
    save();
    notifyListeners();
  }

  void recordWordMistake(String vocabId) {
    wordMistakes[vocabId] = (wordMistakes[vocabId] ?? 0) + 1;
    scheduleSave();
  }

  // ================= v4.4 local intelligence =================

  /// Records which word the learner picked when they meant another one.
  /// Called from the lesson screen with the CORRECT vocab id and the id of
  /// the option actually chosen (when it maps to a real vocab item).
  /// Pairs are stored normalized (lexically sorted) so both directions
  /// count toward the same bucket.
  void recordConfusion(String correctId, String chosenId) {
    if (correctId.isEmpty || chosenId.isEmpty || correctId == chosenId) return;
    final key = Insights.confusionKey(correctId, chosenId);
    confusionPairs[key] = (confusionPairs[key] ?? 0) + 1;
    if (confusionPairs.length > _maxConfusionPairs) {
      final keep =
          Insights.topConfusions(confusionPairs, limit: _keepConfusionPairs)
              .map((p) => p.key)
              .toSet();
      confusionPairs.removeWhere((k, _) => !keep.contains(k));
    }
    scheduleSave();
  }

  /// Top confusion pairs for the CURRENT course (ids resolved, both words
  /// present in [course]) — drives the insights screen + pair practice.
  List<ConfusionPair> courseConfusionPairs([int limit = 5]) {
    final byId = {for (final v in course.allVocab) v.id: v};
    return Insights.topConfusions(confusionPairs, limit: limit)
        .where(
            (p) => byId.containsKey(p.vocabIdA) && byId.containsKey(p.vocabIdB))
        .toList();
  }

  /// Cards that come due within the next 24h (overdue included).
  int get dueTomorrowCount => Insights.dueWithinDays(cards, 1);

  /// v4.4 favorites: per-course starred words, newest first.
  bool isFavorite(String vocabId) =>
      (favorites[courseId] ?? const []).contains(vocabId);

  void toggleFavorite(String vocabId) {
    final list = [...(favorites[courseId] ?? const <String>[])];
    if (list.contains(vocabId)) {
      list.remove(vocabId);
    } else {
      list.insert(0, vocabId);
    }
    favorites[courseId] = list;
    save();
    notifyListeners();
  }

  /// Favorites of [course] resolved against the corpus; stale ids (removed
  /// content, foreign profile import) are dropped silently.
  List<Vocab> favoriteVocab(Course course) {
    final byId = {for (final v in course.allVocab) v.id: v};
    return (favorites[course.id] ?? const <String>[])
        .map((id) => byId[id])
        .whereType<Vocab>()
        .toList();
  }

  /// Vocab lookup for the confusion capture in the lesson screen.
  Map<String, Vocab> vocabById(Course course) =>
      {for (final v in course.allVocab) v.id: v};

  /// Words the learner struggles with most (for the practice mode).
  List<String> get weakestWordIds {
    final entries = wordMistakes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(30).map((e) => e.key).toList();
  }

  /// v4.1 (ROADMAP item 2): weak words that belong to [course] only — most
  /// missed first. Drives the tough-words practice lane; ids recorded in
  /// other courses (or removed from content) are filtered out safely.
  List<Vocab> weakestVocab(Course course) {
    final byId = {for (final v in course.allVocab) v.id: v};
    return weakestWordIds.map((id) => byId[id]).whereType<Vocab>().toList();
  }

  void markPlacement(String courseId) {
    placementDone[courseId] = true;
    save();
  }

  void setPlacementSkip(String courseId, int flatIndex) {
    placementSkip[courseId] = flatIndex;
    markPlacement(courseId);
  }

  /// Vocab ids that belong to lessons the learner already completed.
  /// New SRS cards are only drawn from this set (audit H3).
  Set<String> unlockedVocabIds() {
    final out = <String>{};
    for (final l in course.allLessons) {
      if (lessonStars.containsKey(l.id)) {
        out.addAll(l.vocab.map((v) => v.id));
      }
    }
    return out;
  }

  void setDailyGoal(int goal) {
    dailyGoal = goal;
    save();
    notifyListeners();
  }

  void switchCourse(String id) {
    if (!courses.containsKey(id)) return;
    courseId = id;
    save();
    notifyListeners();
  }

  void finishOnboarding() {
    onboardingDone = true;
    save();
    notifyListeners();
  }

  void addXp(int amount) {
    ensureDaily();
    xp += amount;
    dailyXp += amount;
    _bumpStreak();
    lastActiveDay = todayKey();
    xpLog[dailyXpDay] = (xpLog[dailyXpDay] ?? 0) + amount;
    if (xpLog.length > 30) {
      // Keep only the latest 30 days.
      final keys = xpLog.keys.toList()..sort();
      while (xpLog.length > 30) {
        xpLog.remove(keys.removeAt(0));
      }
    }
    _checkBadges();
    // v4.0.1 fix (M4): addXp fires on every flashcard rating — a full save()
    // here defeated the debounced-write design. scheduleSave + flush-on-pause
    // covers persistence instead.
    scheduleSave();
    notifyListeners();
  }

  /// v4.0.1 fix (HIGH): the streak was pinned at 1 forever — the only code
  /// touching it was `if (streak == 0) streak = 1;` with no increment path,
  /// so the streak_3/7/14 badges were unearnable. A consecutive active day
  /// now extends the streak exactly once per calendar day.
  /// Must run BEFORE [lastActiveDay] is overwritten with today.
  void _bumpStreak() {
    if (lastActiveDay == todayKey()) return; // already counted today
    if (lastActiveDay == yesterdayKey()) {
      streak += 1; // consecutive day
    } else {
      streak = 1; // first activity ever, or after a gap reset
    }
  }

  void recordAnswer(bool correct) {
    totalAnswers += 1;
    if (correct) correctAnswers += 1;
    // v4.4: hour-of-day + per-day accuracy logs for the insights engine.
    final h = DateTime.now().hour;
    if (h >= 0 && h < 24) {
      hourTotal[h] += 1;
      if (correct) hourCorrect[h] += 1;
    }
    final t = todayKey();
    final e = [
      ...(answerLog[t] ?? const <int>[0, 0])
    ];
    if (e.length < 2) e.addAll(const <int>[0, 0]);
    e[0] += 1;
    if (correct) e[1] += 1;
    answerLog[t] = e;
    if (answerLog.length > 30) {
      final keys = answerLog.keys.toList()..sort();
      while (answerLog.length > 30) {
        answerLog.remove(keys.removeAt(0));
      }
    }
    scheduleSave();
  }

  /// Called when a lesson finishes successfully.
  void completeLesson(String lessonId,
      {required int mistakes, required int vocabCount}) {
    ensureDaily();
    final stars = mistakes == 0
        ? 3
        : mistakes <= (vocabCount / 3).ceil()
            ? 2
            : 1;
    final prev = lessonStars[lessonId] ?? 0;
    if (stars > prev) lessonStars[lessonId] = stars;
    _bumpStreak();
    lastActiveDay = todayKey();
    _checkBadges();
    save();
    notifyListeners();
  }

  /// Feed SRS after a lesson using **real per-word results** (audit H4).
  /// [results] maps vocabId -> was the learner's answer correct at least once
  /// during this lesson. Only actually-practiced words enter the review
  /// cycle, seeded by real performance:
  ///  - first encounter, answered right  -> scheduled like a "good" rating
  ///  - first encounter, answered wrong  -> "hard", kept in learning state
  ///  - seen before, answered wrong     -> lapsed ("again") so it comes back soon
  /// Untested words of the lesson stay untouched (they will enter SRS when
  /// genuinely practiced later).
  void applyLessonResults(Map<String, bool> results) {
    final now = DateTime.now();
    results.forEach((vocabId, correct) {
      final c = cards[vocabId] ?? CardData();
      if (c.reps == 0) {
        Srs.rate(c, correct ? Srs.good : Srs.hard, now: now);
        if (!correct) c.state = 'learning';
      } else if (!correct) {
        Srs.rate(c, Srs.again, now: now);
      }
      cards[vocabId] = c;
    });
    save();
  }

  void rateCard(String vocabId, int q) {
    ensureDaily();
    final c = cards[vocabId];
    final isNew = c == null || c.reps == 0;
    if (newCardsDay != todayKey()) {
      newCardsToday = 0;
      newCardsDay = todayKey();
    }
    final card = c ?? CardData();
    Srs.rate(card, q);
    cards[vocabId] = card;
    cardsReviewed += 1;
    if (isNew) newCardsToday += 1;
    _checkBadges();
    scheduleSave();
    notifyListeners();
  }

  CardData? cardFor(String vocabId) => cards[vocabId];

  // ================= badges =================

  void _checkBadges() {
    void award(String id, bool cond) {
      if (cond && !badges.contains(id)) {
        badges.add(id);
        pendingBadges.add(id);
      }
    }

    award('first_lesson', lessonsCompleted >= 1);
    award('five_lessons', lessonsCompleted >= 5);
    award('lessons_20', lessonsCompleted >= 20);
    award('xp_100', xp >= 100);
    award('xp_500', xp >= 500);
    award('xp_1000', xp >= 1000);
    award('streak_3', streak >= 3);
    award('streak_7', streak >= 7);
    award('streak_14', streak >= 14);
    award('perfect', perfectLessons >= 1);
    award('perfect_5', perfectLessons >= 5);
    award('cards_50', cardsReviewed >= 50);
    award('cards_200', cardsReviewed >= 200);

    // Course-completion badges (one per course + polyglot for all three).
    for (final id in ['en', 'ur', 'fr']) {
      final c = courses[id];
      if (c == null) continue;
      final all = c.allLessons.every((l) => lessonStars.containsKey(l.id));
      award('all_${id}_units', all);
    }
    // v4.0 fix (audit H1): the old check required courses.length == 2, which
    // became permanently false once the French course shipped. "Bilingual"
    // now means: both the EN and UR courses are fully completed.
    bool courseDone(String id) {
      final c = courses[id];
      return c != null &&
          c.allLessons.isNotEmpty &&
          c.allLessons.every((l) => lessonStars.containsKey(l.id));
    }

    award('both_courses', courseDone('en') && courseDone('ur'));
    award('polyglot', courseDone('en') && courseDone('ur') && courseDone('fr'));
  }

  String consumePendingBadge() {
    if (pendingBadges.isEmpty) return '';
    return pendingBadges.removeAt(0);
  }

  Future<void> resetAll() async {
    xp = 0;
    streak = 0;
    lastActiveDay = null;
    dailyXp = 0;
    dailyXpDay = todayKey();
    xpLog = {};
    cardsReviewed = 0;
    totalAnswers = 0;
    correctAnswers = 0;
    lessonStars = {};
    cards = {};
    badges = [];
    wordMistakes = {};
    placementDone = {};
    placementSkip = {};
    newCardsToday = 0;
    newCardsDay = todayKey();
    confusionPairs = {};
    hourTotal = List<int>.filled(24, 0);
    hourCorrect = List<int>.filled(24, 0);
    answerLog = {};
    favorites = {};
    pendingBadges.clear();
    await save();
    notifyListeners();
  }

  // ================= v4.0: export / import (MASTER PROMPT M8) ==========

  /// Serializes the full profile for backup / transfer between devices.
  /// Includes a content fingerprint so imports can be validated.
  String exportProfileJson() {
    final payload = {
      'app': 'masar-al-lugha',
      'exportVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'progress': {
        'schema': progressSchema,
        'xp': xp,
        'streak': streak,
        'lastActiveDay': lastActiveDay,
        'dailyGoal': dailyGoal,
        'dailyXp': dailyXp,
        'dailyXpDay': dailyXpDay,
        'cardsReviewed': cardsReviewed,
        'totalAnswers': totalAnswers,
        'correctAnswers': correctAnswers,
        'lessonStars': lessonStars,
        'xpLog': xpLog,
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'badges': badges,
        'wordMistakes': wordMistakes,
        'placement': placementDone,
        'insights': {
          'confusionPairs': confusionPairs,
          'hourTotal': hourTotal,
          'hourCorrect': hourCorrect,
          'answerLog': answerLog,
        },
        'favorites': favorites,
        'settings': {
          'darkMode': darkMode,
          'reduceMotion': reduceMotion,
          'ttsEnabled': ttsEnabled,
          'ttsRate': ttsRate,
          'uiLocale': uiLocale,
          'courseId': courseId,
          'onboardingDone': onboardingDone,
        },
      },
    };
    return const JsonEncoder.withIndent(' ').convert(payload);
  }

  /// Restores a profile produced by [exportProfileJson].
  /// Returns an error key (l10n) on failure, or null on success.
  /// Unknown vocab/lesson ids are dropped so foreign profiles cannot
  /// poison state.
  Future<String?> importProfileJson(String raw) async {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return 'importInvalid';
      payload = decoded;
    } catch (_) {
      return 'importInvalid';
    }
    if (payload['app'] != 'masar-al-lugha') return 'importInvalid';
    final p = payload['progress'];
    if (p is! Map<String, dynamic>) return 'importInvalid';

    // Validate against known ids before touching state.
    final validLessonIds = <String>{
      for (final c in courses.values)
        for (final l in c.allLessons) l.id,
    };
    final validVocabIds = <String>{
      for (final c in courses.values) ...c.allVocab.map((v) => v.id),
    };

    try {
      final stars = <String, int>{};
      (p['lessonStars'] as Map? ?? {}).forEach((k, v) {
        if (validLessonIds.contains(k)) stars[k as String] = (v as num).toInt();
      });
      final newCards = <String, CardData>{};
      (p['cards'] as Map? ?? {}).forEach((k, v) {
        if (validVocabIds.contains(k) && v is Map) {
          newCards[k as String] =
              CardData.fromJson(Map<String, dynamic>.from(v));
        }
      });

      final s = p['settings'];
      xp = (p['xp'] as num?)?.toInt() ?? 0;
      streak = (p['streak'] as num?)?.toInt() ?? 0;
      lastActiveDay = p['lastActiveDay'] as String?;
      dailyGoal = (p['dailyGoal'] as num?)?.toInt() ?? 20;
      dailyXp = (p['dailyXp'] as num?)?.toInt() ?? 0;
      dailyXpDay = (p['dailyXpDay'] as String?) ?? '';
      cardsReviewed = (p['cardsReviewed'] as num?)?.toInt() ?? 0;
      totalAnswers = (p['totalAnswers'] as num?)?.toInt() ?? 0;
      correctAnswers = (p['correctAnswers'] as num?)?.toInt() ?? 0;
      lessonStars = stars;
      xpLog = (p['xpLog'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      cards = newCards;
      badges = ((p['badges'] as List?) ?? [])
          .map((e) => e as String)
          .where((b) => badgeDefs.any((d) => d.id == b))
          .toList();
      wordMistakes = ((p['wordMistakes'] as Map?) ?? {}).map((k, v) =>
          validVocabIds.contains(k)
              ? MapEntry(k as String, (v as num).toInt())
              : MapEntry('', 0))
        ..remove('');
      placementDone = ((p['placement'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v as bool));
      final ins = p['insights'];
      if (ins is Map) {
        confusionPairs = ((ins['confusionPairs'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        hourTotal = _read24(ins['hourTotal']);
        hourCorrect = _read24(ins['hourCorrect']);
        answerLog = ((ins['answerLog'] as Map?) ?? {}).map((k, v) => MapEntry(
            k as String,
            ((v as List?) ?? []).map((e) => (e as num).toInt()).toList()));
        answerLog.removeWhere((_, e) => e.length < 2);
      }
      favorites = ((p['favorites'] as Map?) ?? {}).map((k, v) => MapEntry(
          k as String, ((v as List?) ?? []).map((e) => e as String).toList()));
      if (s is Map) {
        darkMode = (s['darkMode'] as bool?) ?? darkMode;
        reduceMotion = (s['reduceMotion'] as bool?) ?? reduceMotion;
        ttsEnabled = (s['ttsEnabled'] as bool?) ?? ttsEnabled;
        ttsRate = (s['ttsRate'] as num?)?.toDouble() ?? ttsRate;
        uiLocale = (s['uiLocale'] as String?) ?? uiLocale;
        final cid = s['courseId'] as String?;
        if (cid != null && courses.containsKey(cid)) courseId = cid;
        onboardingDone = (s['onboardingDone'] as bool?) ?? onboardingDone;
      }
    } catch (_) {
      return 'importInvalid';
    }
    ensureDaily();
    await save();
    notifyListeners();
    return null;
  }

  /// Reads a 24-slot hour bucket list from an imported payload.
  static List<int> _read24(Object? raw) {
    final list = (raw as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    return list.length == 24 ? list : List<int>.filled(24, 0);
  }

  // Lesson unlock logic: first lesson unlocked; next unlocks when previous
  // done. A placement result can pre-unlock lessons up to a flat index
  // (v4.0, audit M9).
  bool isLessonUnlocked(int flatIndex) {
    if (flatIndex <= (placementSkip[courseId] ?? 0)) return true;
    if (flatIndex <= 0) return true;
    final lessons = course.allLessons;
    if (flatIndex >= lessons.length) return false;
    return lessonStars.containsKey(lessons[flatIndex - 1].id);
  }
}
