// App state: courses, progress, gamification, storage, badges.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'srs.dart';
import 'theme.dart';

class BadgeDef {
  final String id;
  final IconData icon;
  final Color color;
  const BadgeDef(this.id, {required this.icon, required this.color});
}

class AppState extends ChangeNotifier {
  static const _kLocale = 'ui_locale';
  static const _kCourse = 'course_id';
  static const _kProgress = 'progress_json_v1';
  static const _kOnboard = 'onboarding_done';

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
  int cardsReviewed = 0;
  int totalAnswers = 0;
  int correctAnswers = 0;
  Map<String, int> lessonStars = {}; // lessonId -> stars 1..3
  Map<String, CardData> cards = {}; // vocabId -> card
  List<String> badges = [];

  bool onboardingDone = false;
  bool loaded = false;

  // ---- badges registry ----
  static const List<BadgeDef> badgeDefs = [
    BadgeDef('first_lesson', icon: Icons.emoji_events, color: AppColors.blue),
    BadgeDef('five_lessons', icon: Icons.local_fire_department, color: AppColors.orange),
    BadgeDef('xp_100', icon: Icons.star, color: AppColors.yellow),
    BadgeDef('xp_500', icon: Icons.stars, color: AppColors.yellow),
    BadgeDef('streak_3', icon: Icons.whatshot, color: AppColors.red),
    BadgeDef('streak_7', icon: Icons.bolt, color: AppColors.red),
    BadgeDef('perfect', icon: Icons.military_tech, color: AppColors.green),
    BadgeDef('cards_50', icon: Icons.style, color: AppColors.purple),
    BadgeDef('all_en_units', icon: Icons.flag, color: AppColors.green),
    BadgeDef('all_ur_units', icon: Icons.flag, color: AppColors.green),
  ];

  // Newly earned badges waiting to be celebrated in UI.
  final List<String> pendingBadges = [];

  Course get course => courses[courseId] ?? courses.values.first;

  int get accuracyPct {
    if (totalAnswers == 0) return 0;
    return ((correctAnswers / totalAnswers) * 100).round();
  }

  int get wordsLearned =>
      cards.values.where((c) => c.state == 'review').length;

  int get lessonsCompleted => lessonStars.length;

  bool isGoalDone(String day) => dailyXpDay == day && dailyXp >= dailyGoal;

  // ================= lifecycle =================

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    uiLocale = prefs.getString(_kLocale) ?? 'ar';
    courseId = prefs.getString(_kCourse) ?? 'en';
    onboardingDone = prefs.getBool(_kOnboard) ?? false;

    final raw = prefs.getString(_kProgress);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        xp = (j['xp'] as num?)?.toInt() ?? 0;
        streak = (j['streak'] as num?)?.toInt() ?? 0;
        lastActiveDay = j['lastActiveDay'] as String?;
        dailyGoal = (j['dailyGoal'] as num?)?.toInt() ?? 20;
        dailyXp = (j['dailyXp'] as num?)?.toInt() ?? 0;
        dailyXpDay = (j['dailyXpDay'] as String?) ?? '';
        cardsReviewed = (j['cardsReviewed'] as num?)?.toInt() ?? 0;
        totalAnswers = (j['totalAnswers'] as num?)?.toInt() ?? 0;
        correctAnswers = (j['correctAnswers'] as num?)?.toInt() ?? 0;
        lessonStars = ((j['lessonStars'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        cards = ((j['cards'] as Map?) ?? {}).map((k, v) =>
            MapEntry(k as String, CardData.fromJson(v as Map<String, dynamic>)));
        badges = ((j['badges'] as List?) ?? [])
            .map((e) => e as String)
            .toList();
      } catch (_) {
        // Corrupt data — start fresh.
      }
    }
    _ensureDaily();
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, uiLocale);
    await prefs.setString(_kCourse, courseId);
    await prefs.setBool(_kOnboard, onboardingDone);
    final j = {
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
      'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
      'badges': badges,
    };
    await prefs.setString(_kProgress, jsonEncode(j));
  }

  // ================= helpers =================

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String yesterdayKey() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _ensureDaily() {
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
    _ensureDaily();
    xp += amount;
    dailyXp += amount;
    lastActiveDay = todayKey();
    if (streak == 0) streak = 1;
    _checkBadges();
    save();
    notifyListeners();
  }

  void recordAnswer(bool correct) {
    totalAnswers += 1;
    if (correct) correctAnswers += 1;
    notifyListeners();
  }

  /// Called when a lesson finishes successfully.
  void completeLesson(String lessonId, {required int mistakes, required int vocabCount}) {
    _ensureDaily();
    final stars = mistakes == 0
        ? 3
        : mistakes <= (vocabCount / 3).ceil()
            ? 2
            : 1;
    final prev = lessonStars[lessonId] ?? 0;
    if (stars > prev) lessonStars[lessonId] = stars;
    lastActiveDay = todayKey();
    if (streak == 0) streak = 1;
    _checkBadges();
    save();
    notifyListeners();
  }

  /// Feed SRS: lesson vocab enters the review cycle.
  void touchCardsForLesson(List<Vocab> vocab) {
    final now = DateTime.now();
    for (final v in vocab) {
      final c = cards[v.id] ?? CardData();
      if (c.reps == 0) {
        Srs.rate(c, Srs.good, now: now);
      }
      cards[v.id] = c;
    }
    save();
  }

  void rateCard(String vocabId, int q) {
    _ensureDaily();
    final c = cards[vocabId] ?? CardData();
    Srs.rate(c, q);
    cards[vocabId] = c;
    cardsReviewed += 1;
    _checkBadges();
    save();
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
    award('xp_100', xp >= 100);
    award('xp_500', xp >= 500);
    award('streak_3', streak >= 3);
    award('streak_7', streak >= 7);
    award('cards_50', cardsReviewed >= 50);

    final en = courses['en'];
    if (en != null) {
      final all = en.allLessons.every((l) => lessonStars.containsKey(l.id));
      award('all_en_units', all);
    }
    final ur = courses['ur'];
    if (ur != null) {
      final all = ur.allLessons.every((l) => lessonStars.containsKey(l.id));
      award('all_ur_units', all);
    }
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
    cardsReviewed = 0;
    totalAnswers = 0;
    correctAnswers = 0;
    lessonStars = {};
    cards = {};
    badges = [];
    pendingBadges.clear();
    await save();
    notifyListeners();
  }

  // Lesson unlock logic: first lesson unlocked; next unlocks when previous done.
  bool isLessonUnlocked(int flatIndex) {
    if (flatIndex <= 0) return true;
    final lessons = course.allLessons;
    if (flatIndex >= lessons.length) return false;
    return lessonStars.containsKey(lessons[flatIndex - 1].id);
  }
}
