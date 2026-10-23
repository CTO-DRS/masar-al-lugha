// Text-to-speech wrapper (flutter_tts) with graceful fallbacks.
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  String _currentLang = '';
  bool ready = false;
  bool enabled = true;
  double rate = 0.9;

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  Future<void> setLanguage(String lang) async {
    if (!ready || lang == _currentLang) return;
    try {
      final ok = await _tts.isLanguageAvailable(lang);
      if (ok == true) {
        await _tts.setLanguage(lang);
        _currentLang = lang;
      } else {
        // Fallback: try base language (e.g. ur-PK -> ur).
        final base = lang.split('-').first;
        final okBase = await _tts.isLanguageAvailable(base);
        if (okBase == true) {
          await _tts.setLanguage(base);
          _currentLang = base;
        }
      }
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!ready || !enabled || text.trim().isEmpty) return;
    try {
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
