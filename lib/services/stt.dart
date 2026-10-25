// Speech-to-text service (v5.6): a thin, honest wrapper over the
// speech_to_text plugin. The recognition engine is the DEVICE'S — quality
// varies per phone/locale and cannot be verified without real hardware,
// so every failure path degrades to an explicit "unavailable" state the UI
// surfaces verbatim.
//
// Not unit-testable without a device: the platform channel throws
// MissingPluginException under `flutter test`; the UI treats that exactly
// like an unavailable engine (pinned by the widget smoke test).
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  /// Initializes the plugin (this is where the OS microphone permission
  /// dialog fires). Returns false on any failure — including the test
  /// environment, where no platform channel exists.
  Future<bool> init() async {
    if (_available) return true;
    try {
      _available = await _stt.initialize();
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Maps a course ttsLang ("de-DE") to a recognizer locale ("de_DE").
  /// Falls back to the system default when the exact locale is missing.
  Future<String?> localeFor(String ttsLang) async {
    if (!_available) return null;
    final want = ttsLang.replaceAll('-', '_');
    try {
      final locales = await _stt.locales();
      for (final l in locales) {
        if (l.localeId == want) return want;
      }
      final prefix = want.split('_').first;
      for (final l in locales) {
        if (l.localeId.startsWith('${prefix}_') || l.localeId == prefix) {
          return l.localeId;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Starts one listen session. [onFinal] fires once with the best final
  /// transcript; [onPartial] streams interim text (may be ignored).
  Future<void> listen({
    required String localeId,
    required void Function(String text) onFinal,
    void Function(String text)? onPartial,
  }) async {
    if (!_available) return;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (r) {
        if (r.finalResult) {
          onFinal(r.recognizedWords);
        } else {
          onPartial?.call(r.recognizedWords);
        }
      },
    );
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {
      // already stopped / channel gone — nothing to recover
    }
  }
}
