// Local daily-reminder service for Masar Al-Lugha (v5.12, plan F2.5).
//
// Privacy contract (hard invariants of the app): reminders are scheduled
// ON DEVICE via AlarmManager through flutter_local_notifications. No
// network, no push, no accounts — the phone itself rings at the chosen
// local time. Nothing ever leaves the device.
//
// Design notes (honest limitations, documented on purpose):
//  - The schedule is (re)anchored on every app launch, so a reboot simply
//    restores the reminder the next time the app is opened.
//  - The timezone is resolved from the device's current UTC offset
//    (Etc/GMT±N), NOT an IANA zone — that avoids a platform-channel
//    dependency. In DST-observing regions the reminder can drift by the
//    DST delta until the next app launch re-anchors it. Saudi Arabia and
//    most of the app's audience live in non-DST zones.
//  - Scheduling uses AndroidScheduleMode.inexactAllowWhileIdle: no exact-
//    alarm permission needed, and a practice reminder does not need
//    second-level precision.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The 10-year database keeps the payload small and covers any reminder
// schedule a phone will realistically hold.
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../streak_freeze.dart';

/// The reminder notification id (one fixed id — enabling twice replaces).
const int kDailyReminderId = 20251201;

/// Seam over the notification plugin so [ReminderService] logic is
/// unit-testable with a fake (the plugin itself is never touched in tests).
abstract class NotificationApi {
  /// Idempotent plugin bootstrap. Returns false when the platform cannot
  /// support notifications (never on Android in practice).
  Future<bool> init();

  /// Asks Android 13+ for POST_NOTIFICATIONS. True when granted (or not
  /// needed on older versions).
  Future<bool> requestPermission();

  /// Schedules (or replaces) the repeating daily reminder at local
  /// [hour]:[minute].
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  });

  /// Removes the daily reminder.
  Future<void> cancelDaily(int id);
}

class PluginNotificationApi implements NotificationApi {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<bool> init() async {
    if (_initialized) return true;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ok = await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    // Anchor the tz database at the device's current UTC offset.
    tzdata.initializeTimeZones();
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    final name = offsetHours == 0
        ? 'Etc/GMT'
        : offsetHours > 0
            ? 'Etc/GMT-$offsetHours' // tz database sign is inverted
            : 'Etc/GMT+${-offsetHours}';
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/GMT'));
    }
    _initialized = ok ?? false;
    return _initialized;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true; // pre-Android-13: permission not needed
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder', // channel id
        'Daily reminder', // channel name (shown in system settings)
        channelDescription: 'Local daily practice reminder',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    final fire = tz.TZDateTime.from(
      _nextLocalSlot(DateTime.now(), hour, minute),
      tz.local,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      fire,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  @override
  Future<void> cancelDaily(int id) => _plugin.cancel(id);

  static DateTime _nextLocalSlot(DateTime now, int hour, int minute) {
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

/// Test-double-friendly orchestrator: owns WHEN to ask for permission,
/// WHEN to (re)schedule and WHEN to cancel. The UI and main.dart call
/// [sync] only; tests assert against the recorded calls.
class ReminderService {
  final NotificationApi api;

  ReminderService(this.api);

  /// What the notifier currently holds (mirrors the last successful sync).
  bool get scheduledActive => _active;
  int get scheduledHour => _activeHour;
  int get scheduledMinute => _activeMinute;
  bool get permissionGranted => _permissionGranted;

  bool _active = false;
  int _activeHour = -1;
  int _activeMinute = -1;
  bool _permissionGranted = false;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  /// Applies [settings]: disables → cancels; enables → asks permission
  /// (first time only) then schedules/replaces. Returns false when the
  /// learner denied the permission (settings should reflect OFF in that
  /// case — the caller flips the flag back).
  Future<bool> sync({
    required ReminderSettings settings,
    required String title,
    required String body,
  }) async {
    if (!settings.enabled) {
      if (_active) {
        await api.cancelDaily(kDailyReminderId);
        cancelCalls += 1;
        _active = false;
      }
      return true;
    }

    if (!_active) {
      await api.init();
      if (!_permissionGranted) {
        _permissionGranted = await api.requestPermission();
      }
      if (!_permissionGranted) return false;
    }

    await api.scheduleDaily(
      id: kDailyReminderId,
      title: title,
      body: body,
      hour: settings.hour,
      minute: settings.minute,
    );
    scheduleCalls += 1;
    _active = true;
    _activeHour = settings.hour;
    _activeMinute = settings.minute;
    return true;
  }
}
