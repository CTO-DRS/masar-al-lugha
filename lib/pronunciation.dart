// Pronunciation scoring engine (v5.6, Phase 4 skill 1).
//
// HONEST SCOPE: this scores a speech-recognition TRANSCRIPT against the
// expected word/sentence. It measures textual similarity, not acoustics —
// the score is an APPROXIMATION and the UI says so ("تقريبي"). Recognition
// quality itself depends on the platform STT engine and cannot be verified
// without a real device/microphone.
//
// Flutter-free and unit-tested (test/pronunciation_test.dart).
class PronScorer {
  PronScorer._();

  /// Normalizes both sides before comparing: lowercase, Unicode
  /// punctuation/symbols stripped, Arabic tashkeel + tatweel stripped,
  /// whitespace collapsed. Diacritics are IGNORED here (a learner reading
  /// without them should not be punished) unlike the dictation grader,
  /// where they are content — documented difference.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final r in raw.runes) {
      // Arabic tashkeel U+064B–U+065F, superscript alef 0670, tatweel 0640
      if (r >= 0x064B && r <= 0x065F || r == 0x0670 || r == 0x0640) continue;
      // skip punctuation & symbols (unicode categories P/S are mostly
      // non-alphanumeric non-space codepoints; keep letters, digits, spaces)
      if (r == 0x20) buffer.writeCharCode(r);
      final isAsciiAlnum = (r >= 0x30 && r <= 0x39) ||
          (r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A);
      final isArabic =
          (r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F);
      final isLatin1 = r >= 0x00C0 && r <= 0x024F; // é, ß, ü …
      if (isAsciiAlnum || isArabic || isLatin1) buffer.writeCharCode(r);
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Levenshtein edit distance (iterative, two rows — bounded inputs).
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        cur[j + 1] = [
          prev[j + 1] + 1, // deletion
          cur[j] + 1, // insertion
          prev[j] + cost, // substitution
        ].reduce((x, y) => x < y ? x : y);
      }
      final tmp = prev;
      prev = cur;
      cur = tmp;
    }
    return prev[b.length];
  }

  /// Similarity 0..100 between the expected text and what the recognizer
  /// heard. Empty transcript scores 0.
  static int score(String expected, String said) {
    final e = normalize(expected);
    final s = normalize(said);
    if (e.isEmpty || s.isEmpty) return 0;
    final dist = editDistance(e, s);
    final maxLen = e.length > s.length ? e.length : s.length;
    return ((1 - dist / maxLen) * 100).round().clamp(0, 100);
  }

  /// Verdict keys (l10n): great / close / partial / miss.
  /// Thresholds documented: ≥85 great, ≥60 close, >0 partial, else miss.
  static String verdictKey(int pct) {
    if (pct >= 85) return 'pronGreat';
    if (pct >= 60) return 'pronClose';
    if (pct > 0) return 'pronPartial';
    return 'pronMiss';
  }
}
