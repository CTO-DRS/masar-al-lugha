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
import 'calibration.dart';
import 'decks.dart';
import 'mascot.dart';
import 'models.dart';
import 'path.dart';
import 'streak_freeze.dart';

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
  // v5.10 local multi-profile slots: up to 3 independent learners on one
  // device, each with its OWN progress payload key. Purely local — no
  // accounts, no network (hard invariants); the "no account" mode stays
  // the default (slot 1 = the original key, byte-compatible).
  static const _kProfileNames = 'profile_names';
  static const maxProfiles = 3;
  int _slot = 1;
  int get slot => _slot;

  String get _kProgressSlot => _slot > 1 ? '${_kProgress}_$_slot' : _kProgress;
  String get _kBackupSlot => _slot > 1 ? '${_kBackup}_$_slot' : _kBackup;

  /// Switches the active profile slot. Flushes the CURRENT slot first so
  /// no debounced write lands in the wrong file afterwards.
  Future<void> setSlot(int s) async {
    final target = s.clamp(1, maxProfiles);
    if (target == _slot) return;
    await flush();
    _slot = target;
  }

  /// Device-level profile display names (slot -> name), owned here.
  Map<int, String> loadProfileNames() {
    // synchronous prefs access is not available; cached at load time via
    // [refreshProfileNames] — kept simple for the 3-slot scale.
    return _profileNames;
  }

  Map<int, String> _profileNames = {};

  Future<void> refreshProfileNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfileNames);
    if (raw == null) {
      _profileNames = {};
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _profileNames =
          j.map((k, v) => MapEntry(int.tryParse(k) ?? 1, (v as String?) ?? ''));
    } catch (_) {
      _profileNames = {};
    }
  }

  Future<void> saveProfileNames(Map<int, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    _profileNames = Map<int, String>.from(names);
    await prefs.setString(_kProfileNames,
        jsonEncode({for (final e in names.entries) '${e.key}': e.value}));
  }

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

    final raw = prefs.getString(_kProgressSlot);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _migrateSchema(j);
        s.xp = (j['xp'] as num?)?.toInt() ?? 0;
        s.streak = (j['streak'] as num?)?.toInt() ?? 0;
        // v4.8 records (additive, null-safe for old payloads).
        s.bestStreak = (j['bestStreak'] as num?)?.toInt() ?? 0;
        s.bestDayXp = (j['bestDayXp'] as num?)?.toInt() ?? 0;
        s.activeDays = (j['activeDays'] as num?)?.toInt() ?? 0;
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
        // v4.11 learning path (additive, null-safe; unknown names dropped).
        s.pathDomain = ((j['pathDomain'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, v as String))
          ..removeWhere((k, v) => PathEngine.domainByName(v) == null);
        s.pathTier = ((j['pathTier'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, v as String))
          ..removeWhere((k, v) => PathEngine.tierByName(v) == null);
        s.newCardsToday = (j['newCardsToday'] as num?)?.toInt() ?? 0;
        s.newCardsDay = (j['newCardsDay'] as String?) ?? '';
        // v4.4 local intelligence (additive, null-safe for old payloads).
        final ins = j['insights'];
        if (ins is Map) {
          s.confusionPairs = ((ins['confusionPairs'] as Map?) ?? {})
              .map((k, v) => MapEntry(k as String, (v as num).toInt()));
          s.hourTotal = _read24(ins['hourTotal']);
          s.hourCorrect = _read24(ins['hourCorrect']);
          s.answerLog = ((ins['answerLog'] as Map?) ?? {}).map((k, v) =>
              MapEntry(
                  k as String,
                  ((v as List?) ?? [])
                      .map((e) => (e as num).toInt())
                      .toList()));
          s.answerLog.removeWhere((_, e) => e.length < 2);
          // v5.12 (F2.2): calibration samples — strict shape check, oldest
          // first; malformed entries are dropped, valid ones clamped.
          final cal = ins['calibration'];
          if (cal is List) {
            s.calibrationLog = cal
                .whereType<List>()
                .map((e) {
                  if (e.length < 2) return null;
                  final r = (e[0] as num?)?.toInt();
                  final o = (e[1] as num?)?.toInt();
                  if (r == null || o == null) return null;
                  return [r.clamp(0, 1000), o == 0 ? 0 : 1];
                })
                .whereType<List<int>>()
                .toList();
            if (s.calibrationLog.length > Calibration.maxSamples) {
              s.calibrationLog.removeRange(
                  0, s.calibrationLog.length - Calibration.maxSamples);
            }
          }
        }
        // v5.12 (F2.4): remediation lapse log — bounded, strict parse.
        final ll = j['lapseLog'];
        if (ll is Map) {
          ll.forEach((k, v) {
            if (k is! String || v is! List) return;
            final days = v
                .map((e) => (e is num) ? e.toInt() : null)
                .whereType<int>()
                .toList();
            if (days.isEmpty) return;
            s.lapseLog[k] = days;
          });
        }
        // v5.12 (F2.5): streak freeze wallet (null-safe for old payloads).
        s.streakFreezes = (j['streakFreezes'] as num?)?.toInt() ?? 0;
        s.lastFreezeAwardMark =
            (j['lastFreezeAwardMark'] as num?)?.toInt() ?? 0;
        s.favorites = ((j['favorites'] as Map?) ?? {}).map((k, v) => MapEntry(
            k as String,
            ((v as List?) ?? []).map((e) => e as String).toList()));
        // v4.7 custom decks (additive, null-safe for old payloads):
        // strict parse in decks.dart drops malformed entries silently.
        final ds = j['decks'];
        if (ds is List) {
          final loaded = <CustomDeck>[];
          final seenIds = <String>{};
          for (final raw in ds.take(DeckLimits.maxDecks)) {
            if (raw is! Map) continue;
            final d = CustomDeck.fromJson(Map<String, dynamic>.from(raw));
            if (d == null || !seenIds.add(d.id)) continue;
            loaded.add(d);
          }
          s.customDecks = loaded;
          s.rebaseDeckCounter();
        }
        // v4.5 companion (additive, null-safe for old payloads).
        // Unknown ids fall back to the default companion.
        final m = j['mascot'];
        if (m is String && mascotCast.any((c) => c.id == m)) {
          s.mascotId = m;
        }
        final settings = j['settings'];
        if (settings is Map) {
          s.darkMode = (settings['darkMode'] as bool?) ?? s.darkMode;
          s.reduceMotion =
              (settings['reduceMotion'] as bool?) ?? s.reduceMotion;
          s.simplifiedAudio =
              (settings['simplifiedAudio'] as bool?) ?? s.simplifiedAudio;
          s.largerText = (settings['largerText'] as bool?) ?? s.largerText;
          s.ttsEnabled = (settings['ttsEnabled'] as bool?) ?? s.ttsEnabled;
          s.ttsRate = (settings['ttsRate'] as num?)?.toDouble() ?? s.ttsRate;
          s.analyticsOptIn =
              (settings['analyticsOptIn'] as bool?) ?? s.analyticsOptIn;
          s.retentionTarget =
              (settings['retentionTarget'] as num?)?.toDouble() ??
                  s.retentionTarget;
          // v5.12 (F2.5): daily reminder preferences.
          final rem = settings['reminders'];
          if (rem is Map) {
            s.reminders =
                ReminderSettings.fromJson(Map<String, dynamic>.from(rem));
          }
        }
        if (s.newCardsDay != AppState.todayKey()) {
          s.newCardsToday = 0;
          s.newCardsDay = AppState.todayKey();
        }
      } catch (_) {
        // Corrupt data — keep a recoverable copy before starting fresh.
        prefs.setString(_kBackupSlot, raw);
      }
    }
    // v5.10: profile names load unconditionally — a fresh slot has no
    // payload yet but its display name must still show up.
    await refreshProfileNames();
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
      'bestStreak': s.bestStreak, // v4.8
      'bestDayXp': s.bestDayXp, // v4.8
      'activeDays': s.activeDays, // v4.8
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
      'pathDomain': s.pathDomain,
      'pathTier': s.pathTier,
      'newCardsToday': s.newCardsToday,
      'newCardsDay': s.newCardsDay,
      'insights': {
        'confusionPairs': s.confusionPairs,
        'hourTotal': s.hourTotal,
        'hourCorrect': s.hourCorrect,
        'answerLog': s.answerLog,
        'calibration': s.calibrationLog, // v5.12 F2.2
      },
      'lapseLog': s.lapseLog, // v5.12 F2.4
      'streakFreezes': s.streakFreezes, // v5.12 F2.5
      'lastFreezeAwardMark': s.lastFreezeAwardMark, // v5.12 F2.5
      'favorites': s.favorites,
      'mascot': s.mascotId,
      'decks': s.customDecks.map((d) => d.toJson()).toList(),
      'settings': {
        'darkMode': s.darkMode,
        'reduceMotion': s.reduceMotion,
        'simplifiedAudio': s.simplifiedAudio,
        'largerText': s.largerText,
        'ttsEnabled': s.ttsEnabled,
        'ttsRate': s.ttsRate,
        'analyticsOptIn': s.analyticsOptIn,
        'retentionTarget': s.retentionTarget,
        'reminders': s.reminders.toJson(), // v5.12 F2.5
      },
    };
    await prefs.setString(_kProgressSlot, jsonEncode(j));
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
    // v2 additive keys (v4.4): insights + favorites are read null-safe in
    // load()/save() — no structural migration required; old app versions
    // simply ignore the extra keys (forward-compatible).
    j['schema'] = AppState.progressSchema;
  }

  /// Reads a 24-slot hour bucket list from a stored payload.
  static List<int> _read24(Object? raw) {
    final list =
        (raw as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    return list.length == 24 ? list : List<int>.filled(24, 0);
  }
}
