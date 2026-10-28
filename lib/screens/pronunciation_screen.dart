// Pronunciation practice (v5.6, Phase 4 skill 1): speak a course word and
// get an APPROXIMATE score by comparing the speech-to-text transcript with
// the expected text. Microphone permission is OPTIONAL — the feature is
// reached by explicit action, the OS dialog fires on first use, and every
// failure (no permission, no recognizer, test environment) degrades to an
// honest "unavailable" state instead of a fake score.
import 'package:flutter/material.dart';

import '../models.dart';
import '../pronunciation.dart';
import '../pronunciation_pairs.dart';
import '../scope.dart';
import '../services/stt.dart';
import '../srs.dart';
import '../theme.dart';
import '../widgets/mascot.dart';

class PronunciationScreen extends StatefulWidget {
  final String? initialWord;
  const PronunciationScreen({super.key, this.initialWord});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  late final List<Vocab> _words;
  late Vocab _current;
  final TextEditingController _pickCtrl = TextEditingController();

  // v5.17 (Phase-1 audit H-1): the corpus resolve runs in a post-frame
  // callback, but build() used to read `_current` unconditionally — the
  // first frame crashed with LateInitializationError on every open. The
  // body now waits for `_started` (same proven pattern as
  // quick_review_screen), and an empty corpus shows an honest empty state.
  bool _started = false;
  bool _wordsEmpty = false;

  /// v5.17 (Phase-1 audit M-2): was `FocusNode()` inline in build — a new
  /// node leaked on every rebuild (this screen rebuilds on every STT
  /// partial result). One node, owned by the State, disposed on exit.
  final FocusNode _pickFocus = FocusNode();

  /// Confusable pairs (F4.4) resolvable against THIS course's corpus —
  /// both sides must be real single words, otherwise the pair is dropped
  /// (a chip that opens nothing is a broken promise).
  List<MapEntry<PronPair, (Vocab, Vocab)>> _pairs = const [];

  bool _engineReady = false;
  bool _engineChecked = false;
  bool _listening = false;
  String _transcript = '';
  int? _score;
  String? _verdictKey;
  final SttService _stt = SttService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final st = AppScope.of(context);
      _words = st.course.allVocab.where((v) => !v.isSentence).toList();
      final byTarget = {
        for (final v in _words) v.target.toLowerCase(): v,
      };
      _pairs = [
        for (final p in PronPairCatalog.forCourse(st.course.id))
          if (byTarget[p.a.toLowerCase()] != null &&
              byTarget[p.b.toLowerCase()] != null)
            MapEntry(p,
                (byTarget[p.a.toLowerCase()]!, byTarget[p.b.toLowerCase()]!)),
      ];
      if (_words.isEmpty) {
        // Honest degradation: no practiceable words in this course.
        if (mounted) {
          setState(() {
            _wordsEmpty = true;
            _started = true;
          });
        }
        return;
      }
      _current = _words.firstWhere(
        (v) => widget.initialWord != null && v.target == widget.initialWord,
        orElse: () => _words.first,
      );
      if (widget.initialWord != null) _pickCtrl.text = _current.target;
      if (mounted) setState(() => _started = true);
      _engineReady = await _stt.init();
      if (mounted) setState(() => _engineChecked = true);
    });
  }

  @override
  void dispose() {
    _stt.stop();
    _pickCtrl.dispose();
    _pickFocus.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final tts = AppScope.ttsOf(context);
    await tts.setLanguage(AppScope.of(context).course.ttsLang);
    await tts.speak(_current.target);
  }

  Future<void> _listen() async {
    // Context is resolved ONCE at the top — every await below keeps a
    // mounted guard, never a BuildContext across a gap.
    final st = AppScope.of(context);
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_engineReady) {
      _engineReady = await _stt.init();
      if (!mounted) return;
      setState(() {});
      if (!_engineReady) return; // unavailable banner already visible
    }
    // v5.18 (Phase-2 Batch E): stop any ongoing TTS BEFORE the mic opens —
    // the recognizer must hear the LEARNER, not the app's own replay of
    // the same word (a real audio-resource conflict, not cosmetics).
    final tts = AppScope.ttsOf(context);
    await tts.stop();
    final locale = await _stt.localeFor(st.course.ttsLang);
    // v5.17 (Phase-1 audit M-3): the screen can close while the locale
    // query is in flight — never setState after dispose.
    if (!mounted) return;
    setState(() {
      _listening = true;
      _transcript = '';
      _score = null;
      _verdictKey = null;
    });
    await _stt.listen(
      localeId: locale ?? st.course.ttsLang.replaceAll('-', '_'),
      onFinal: (text) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _transcript = text.trim();
          _score = PronScorer.score(_current.target, _transcript);
          _verdictKey = PronScorer.verdictKey(_score!);
        });
      },
      onPartial: (text) {
        if (!mounted) return;
        setState(() => _transcript = text);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => context.tr(k);
    // v5.17 (Phase-1 audit H-1): first frame renders a neutral shell until
    // the corpus resolve completes (no more LateInitializationError).
    if (!_started) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('pronTitle'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_wordsEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('pronTitle'))),
        body: Center(
          child: Text(tr('noResults'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 15)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('pronTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr('pronIntro'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13.5)),
          const SizedBox(height: 16),
          // F4.4: confusable sound pairs — one chip per pair, tap toggles
          // between the two sides; both sides are real course words.
          if (_pairs.isNotEmpty) ...[
            Text(tr('pronPairs'),
                style: TextStyle(
                    color: context.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pairs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final entry = _pairs[i];
                  final active = entry.value.$1.id == _current.id ||
                      entry.value.$2.id == _current.id;
                  return Semantics(
                    button: true,
                    label: '${tr('pronPairs')}: '
                        '${entry.value.$1.target} / ${entry.value.$2.target}',
                    child: ActionChip(
                      avatar: Icon(Icons.hearing,
                          size: 18,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : context.mutedText),
                      label: Text(
                        '${entry.value.$1.target} / ${entry.value.$2.target}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500),
                      ),
                      backgroundColor: active ? context.softBg : null,
                      onPressed: () {
                        final sideA = _current.id != entry.value.$1.id;
                        final v = sideA ? entry.value.$1 : entry.value.$2;
                        setState(() {
                          _current = v;
                          _pickCtrl.text = v.target;
                          _transcript = '';
                          _score = null;
                          _verdictKey = null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          // word picker with autocomplete over the course corpus
          RawAutocomplete<Vocab>(
            textEditingController: _pickCtrl,
            focusNode: _pickFocus,
            displayStringForOption: (v) => v.target,
            optionsBuilder: (TextEditingValue value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<Vocab>.empty();
              return _words.where((v) =>
                  v.target.toLowerCase().contains(q) ||
                  v.translationAr.contains(value.text.trim()));
            },
            onSelected: (Vocab v) => setState(() {
              _current = v;
              _transcript = '';
              _score = null;
              _verdictKey = null;
            }),
            fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) =>
                TextField(
              controller: ctrl,
              focusNode: focus,
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: InputDecoration(
                hintText: tr('pronPickWord'),
                prefixIcon: Icon(Icons.search, color: context.mutedText),
                suffixIcon: Icon(Icons.record_voice_over,
                    color: context.mutedText, size: 20),
                filled: true,
                fillColor: context.softBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.line, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.line, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.green, width: 2),
                ),
              ),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final v in options.take(8))
                        ListTile(
                          dense: true,
                          title: Text(v.target,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(v.translationAr,
                              style: const TextStyle(fontSize: 12)),
                          onTap: () => onSelected(v),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // target card: word + TTS replay
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.line, width: 2),
            ),
            child: Column(
              children: [
                Text(_current.target,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_current.translationAr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText, fontSize: 15)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _speak,
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: Text(tr('pronSpeakFirst')),
                ),
                // v5.18 (Batch E): the pronunciation practice feeds the REAL
                // SRS — the same honest "hard" self-rating the reading
                // screen uses, so practice here counts in review too.
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    AppScope.of(context).rateCard(_current.id, Srs.hard);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('readingAdded')),
                      duration: const Duration(seconds: 2),
                    ));
                  },
                  icon: const Icon(Icons.style, size: 18),
                  label: Text(tr('readingAddReview')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // mic + result
          Center(
            child: GestureDetector(
              onTap: _listen,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? AppColors.red : AppColors.green,
                  boxShadow: [
                    BoxShadow(
                      color: (_listening ? AppColors.red : AppColors.green)
                          .withValues(alpha: 0.35),
                      blurRadius: _listening ? 26 : 10,
                      spreadRadius: _listening ? 6 : 1,
                    ),
                  ],
                ),
                child: Icon(_listening ? Icons.stop : Icons.mic,
                    color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _listening ? tr('pronListening') : tr('pronTapMic'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          if (_engineChecked && !_engineReady) ...[
            const SizedBox(height: 8),
            Text(tr('pronUnavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 8),
          // v5.18 (Batch E): honest engine disclosure — the recognition is
          // the DEVICE'S engine; the app itself never uploads audio.
          Text(tr('pronDeviceEngine'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 11.5)),
          if (_score != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.line, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _score! / 100,
                              strokeWidth: 8,
                              backgroundColor:
                                  context.line.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation(_score! >= 60
                                  ? AppColors.green
                                  : AppColors.orange),
                            ),
                            Text('$_score%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 15)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(_verdictKey!),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(tr('pronApprox'),
                                style: TextStyle(
                                    color: context.mutedText, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_transcript.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('${tr('pronSaid')}: "$_transcript"',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: context.mutedText, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const _HomeCompanion(),
        ],
      ),
    );
  }
}

// Small companion so the screen never goes quiet (same widget family as
// the learn path hero), kept private — no state persisted.
class _HomeCompanion extends StatelessWidget {
  const _HomeCompanion();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Mascot(size: 76, mood: MascotMood.happy));
  }
}
