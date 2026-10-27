// AppScope: tiny inherited state holder + context helpers.
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'l10n.dart';
import 'services/notifications.dart';
import 'services/tts.dart';

class AppScope extends InheritedNotifier<AppState> {
  final TtsService tts;

  /// v5.12 (F2.5): the daily-reminder orchestrator, created once in main
  /// and shared so settings toggles and app-launch syncs hit the same
  /// notifier state.
  final ReminderService reminders;

  const AppScope({
    super.key,
    required AppState state,
    required this.tts,
    required this.reminders,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static TtsService ttsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.tts;

  static ReminderService remindersOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.reminders;
}

extension L10nX on BuildContext {
  String tr(String key) => L.t(AppScope.of(this).uiLocale, key);

  /// v4.4: translate then substitute {param} placeholders — used by the
  /// insights tips whose templates carry runtime numbers/words.
  String trF(String key, Map<String, String> params) {
    var s = tr(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}
