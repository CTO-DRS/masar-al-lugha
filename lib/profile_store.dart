// ProfileStore (v4.1): persistence layer extracted from AppState.
//
// Owns SharedPreferences keys, schema migration, JSON (de)serialization and
// the debounced write. AppState keeps the domain API and delegates here, so a
// future backend swap (e.g. SQLite/Drift) only touches this class — see
// docs/ARCHITECTURE.md §2. No behavior change vs the v4.0 in-class code:
// corrupt payloads still keep a restorable backup before a fresh start.
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'models.dart';

class ProfileStore {
  ProfileStore(this._state);

  final AppState _state;

  /// Current progress schema version. Bump when the payload shape changes
  /// and handle old shapes in [_migrateSchema].
  static const int progressSchema = 2;

  bool _dirty = false;
  Timer? _saveTimer;
  static const _saveDelay = Duration(seconds: 2);

  static const _kLocale = 'ui_locale';
  static const _kCourse = 'course_id';
  static const _kProgress = 'progress_json_v1';
  static const _kBackup = 'progress_backup_v1'; // corrupt-state snapshot
  static const _kOnboard = 'onboarding_done';

  /// True when there are unsaved changes (debug/diagnostics, tests).
  bool get dirty => _dirty;

  // ================= lifecycle =================

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = _state;
    s.uiLocale = prefs.getString(_kLocale) ?? 'ar';
    s.courseId = prefs.getString(_kCourse) ?? 'en';
    s.onboardingDone = prefs.getBool(_kOnboard) ?? false;

    final raw = prefs.getString(_kProgress);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _migrateSchema(j);
        s.xp = (j['xp'] as num?)?.toInt() ?? 0;
        s.streak = (j['streak'] as num?)?.toInt() ?? 0;
        s.lastActiveDay = j['lastActiveDay'] as String?;
        s.dailyGoal = (j['dailyGoal'] as num?)?.toInt() ?? 20;
        s.dailyXp = (j['dailyXp'] as num?)?.toInt() ?? 0;
        s.dailyXpDay = (j['dailyXpDay'] as String?) ?? '';
        s.cardsReviewed = (j['cardsReviewed'] as num?)?.toInt() ?? 0;
        s.totalAnswers = (j['totalAnswers'] as num?)?.toInt() ?? 0;
        s.correctAnswers = (j['correctAnswers'] as num?)?.toInt() ?? 0;
        s.lessonStars = ((j['lessonStars'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        s.xpLog = ((j['xpLog'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        s.cards = ((j['cards'] as Map?) ?? {}).map((k, v) => MapEntry(
            k as String,
            CardData.fromJson(Map<String, dynamic>.from(v as Map))));
        s.badges =
            ((j['badges'] as List?) ?? []).map((e) => e as String).toList();
        s.wordMistakes = ((j['wordMistakes'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        s.placementDone = ((j['placement'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, v as bool));
        s.placementSkip = ((j['placementSkip'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
        s.newCardsToday = (j['newCardsToday'] as num?)?.toInt() ?? 0;
        s.newCardsDay = (j['newCardsDay'] as String?) ?? '';
        final settings = j['settings'];
        if (settings is Map) {
          s.darkMode = (settings['darkMode'] as bool?) ?? s.darkMode;
          s.reduceMotion =
              (settings['reduceMotion'] as bool?) ?? s.reduceMotion;
          s.ttsEnabled = (settings['ttsEnabled'] as bool?) ?? s.ttsEnabled;
          s.ttsRate = (settings['ttsRate'] as num?)?.toDouble() ?? s.ttsRate;
        }
        if (s.newCardsDay != AppState.todayKey()) {
          s.newCardsToday = 0;
          s.newCardsDay = AppState.todayKey();
        }
      } catch (_) {
        // Corrupt data — keep a recoverable copy before starting fresh.
        prefs.setString(_kBackup, raw);
      }
    }
    s.ensureDaily();
    s.loaded = true;
    // AppState.load() fires notifyListeners() after awaiting this method,
    // keeping the ChangeNotifier contract inside the state class itself.
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final s = _state;
    await prefs.setString(_kLocale, s.uiLocale);
    await prefs.setString(_kCourse, s.courseId);
    await prefs.setBool(_kOnboard, s.onboardingDone);
    final j = {
      'schema': AppState.progressSchema,
      'xp': s.xp,
      'streak': s.streak,
      'lastActiveDay': s.lastActiveDay,
      'dailyGoal': s.dailyGoal,
      'dailyXp': s.dailyXp,
      'dailyXpDay': s.dailyXpDay,
      'cardsReviewed': s.cardsReviewed,
      'totalAnswers': s.totalAnswers,
      'correctAnswers': s.correctAnswers,
      'lessonStars': s.lessonStars,
      'xpLog': s.xpLog,
      'cards': s.cards.map((k, v) => MapEntry(k, v.toJson())),
      'badges': s.badges,
      'wordMistakes': s.wordMistakes,
      'placement': s.placementDone,
      'placementSkip': s.placementSkip,
      'newCardsToday': s.newCardsToday,
      'newCardsDay': s.newCardsDay,
      'settings': {
        'darkMode': s.darkMode,
        'reduceMotion': s.reduceMotion,
        'ttsEnabled': s.ttsEnabled,
        'ttsRate': s.ttsRate,
      },
    };
    await prefs.setString(_kProgress, jsonEncode(j));
    _dirty = false;
  }

  /// Marks state dirty and schedules a debounced save. Heavy callers
  /// (every answer tap) should use this instead of awaiting [save].
  void scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      if (_dirty) save();
    });
  }

  /// Force-write now if dirty (call on app pause / critical moments).
  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_dirty) await save();
  }

  /// Migrates older progress payloads to the current schema in place.
  void _migrateSchema(Map<String, dynamic> j) {
    final v = (j['schema'] as num?)?.toInt() ?? 1; // v1 = pre-4.0 payloads
    if (v < 2) {
      // v1 -> v2: settings previously lived outside the progress blob;
      // cards map keys unchanged. Nothing structural to transform yet,
      // but we normalize optional containers defensively.
      j['lessonStars'] ??= <String, dynamic>{};
      j['cards'] ??= <String, dynamic>{};
    }
    j['schema'] = AppState.progressSchema;
  }
}
