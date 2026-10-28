// Theme-catalog contrast audit (v5.15, plan F3.3 — values re-pinned for the
// v5.17 Phase-1 "فضاء مسار" identity).
//
// The plan's acceptance: 100% of the (text, background) pairs in the theme
// catalog pass WCAG AA — 4.5:1 for normal text, 3:1 for large text — with
// documented exceptions only for non-text (decorative/icon) surfaces.
//
// This test IS the audit: it pins every pair the UI can legally render,
// computed with the same WCAG formula the catalog fixes were chosen by
// (lib/contrast.dart). If a future edit re-brightens a text color, this
// fails in CI before any learner sees a washed-out screen. The v5.17 values
// were verified with the same formula BEFORE the palette landed (audit log,
// PHASE_1_TEST_REPORT_AR.md).
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/contrast.dart';

void main() {
  group('WCAG AA — light mode text pairs', () {
    test('body and muted text pass 4.5:1', () {
      // ink #1A2233 on white / bgSoft (body).
      expect(Contrast.passesAA(0x1A2233, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x1A2233, 0xF4F6FB, large: false), isTrue);
      // inkLight #5A6579 (muted) — re-derived for the v5.17 identity.
      expect(Contrast.passesAA(0x5A6579, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x5A6579, 0xF4F6FB, large: false), isTrue);
    });

    test('brand-hue TEXT colors pass 4.5:1 on light surfaces', () {
      // greenText / blueText / purpleText / orangeText — text-safe shades.
      expect(Contrast.passesAA(0x12704E, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x0B6B77, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x0B6B77, 0xF4F6FB, large: false), isTrue);
      expect(Contrast.passesAA(0x6E4FD8, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0xA86200, 0xFFFFFF, large: false), isTrue);
      // The VIVID hues are no longer legal as small text on light surfaces
      // — this assertion documents the rule so nobody reintroduces them.
      expect(Contrast.passesAA(0x42E8F5, 0xFFFFFF, large: false), isFalse,
          reason: 'vivid cyan must never be small text on white');
    });

    test('chunky-button surfaces pass the large-bold policy (3:1)', () {
      // ChunkyButton labels render >= 18.7px BOLD (WCAG large text), and
      // vivid surfaces are promoted to their -Dark sibling under white
      // text. These are the pairs the policy produces:
      expect(Contrast.passesAA(0xFFFFFF, 0x12805A, large: true), isTrue,
          reason: 'white on greenDark');
      expect(Contrast.passesAA(0xFFFFFF, 0x0E7C8A, large: true), isTrue,
          reason: 'white on blueDark');
      expect(Contrast.passesAA(0xFFFFFF, 0xEA2B2B, large: true), isTrue,
          reason: 'white on redDark');
      // And the policy is NECESSARY — the vivid shades fail even 3:1:
      expect(Contrast.passesAA(0xFFFFFF, 0x42E6A4, large: true), isFalse,
          reason: 'white on vivid green must be promoted');
      expect(Contrast.passesAA(0xFFFFFF, 0x42E8F5, large: true), isFalse,
          reason: 'white on vivid cyan must be promoted');
    });

    test('tinted state surfaces keep ink-legible text (4.5:1)', () {
      // OptionCard selected/correct/wrong backgrounds with body text.
      expect(Contrast.passesAA(0x1A2233, 0xDFF7FB, large: false), isTrue);
      expect(Contrast.passesAA(0x1A2233, 0xDDF9EC, large: false), isTrue);
      expect(Contrast.passesAA(0x1A2233, 0xFFE4E9, large: false), isTrue);
      // Yellow node star-count is INK on yellow (10.2:1) — white failed.
      expect(Contrast.passesAA(0x1A2233, 0xFFC800, large: false), isTrue);
    });

    test('snackbar and inverted surfaces pass', () {
      expect(Contrast.passesAA(0xFFFFFF, 0x1A2233, large: false), isTrue);
    });
  });

  group('WCAG AA — dark mode text pairs (space identity)', () {
    test('body and muted text pass 4.5:1', () {
      expect(Contrast.passesAA(0xF4F7FF, 0x10182B, large: false), isTrue);
      expect(Contrast.passesAA(0xF4F7FF, 0x080B16, large: false), isTrue);
      expect(Contrast.passesAA(0xF4F7FF, 0x182338, large: false), isTrue);
      expect(Contrast.passesAA(0xA9B4CE, 0x10182B, large: false), isTrue);
      expect(Contrast.passesAA(0xA9B4CE, 0x182338, large: false), isTrue);
    });

    test('dark icon-on-fill pairs pass the 3:1 non-text bar', () {
      // The locked padlock icon: darkInkLight on darkLocked.
      expect(Contrast.ratio(0xA9B4CE, 0x2A3752) >= 3.0, isTrue);
    });

    test('vivid accents stay legal as text/icons on the dark depths', () {
      // On the deep-space surfaces the vivid accents carry enough
      // contrast for accent text and icons (>= 3:1):
      expect(Contrast.ratio(0x42E8F5, 0x10182B) >= 3.0, isTrue,
          reason: 'cyan accent on dark card');
      expect(Contrast.ratio(0x9B7BFF, 0x080B16) >= 3.0, isTrue,
          reason: 'violet icon on dark bg');
      expect(Contrast.ratio(0x42E6A4, 0x080B16) >= 3.0, isTrue,
          reason: 'green icon on dark bg');
    });
  });

  group('WCAG AA — light non-text (icons)', () {
    test('locked padlock icon passes 3:1', () {
      // lockedDark #808080 on the locked fill #E5E8F0 (v5.17 surfaces).
      expect(Contrast.ratio(0x808080, 0xE5E8F0) >= 3.0, isTrue);
    });
  });

  group('contrast math sanity', () {
    test('black/white extremes and known values', () {
      expect(Contrast.ratio(0x000000, 0xFFFFFF), closeTo(21.0, 0.1));
      expect(Contrast.ratio(0xFFFFFF, 0xFFFFFF), closeTo(1.0, 0.001));
      // The classic 4.5 boundary example: #767676 on white is 4.54:1.
      expect(Contrast.ratio(0x767676, 0xFFFFFF) >= 4.5, isTrue);
      // #777777 on white is 4.48:1 — below the AA floor.
      expect(Contrast.ratio(0x777777, 0xFFFFFF) < 4.5, isTrue);
    });
  });
}
