// Masar Al-Lugha (مسار اللغة) — main entry point.
// v4.0: light+dark themes, persisted TTS prefs, lifecycle-safe save flush.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'models.dart';
import 'scope.dart';
import 'services/tts.dart';
import 'theme.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final tts = TtsService();
  await tts.init();

  final state = AppState();

  // v5.0: four courses — English, Urdu, French and German.
  for (final id in ['en', 'ur', 'fr', 'de']) {
    final raw = await rootBundle.loadString('assets/data/course_$id.json');
    state.courses[id] = Course.fromJson(jsonDecode(raw));
  }

  await state.load();
  await AppTtsConfig.applyCourseLang(tts, state);
  // v4.0: TTS preferences persist across launches (audit M2).
  tts.enabled = state.ttsEnabled;
  tts.rate = state.ttsRate;

  runApp(MasarApp(state: state, tts: tts));
}

class AppTtsConfig {
  static Future<void> applyCourseLang(TtsService tts, AppState state) async {
    await tts.setLanguage(state.course.ttsLang);
  }
}

class MasarApp extends StatefulWidget {
  final AppState state;
  final TtsService tts;

  const MasarApp({super.key, required this.state, required this.tts});

  @override
  State<MasarApp> createState() => _MasarAppState();
}

class _MasarAppState extends State<MasarApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // v4.0 (audit M3/L5): pending debounced saves are flushed when the app
    // goes to background so nothing is lost between 2-second save windows.
    _lifecycle = AppLifecycleListener(
      onPause: () => widget.state.flush(),
      onInactive: () => widget.state.flush(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Locale get _appLocale =>
      widget.state.uiLocale == 'ar' ? const Locale('ar') : const Locale('en');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return AppScope(
          state: widget.state,
          tts: widget.tts,
          child: MaterialApp(
            title: 'مسار اللغة',
            debugShowCheckedModeBanner: false,
            theme: buildMasarTheme(dark: false),
            darkTheme: buildMasarTheme(dark: true),
            themeMode: widget.state.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: _appLocale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
