// AppScope: tiny inherited state holder + context helpers.
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'l10n.dart';
import 'services/tts.dart';

class AppScope extends InheritedNotifier<AppState> {
  final TtsService tts;
  const AppScope({
    super.key,
    required AppState state,
    required this.tts,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static TtsService ttsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.tts;
}

extension L10nX on BuildContext {
  String tr(String key) => L.t(AppScope.of(this).uiLocale, key);
}
