// Masar Al-Lugha (مسار اللغة) — main entry point.
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

  // Load courses from assets.
  for (final id in ['en', 'ur', 'fr']) {
    final raw = await rootBundle.loadString('assets/data/course_$id.json');
    state.courses[id] = Course.fromJson(jsonDecode(raw));
  }

  await state.load();
  await AppTtsConfig.applyCourseLang(tts, state);

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
            theme: buildTheme(_appLocale),
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
