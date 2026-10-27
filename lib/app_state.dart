// App state: courses, progress, gamification, badges.
// v4.1: persistence (load/save/debounce/migration) extracted to ProfileStore
// — AppState delegates to [store] and stays the domain + notification layer.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'decks.dart';
import 'calibration.dart';
import 'insights.dart';
import 'mastery.dart';
import 'mascot.dart';
import 'models.dart';
import 'path.dart';
import 'profile_store.dart';
import 'remediation.dart';
import 'srs.dart';
import 'streak_freeze.dart';
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
  String mascotId = 'rafiq'; // selected companion (v4.5, lib/mascot.dart)

  // ---- progress ----
  int xp = 0;
  int streak = 0;
  String? lastActiveDay; // yyyy-MM-dd
  // v4.8 all-time records (additive schema keys, null-safe on old payloads):
  int bestStreak = 0; // longest streak ever — updated in _bumpStreak
  int bestDayXp = 0; // best single-day XP — updated in addXp
  int activeDays = 0; // all-time days with any activity — one bump per day
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

  // v5.15 (F3.1): first-run journey timing — when onboarding finished and
  // when the first lesson win landed. Both are epoch-ms, additive settings
  // keys, recorded once and never overwritten; they feed the opt-in local
  // analytics KPI (time-to-first-win <= 3:00). Nothing leaves the device.
  int? journeyStartedAt;
  int? firstWinAt;

  // ---- v4.0 settings & engine ----
  bool darkMode = false; // null-aware tri-state handled by settings UI
  bool reduceMotion = false;
  bool simplifiedAudio = false;
  bool largerText = false;

  // v5.15 (F3.3 + F3.5): accessibility additions. simplifiedAudio speaks
  // the result aloud after every answer (low-vision support, F3.3);
  // largerText scales the interface text by 15% (F3.5). Both are additive
  // settings keys, OFF by default — the app behaves byte-identically
  // without them.
  bool ttsEnabled = true;
  double ttsRate = 0.9;
  // v5.3 FSRS target retention (0.70..0.98) — lower schedules longer intervals.
  double retentionTarget = Srs.defaultRetention;
  // v5.10 local multi-profile slot (1..3) + device-level display names.
  int profileSlot = 1;
  Map<int, String> profileNames = {};
  // v5.10 opt-in local analytics (retention metrics) — OFF by default and
  // anonymous BY CONSTRUCTION: nothing ever leaves the device.
  bool analyticsOptIn = false;
  Map<String, bool> placementDone = {}; // courseId -> placed
  Map<String, int> wordMistakes = {}; // vocabId -> lifetime mistake count
  Map<String, int> placementSkip =
      {}; // courseId -> flat lesson index unlocked by placement
  // v4.11 learning path plan per course (engine-parsed enum names, null-safe
  // on old payloads — see lib/path.dart and PathEngine.domainByName).
  Map<String, String> pathDomain = {}; // courseId -> PathDomain.name
  Map<String, String> pathTier = {}; // courseId -> LevelTier.name
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

  // ---- v5.12 learning engine (plan F2.1-F2.5) ----

  /// F2.4 remediation window: vocabId -> epoch-day lapse log (bounded —
  /// see Remediation). Records RECENT forgetting only, self-cleans.
  Map<String, List<int>> lapseLog = {};

  /// F2.2 calibration rolling log of [predictedR-milli, recalled] pairs
  /// (bounded to Calibration.maxSamples — see Calibration).
  List<List<int>> calibrationLog = [];

  /// F2.5 streak freeze wallet (max 2, earned every 7 consecutive days).
  int streakFreezes = 0;

  /// Highest 7-day milestone already converted into a freeze token.
  int lastFreezeAwardMark = 0;

  /// F2.5 daily reminder preferences (persisted; the service applies them).
  ReminderSettings reminders =
      const ReminderSettings(enabled: false, hour: 20, minute: 0);

  /// courseId -> starred vocab ids (newest first) — favorites deck.
  Map<String, List<String>> favorites = {};

  /// v4.7: user-authored word lists (schema-v2 additive `decks` key).
  /// Bounded and validated in lib/decks.dart; ids are store-assigned and
  /// never trusted from payloads.
  List<CustomDeck> customDecks = [];
  int _deckCounter = 0;

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
    BadgeDef('all_de_units', icon: Icons.flag, color: AppColors.blue),
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
    profileSlot = store.slot;
    profileNames = Map<int, String>.from(store.loadProfileNames());
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
  /// v5.12 (F2.5): a single missed day can be bridged by a freeze token —
  /// the streak survives, the token is spent, the missed day is not
  /// rewritten into study time.
  void ensureDaily() {
    final today = todayKey();
    if (dailyXpDay != today) {
      dailyXp = 0;
      dailyXpDay = today;
      // Streak check: if the user skipped a day, reset streak lazily —
      // unless a freeze token bridges exactly one missed day.
      if (lastActiveDay != null &&
          lastActiveDay != today &&
          lastActiveDay != yesterdayKey()) {
        final missed = missedDaysSince(lastActiveDay!, today);
        if (StreakFreeze.canBridge(
            freezes: streakFreezes, missedDays: missed)) {
          streakFreezes = StreakFreeze.afterBridge(streakFreezes);
          // Virtual bridge: treat yesterday as covered so the streak
          // chain continues; no XP and no activeDay are granted.
          lastActiveDay = yesterdayKey();
        } else {
          streak = 0;
        }
      }
    }
  }

  /// Calendar days missed between two day keys (1 = yesterday was skipped,
  /// 2 = the day before yesterday…). Malformed keys count as "far away".
  static int missedDaysSince(String fromDayKey, String toDayKey) {
    final a = DateTime.tryParse(fromDayKey);
    final b = DateTime.tryParse(toDayKey);
    if (a == null || b == null) return 99;
    final diff = DateTime(b.year, b.month, b.day)
        .difference(DateTime(a.year, a.month, a.day))
        .inDays;
    return diff <= 0 ? 0 : diff - 1;
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

  // v5.15 (F3.3/F3.5): simplified-audio + larger-text setters.
  void setSimplifiedAudio(bool on) {
    simplifiedAudio = on;
    save();
    notifyListeners();
  }

  void setLargerText(bool on) {
    largerText = on;
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

  /// v5.3: FSRS target retention, clamped to the engine's supported range
  /// and rounded so the payload stays stable across round-trips.
  void setAnalyticsOptIn(bool on) {
    analyticsOptIn = on;
    save();
    notifyListeners();
  }

  void setRetentionTarget(double r) {
    retentionTarget = r.clamp(Srs.minRetention, Srs.maxRetention).toDouble();
    retentionTarget = (retentionTarget * 100).roundToDouble() / 100;
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

  // ================= v4.5: companion (Rafiq & Friends) =================

  /// Consecutive fully-missed days ending today (0 = active today).
  int get mascotMissedDays {
    final last = lastActiveDay;
    if (last == null || last == todayKey()) return 0;
    final t = DateTime.tryParse(todayKey());
    final l = DateTime.tryParse(last);
    if (t == null || l == null) return 0;
    final d = t.difference(l).inDays;
    return d < 0 ? 0 : d;
  }

  /// Evidence snapshot the companion engine reads (lib/mascot.dart).
  MascotFacts get mascotFacts => MascotFacts(
        xp: xp,
        streak: streak,
        lessons: lessonsCompleted,
        level: level,
        accuracy: accuracyPct,
        missedDays: mascotMissedDays,
      );

  bool isMascotUnlocked(String id) {
    final c = mascotById(id);
    return c.missingRequirement(mascotFacts) == null;
  }

  /// Selects a companion. Locked or unknown ids are ignored (no-op) —
  /// the UI only offers unlocked ones, this guard is the second lock.
  void selectMascot(String id) {
    if (!isMascotUnlocked(id)) return;
    final resolved = mascotById(id).id;
    if (mascotId == resolved) return;
    mascotId = resolved;
    scheduleSave();
    notifyListeners();
  }

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

  // ================= v5.12 learning engine helpers =================

  /// F2.4: the current 7-day remediation targets that belong to [course],
  /// most chronic first. Unknown/foreign ids are filtered out safely.
  List<Vocab> remediationVocab(Course course) {
    final byId = {for (final v in course.allVocab) v.id: v};
    return Remediation.scan(lapseLog, now: DateTime.now())
        .map((i) => byId[i.vocabId])
        .whereType<Vocab>()
        .toList();
  }

  /// F2.1: mastery summary for [course] (average + mastered count).
  MasterySummary masterySummary(Course course, {DateTime? now}) =>
      Mastery.summary(course.allVocab, cards, now: now);

  /// F2.5: updates reminder preferences. The notification scheduling itself
  /// is applied by the caller (ReminderService.sync) — state stays
  /// notification-free.
  void setReminders(ReminderSettings r) {
    reminders = ReminderSettings(
      enabled: r.enabled,
      hour: r.hour.clamp(0, 23),
      minute: r.minute.clamp(0, 59),
    );
    save();
    notifyListeners();
  }

  /// F2.1: per-word mastery score convenience (0..100).
  double masteryOf(String vocabId, {DateTime? now}) =>
      Mastery.wordScore(cards[vocabId], now: now);

  void markPlacement(String courseId) {
    placementDone[courseId] = true;
    save();
  }

  void setPlacementSkip(String courseId, int flatIndex) {
    placementSkip[courseId] = flatIndex;
    markPlacement(courseId);
  }

  /// v4.11: stores the learner's path plan (domain + tier) for [courseId].
  /// Invalid enum names are rejected silently — the stored plan stays put.
  void setPathPlan(String courseId, String domain, String tier) {
    if (PathEngine.domainByName(domain) == null) return;
    if (PathEngine.tierByName(tier) == null) return;
    pathDomain[courseId] = domain;
    pathTier[courseId] = tier;
    save();
    notifyListeners();
  }

  /// v4.12: stores ONLY the level tier for [courseId] — the placement test
  /// calls this to link its result to the learner's level automatically.
  /// A previously chosen domain survives, so an existing plan just moves to
  /// the detected tier; without a domain nothing shows until the wizard
  /// completes, but the tier is pre-selected there. Invalid enum names are
  /// rejected silently; re-storing the same value skips the save.
  void setPathTier(String courseId, String tier) {
    if (PathEngine.tierByName(tier) == null) return;
    if (pathTier[courseId] == tier) return;
    pathTier[courseId] = tier;
    save();
    notifyListeners();
  }

  /// v4.13: stores ONLY the domain for [courseId] — the placement test
  /// calls this to link its suggested field (derived from the units whose
  /// words the learner answered correctly) to the plan automatically. A
  /// previously chosen tier survives, so a stored tier + suggested domain
  /// completes a full plan without the wizard. Invalid enum names are
  /// rejected silently; re-storing the same value skips the save.
  void setPathDomain(String courseId, String domain) {
    if (PathEngine.domainByName(domain) == null) return;
    if (pathDomain[courseId] == domain) return;
    pathDomain[courseId] = domain;
    save();
    notifyListeners();
  }

  /// v4.11: removes the plan for [courseId] (no-op when none was set).
  void clearPathPlan(String courseId) {
    final had = pathDomain.remove(courseId) != null ||
        pathTier.remove(courseId) != null;
    if (!had) return;
    save();
    notifyListeners();
  }

  PathDomain? pathDomainOf(String courseId) =>
      PathEngine.domainByName(pathDomain[courseId]);

  LevelTier? pathTierOf(String courseId) =>
      PathEngine.tierByName(pathTier[courseId]);

  /// The active plan for the CURRENT course, or null when unset or when the
  /// stored names no longer parse (e.g. payload from a future version).
  PathPlan? get activePathPlan {
    final d = pathDomainOf(courseId);
    final t = pathTierOf(courseId);
    if (d == null || t == null) return null;
    return PathEngine.build(course, d, t);
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
    // v5.15 (F3.1): the journey clock starts when onboarding ends — the
    // first-win timer measures onboarding-end -> lesson-complete.
    journeyStartedAt ??= DateTime.now().millisecondsSinceEpoch;
    save();
    notifyListeners();
  }

  /// v5.15 (F3.1): called by the first-win result screen. Recorded ONCE —
  /// later lessons never move it.
  void markFirstWin() {
    firstWinAt ??= DateTime.now().millisecondsSinceEpoch;
    save();
    notifyListeners();
  }

  void addXp(int amount) {
    ensureDaily();
    xp += amount;
    dailyXp += amount;
    if (dailyXp > bestDayXp) bestDayXp = dailyXp; // v4.8 record
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
    // v4.8: this branch runs exactly once per active day — the perfect
    // hook to count all-time active days without any extra stored state.
    activeDays += 1;
    if (lastActiveDay == yesterdayKey()) {
      streak += 1; // consecutive day
    } else {
      streak = 1; // first activity ever, or after a gap reset
    }
    if (streak > bestStreak) bestStreak = streak; // v4.8 record
    // v5.12 (F2.5): one freeze token per 7-day milestone, stored only when
    // the wallet has room — a full wallet defers the milestone instead of
    // wasting it (see StreakFreeze.shouldAward).
    if (StreakFreeze.shouldAward(
        streak: streak,
        lastAwardMark: lastFreezeAwardMark,
        freezes: streakFreezes)) {
      streakFreezes = StreakFreeze.afterAward(streakFreezes);
      lastFreezeAwardMark = StreakFreeze.markAfter(streak);
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
        Srs.rate(c, correct ? Srs.good : Srs.hard,
            now: now, requestRetention: retentionTarget);
        if (!correct) c.state = 'learning';
      } else if (!correct) {
        // v5.12 (F2.2/F2.4): a seen word the learner missed is a real
        // calibration datapoint and a remediation-window lapse event.
        _logCalibration(c, false);
        Remediation.recordLapse(lapseLog, vocabId, now);
        Srs.rate(c, Srs.again, now: now, requestRetention: retentionTarget);
      } else {
        // v5.12 (F2.2): the lesson re-tested a seen word even though the
        // scheduler did not ask — still an honest prediction/outcome pair.
        _logCalibration(c, true);
      }
      cards[vocabId] = c;
    });
    save();
  }

  /// F2.2: records one calibration sample BEFORE a rating mutates the
  /// card's memory states — the prediction must be the pre-review one.
  void _logCalibration(CardData card, bool recalled) {
    if (!Calibration.isPredictable(card)) return;
    final r = Srs.retrievability(
        card.stability, card.lastReviewEpochMs, DateTime.now());
    Calibration.addSample(calibrationLog, r, recalled);
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
    // v5.12 (F2.2/F2.4): sample the prediction BEFORE the rating mutates
    // the memory states; only lapsed SEEN words enter the remediation
    // window (first-encounter mistakes are the lessons' job, not traps).
    _logCalibration(card, q != Srs.again);
    if (q == Srs.again && card.reps > 0) {
      Remediation.recordLapse(lapseLog, vocabId, DateTime.now());
    }
    Srs.rate(card, q, requestRetention: retentionTarget);
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

    // Course-completion badges (one per course + polyglot for all four).
    for (final id in ['en', 'ur', 'fr', 'de']) {
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
    // v5.0: German joins the polyglot requirement — all four courses.
    award(
        'polyglot',
        courseDone('en') &&
            courseDone('ur') &&
            courseDone('fr') &&
            courseDone('de'));
  }

  String consumePendingBadge() {
    if (pendingBadges.isEmpty) return '';
    return pendingBadges.removeAt(0);
  }

  // ================= v4.7: custom word lists =================

  CustomDeck? deckById(String id) {
    for (final d in customDecks) {
      if (d.id == id) return d;
    }
    return null;
  }

  static int _maxDeckNum(List<CustomDeck> decks) {
    var m = 0;
    for (final d in decks) {
      final n = int.tryParse(d.id.substring(2));
      if (n != null && n > m) m = n;
    }
    return m;
  }

  /// Re-derives the deck-id counter from the loaded deck set (used by
  /// ProfileStore after loading a stored payload — payload ids are never
  /// trusted for the monotonic sequence).
  void rebaseDeckCounter() => _deckCounter = _maxDeckNum(customDecks);

  void _decksChanged() {
    scheduleSave();
    notifyListeners();
  }

  /// Creates a deck for the current course. Returns null when the name is
  /// unusable or the deck budget is spent (12).
  CustomDeck? createCustomDeck(String name) {
    final clean = DeckLimits.cleanName(name);
    if (clean == null) return null;
    if (customDecks.length >= DeckLimits.maxDecks) return null;
    _deckCounter++;
    final deck =
        CustomDeck(id: 'cd$_deckCounter', name: clean, courseId: courseId);
    customDecks.add(deck);
    _decksChanged();
    return deck;
  }

  /// Renames a deck; false when the deck is unknown or the name unusable.
  bool renameCustomDeck(String deckId, String name) {
    final clean = DeckLimits.cleanName(name);
    if (clean == null) return false;
    final i = customDecks.indexWhere((d) => d.id == deckId);
    if (i < 0) return false;
    customDecks[i] = customDecks[i].copyWith(name: clean);
    _decksChanged();
    return true;
  }

  bool deleteCustomDeck(String deckId) {
    final before = customDecks.length;
    customDecks.removeWhere((d) => d.id == deckId);
    if (customDecks.length == before) return false;
    _decksChanged();
    return true;
  }

  /// Adds a word to a deck. Returns an l10n error key on failure
  /// ('invalidWord' / 'dupWord' / 'listFull') or null on success.
  String? addCustomWord(String deckId, String target, String translationAr) {
    final deck = deckById(deckId);
    if (deck == null) return 'invalidWord';
    final t = DeckLimits.cleanWord(target);
    final a = DeckLimits.cleanWord(translationAr, maxLen: 80);
    if (t == null || a == null) return 'invalidWord';
    if (deck.words.length >= CustomDeck.maxWords) return 'listFull';
    final key = DeckLimits.dupKey(t);
    for (final w in deck.words) {
      if (DeckLimits.dupKey(w.target) == key) return 'dupWord';
    }
    final word = CustomWord(
      id: '${deck.id}_w${deck.nextSeq}',
      target: t,
      translationAr: a,
    );
    final i = customDecks.indexWhere((d) => d.id == deckId);
    customDecks[i] =
        deck.copyWith(words: [...deck.words, word], nextSeq: deck.nextSeq + 1);
    _decksChanged();
    return null;
  }

  bool removeCustomWord(String deckId, String wordId) {
    final deck = deckById(deckId);
    if (deck == null) return false;
    final i = customDecks.indexWhere((d) => d.id == deckId);
    customDecks[i] =
        deck.copyWith(words: deck.words.where((w) => w.id != wordId).toList());
    _decksChanged();
    return true;
  }

  Future<void> resetAll() async {
    _resetInMemory();
    pendingBadges.clear();
    await save();
    notifyListeners();
  }

  /// v5.10: wipes every in-memory progress field WITHOUT touching prefs —
  /// used by [switchProfile] before loading another slot's payload.
  void _resetInMemory() {
    xp = 0;
    streak = 0;
    bestStreak = 0; // v4.8 records reset with everything else
    bestDayXp = 0;
    activeDays = 0;
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
    pathDomain = {};
    pathTier = {};
    newCardsToday = 0;
    newCardsDay = todayKey();
    confusionPairs = {};
    hourTotal = List<int>.filled(24, 0);
    hourCorrect = List<int>.filled(24, 0);
    answerLog = {};
    favorites = {};
    customDecks = [];
    _deckCounter = 0;
    mascotId = 'rafiq';
  }

  // ================= v5.10: local multi-profile slots ==================

  /// Switches to another LOCAL profile slot (1..3). Saves the current
  /// slot, wipes in-memory progress, loads the target payload. Purely
  /// on-device — no accounts, no network; slot 1 is the original key so
  /// the "no account" default is byte-compatible with older builds.
  Future<void> switchProfile(int slot) async {
    final target = slot.clamp(1, ProfileStore.maxProfiles);
    if (target == profileSlot) return;
    await save();
    await store.setSlot(target);
    profileSlot = target;
    _resetInMemory();
    await load();
    notifyListeners();
  }

  /// Renames a local profile slot (device-level display names).
  Future<void> renameProfile(int slot, String name) async {
    final s = slot.clamp(1, ProfileStore.maxProfiles);
    final trimmed = name.trim().substring(0, name.trim().length.clamp(0, 24));
    if (trimmed.isEmpty) {
      profileNames.remove(s);
    } else {
      profileNames[s] = trimmed;
    }
    await store.saveProfileNames(profileNames);
    notifyListeners();
  }

  // ================= v4.0: export / import (MASTER PROMPT M8) ==========

  /// Serializes the full profile for backup / transfer between devices.
  /// Includes a content fingerprint so imports can be validated.
  /// v5.11: records the source slot (informational — imports ignore it).
  String exportProfileJson() {
    final payload = {
      'app': 'masar-al-lugha',
      'exportVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'slot': profileSlot, // v5.11: informational
      'progress': {
        'schema': progressSchema,
        'xp': xp,
        'streak': streak,
        'bestStreak': bestStreak, // v4.8
        'bestDayXp': bestDayXp, // v4.8
        'activeDays': activeDays, // v4.8
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
        'placementSkip': placementSkip,
        'pathDomain': pathDomain,
        'pathTier': pathTier,
        'insights': {
          'confusionPairs': confusionPairs,
          'hourTotal': hourTotal,
          'hourCorrect': hourCorrect,
          'answerLog': answerLog,
        },
        'favorites': favorites,
        'mascot': mascotId,
        'decks': customDecks.map((d) => d.toJson()).toList(),
        'settings': {
          'darkMode': darkMode,
          'reduceMotion': reduceMotion,
          'simplifiedAudio': simplifiedAudio,
          'largerText': largerText,
          'ttsEnabled': ttsEnabled,
          'ttsRate': ttsRate,
          'retentionTarget': retentionTarget,
          'analyticsOptIn': analyticsOptIn,
          if (journeyStartedAt != null) 'journeyStartedAt': journeyStartedAt,
          if (firstWinAt != null) 'firstWinAt': firstWinAt,
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
  ///
  /// v5.11: [targetSlot] restores into ANY local profile slot (1..3),
  /// not only the current one. Implementation routes the store's keys at
  /// the target slot for the duration of the import — so the payload
  /// goes through the exact same serializer as a normal save — then
  /// reloads the original slot's state. The CURRENT slot's payload key
  /// is never written by a cross-slot import; its in-memory state is
  /// flushed first so nothing pending is lost. Note the device-global
  /// prefs (course/uiLocale) follow the imported payload by design —
  /// v5.10 keeps one course per device across slots.
  Future<String?> importProfileJson(String raw, {int? targetSlot}) async {
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

    // v5.11: optional cross-slot restore (see the doc comment above).
    final origSlot = profileSlot;
    final target = (targetSlot ?? origSlot).clamp(1, ProfileStore.maxProfiles);
    final crossSlot = target != origSlot;
    if (crossSlot) {
      await save(); // flush the CURRENT slot so nothing pending is lost
      await store.setSlot(target);
      profileSlot = target;
      _resetInMemory();
    }

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
      // v4.8 records (additive, null-safe for old payloads).
      bestStreak = (p['bestStreak'] as num?)?.toInt() ?? 0;
      bestDayXp = (p['bestDayXp'] as num?)?.toInt() ?? 0;
      activeDays = (p['activeDays'] as num?)?.toInt() ?? 0;
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
      // v4.11 path plan (additive, null-safe; unknown names are dropped).
      pathDomain = ((p['pathDomain'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v as String))
        ..removeWhere((k, v) => PathEngine.domainByName(v) == null);
      pathTier = ((p['pathTier'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v as String))
        ..removeWhere((k, v) => PathEngine.tierByName(v) == null);
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
      // v4.7: custom decks — strict parse, bounded, counter re-derived
      // (payload ids are never trusted for the monotonic sequence).
      final ds = p['decks'];
      if (ds is List) {
        final loaded = <CustomDeck>[];
        final seenIds = <String>{};
        for (final raw in ds.take(DeckLimits.maxDecks)) {
          if (raw is! Map) continue;
          final d = CustomDeck.fromJson(Map<String, dynamic>.from(raw));
          if (d == null || !seenIds.add(d.id)) continue;
          loaded.add(d);
        }
        customDecks = loaded;
        _deckCounter = _maxDeckNum(customDecks);
      }
      // v4.5: companion — only ids from the cast are accepted.
      final m = p['mascot'];
      if (m is String && mascotCast.any((c) => c.id == m)) mascotId = m;
      if (s is Map) {
        darkMode = (s['darkMode'] as bool?) ?? darkMode;
        reduceMotion = (s['reduceMotion'] as bool?) ?? reduceMotion;
        simplifiedAudio = (s['simplifiedAudio'] as bool?) ?? simplifiedAudio;
        largerText = (s['largerText'] as bool?) ?? largerText;
        ttsEnabled = (s['ttsEnabled'] as bool?) ?? ttsEnabled;
        ttsRate = (s['ttsRate'] as num?)?.toDouble() ?? ttsRate;
        analyticsOptIn = (s['analyticsOptIn'] as bool?) ?? analyticsOptIn;
        retentionTarget =
            (s['retentionTarget'] as num?)?.toDouble() ?? retentionTarget;
        uiLocale = (s['uiLocale'] as String?) ?? uiLocale;
        final cid = s['courseId'] as String?;
        if (cid != null && courses.containsKey(cid)) courseId = cid;
        onboardingDone = (s['onboardingDone'] as bool?) ?? onboardingDone;
        journeyStartedAt = (s['journeyStartedAt'] as num?)?.toInt();
        firstWinAt = (s['firstWinAt'] as num?)?.toInt();
      }
    } catch (_) {
      if (crossSlot) {
        // Restore the original slot's state; the target key was never
        // written on this failure path (save happens only on success).
        await store.setSlot(origSlot);
        profileSlot = origSlot;
        _resetInMemory();
        await load();
        notifyListeners();
      }
      return 'importInvalid';
    }
    ensureDaily();
    if (crossSlot) {
      await store.save(); // writes the TARGET slot key
      await store.setSlot(origSlot);
      profileSlot = origSlot;
      _resetInMemory();
      await load();
    } else {
      await save();
    }
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
