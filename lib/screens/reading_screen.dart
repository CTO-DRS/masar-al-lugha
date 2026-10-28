// Reading screen (v5.8, Phase 4 skill 3): leveled texts per course; tap any
// word → meaning sheet (course-corpus lookup), TTS replay, and one-tap
// "add to review" feeding the REAL SRS via rateCard(hard) — an honest
// self-rating, identical to the flashcards path.
import 'package:flutter/material.dart';

import '../reading.dart';
import '../scope.dart';
import '../srs.dart';
import '../theme.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courseId = AppScope.of(context).courseId;
    final texts = ReadingCatalog.forCourse(courseId);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('readingTitle'))),
      body: texts.isEmpty
          ? Center(child: Text(context.tr('readingNone')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(context.tr('readingIntro'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText, fontSize: 13)),
                const SizedBox(height: 14),
                for (final t in texts) _TextCard(text: t),
              ],
            ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final ReadingText text;
  const _TextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.line, width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(text.titleAr,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(text.level,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(text.titleEn,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedText, fontSize: 12)),
                ),
              ],
            ),
          ),
          children: [
            _Reader(text: text),
            if (text.questions.isNotEmpty)
              _Comprehension(text: text),
          ],
        ),
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  final ReadingText text;
  const _Reader({required this.text});

  List<List<String>> _tokenizedSentences() => [
        for (final s in text.sentences())
          s.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList()
      ];

  @override
  Widget build(BuildContext context) {
    final sentences = text.sentences();
    final tokens = _tokenizedSentences();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('readingTapHint'),
            style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (var i = 0; i < sentences.length; i++) ...[
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final w in tokens[i])
                GestureDetector(
                  onTap: () => _showWordSheet(context, w),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border(
                        bottom: BorderSide(
                            color: AppColors.green.withValues(alpha: 0.45),
                            width: 1.5),
                      ),
                    ),
                    child: Text(w,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          if (i < text.sentencesAr.length) ...[
            const SizedBox(height: 3),
            Text(text.sentencesAr[i],
                style: TextStyle(
                    color: context.mutedText, fontSize: 13, height: 1.5)),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _showWordSheet(BuildContext context, String rawWord) {
    final st = AppScope.of(context);
    final course = st.course;
    final v = ReadingCatalog.lookup(course, rawWord);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(rawWord,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (v != null) ...[
                Text(v.translationAr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final tts = AppScope.ttsOf(context);
                        await tts.setLanguage(course.ttsLang);
                        await tts.speak(v.target);
                      },
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: Text(sheetCtx.tr('pronSpeakFirst')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () {
                        // honest SRS feed: a "hard" self-rating, the SAME
                        // path the flashcards use — no fake mastery signal.
                        st.rateCard(v.id, Srs.hard);
                        Navigator.of(sheetCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(sheetCtx.tr('readingAdded')),
                              duration: const Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.style, size: 18),
                      label: Text(sheetCtx.tr('readingAddReview')),
                    ),
                  ],
                ),
              ] else ...[
                Text(sheetCtx.tr('readingNotInCourse'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// v5.18 (Phase-2 Batch D1): comprehension questions under the text.
/// Answers enter the REAL stats (recordAnswer feeds accuracy/insights; a
/// correct answer earns 1 XP — the same rate as weak-words practice and
/// grammar drills). Each question answers at most once — the per-question
/// answered gate makes rebuilds and re-taps incapable of double-counting.
class _Comprehension extends StatefulWidget {
  final ReadingText text;
  const _Comprehension({required this.text});

  @override
  State<_Comprehension> createState() => _ComprehensionState();
}

class _ComprehensionState extends State<_Comprehension> {
  final Map<int, int> _picked = {}; // question index -> picked option

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('readingCheckTitle'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 14.5)),
          const SizedBox(height: 8),
          for (var qi = 0; qi < widget.text.questions.length; qi++)
            _questionCard(qi),
        ],
      ),
    );
  }

  Widget _questionCard(int qi) {
    final q = widget.text.questions[qi];
    final picked = _picked[qi];
    final answered = picked != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.promptAr,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 8),
          for (var oi = 0; oi < q.options.length; oi++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OptionCard(
                text: q.options[oi],
                selected: picked == oi,
                correct: answered && oi == q.correct,
                wrong: answered && picked == oi && oi != q.correct,
                onTap: answered ? null : () => _pick(qi, oi),
              ),
            ),
        ],
      ),
    );
  }

  void _pick(int qi, int oi) {
    final q = widget.text.questions[qi];
    final st = AppScope.of(context);
    setState(() => _picked[qi] = oi);
    st.recordAnswer(oi == q.correct);
    if (oi == q.correct) st.addXp(1);
  }
}
