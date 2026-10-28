// Dictionary: searchable word bank of the current course (v2.0).
import 'package:flutter/material.dart';

import 'pronunciation_screen.dart';

import '../models.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import 'home_shell.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String query = '';

  // v5.17 (Phase-1 audit P-1): the search used to rescan the whole corpus
  // and allocate toLowerCase() per word on EVERY build — and AppScope
  // notifies on every XP/favorite change, so the scan ran far more often
  // than the user typed. The corpus is now indexed once per course object
  // (lowercased targets) and the row list is memoized per (course, query);
  // the cache is capped so long typing sessions cannot accumulate memory.
  _SearchIndex? _index;
  final Map<(Course, String), List<_Row>> _rowCache = {};

  _SearchIndex _indexFor(Course course) {
    final existing = _index;
    if (existing == null || existing.course != course) {
      _index = _SearchIndex(course);
      _rowCache.clear();
    }
    return _index!;
  }

  List<_Row> _rowsFor(_SearchIndex ix, String q) {
    final key = (ix.course, q);
    final cached = _rowCache[key];
    if (cached != null) return cached;
    final rows = <_Row>[
      for (final e in ix.entries)
        if (q.isEmpty || _matchesEntry(e, q)) e.row,
    ];
    if (_rowCache.length > 8) _rowCache.clear(); // bounded memo
    _rowCache[key] = rows;
    return rows;
  }

  bool _matchesEntry(_SearchEntry e, String q) {
    return e.targetLower.contains(q.toLowerCase()) ||
        e.row.vocab.translationAr.contains(q) ||
        (e.row.vocab.phonetic ?? '').contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    String tr(String k) => context.tr(k);
    final course = st.course;

    // Build rows grouped by unit (memoized — see _rowsFor above).
    final rows = _rowsFor(_indexFor(course), query);

    return Scaffold(
      body: Column(
        children: [
          const TopStatsBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => query = v.trim()),
              decoration: InputDecoration(
                hintText: tr('searchWords'),
                prefixIcon: Icon(Icons.search, color: context.mutedText),
                // v5.6: pronunciation practice entry — practice the word
                // currently typed in the search box (or the first word).
                suffixIcon: IconButton(
                  tooltip: tr('pronTitle'),
                  icon: Icon(Icons.record_voice_over,
                      color: AppColors.green, size: 22),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PronunciationScreen(
                          initialWord: query.isEmpty ? null : query),
                    ),
                  ),
                ),
                filled: true,
                fillColor: context.softBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Text(
                  '${rows.length} ${tr('words')}',
                  style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
                const Spacer(),
                // v5.17 (Phase-1 audit M-6): the hint overflowed this Row on
                // 360dp phones — it now wraps instead of clipping.
                Flexible(
                  child: Text(
                    tr('tapToListen'),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Mascot(size: 90, mood: MascotMood.neutral),
                        const SizedBox(height: 12),
                        Text(tr('noResults'),
                            style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final showUnitHeader =
                          i == 0 || rows[i - 1].unit.id != r.unit.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showUnitHeader) _unitHeader(context, r),
                          _WordTile(row: r),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _unitHeader(BuildContext context, _Row r) {
    final st = AppScope.of(context);
    final color = _hexToColor(r.unit.colorHex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        '${st.uiLocale == 'ar' ? r.unit.titleAr : r.unit.titleEn} · '
        '${st.uiLocale == 'ar' ? r.lesson.titleAr : r.lesson.titleEn}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Row {
  final Unit unit;
  final Lesson lesson;
  final Vocab vocab;
  _Row({required this.unit, required this.lesson, required this.vocab});
}

/// v5.17 (Phase-1 audit P-1): one lowercase index per course OBJECT —
/// rebuilt only when the course instance changes (switchCourse / reload).
class _SearchIndex {
  final Course course;
  final List<_SearchEntry> entries;
  _SearchIndex(Course c)
      : course = c,
        entries = [
          for (final unit in c.units)
            for (final lesson in unit.lessons)
              for (final v in lesson.vocab)
                _SearchEntry(
                  row: _Row(unit: unit, lesson: lesson, vocab: v),
                  targetLower: v.target.toLowerCase(),
                ),
        ];
}

class _SearchEntry {
  final _Row row;
  final String targetLower;
  _SearchEntry({required this.row, required this.targetLower});
}

class _WordTile extends StatefulWidget {
  final _Row row;
  const _WordTile({required this.row});

  @override
  State<_WordTile> createState() => _WordTileState();
}

class _WordTileState extends State<_WordTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final v = widget.row.vocab;
    final color = _hexToColor(widget.row.unit.colorHex);
    final card = st.cardFor(v.id);
    final state = card?.state ?? 'new';
    final stateColor = state == 'review'
        ? AppColors.green
        : state == 'learning'
            ? AppColors.orange
            : AppColors.lockedDark;
    final stateLabel = state == 'review'
        ? context.tr('reviewCards')
        : state == 'learning'
            ? context.tr('learningCards')
            : context.tr('newCards');

    return GestureDetector(
      onTap: () => setState(() => expanded = !expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: expanded ? context.softBg : context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded ? color : AppColors.border,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // emoji avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (v.emoji ?? '').isEmpty ? '🎓' : v.emoji!,
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.target,
                        // v5.17 (Phase-1 audit RTL-1): the headword is
                        // TARGET-language text (Latin/Urdu) — it must lay
                        // out in its own script, like the example below.
                        textDirection: directionOf(v.target),
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        v.translationAr,
                        style:
                            TextStyle(color: context.mutedText, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // v4.4: favorite star + speak button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => st.toggleFavorite(v.id),
                          // v5.15 (F3.3): semantic label + 48dp target —
                          // the favorite toggle was a 38dp mystery star.
                          child: Semantics(
                            label: context.tr('semFavorite'),
                            button: true,
                            selected: st.isFavorite(v.id),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.yellow
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    st.isFavorite(v.id)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: AppColors.yellow,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // speak button
                        GestureDetector(
                          onTap: () {
                            final tts = AppScope.ttsOf(context);
                            tts
                                .setLanguage(st.course.ttsLang)
                                .then((_) => tts.speak(v.target));
                          },
                          // v5.15 (F3.3): semantic label + 48dp target.
                          child: Semantics(
                            label: context.tr('semSpeak'),
                            button: true,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.blueLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.volume_up,
                                      color: AppColors.blueText, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stateLabel,
                        style: TextStyle(
                            color: stateColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              if (v.phonetic != null)
                Row(
                  children: [
                    Icon(Icons.record_voice_over,
                        size: 16, color: context.mutedText),
                    const SizedBox(width: 6),
                    Text(v.phonetic!,
                        style:
                            TextStyle(color: context.mutedText, fontSize: 13)),
                  ],
                ),
              if (v.exampleTarget != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.line, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.exampleTarget!,
                          // v4.12.1: example is target-language text.
                          textDirection: directionOf(v.exampleTarget!),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(v.exampleAr ?? '',
                          style: TextStyle(
                              color: context.mutedText, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  // v5.17 (Phase-1 audit L-1): malformed content data must not crash the
  // dictionary build — degrade to the brand blue instead.
  try {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return AppColors.blue;
  }
}
