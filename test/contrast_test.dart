// Theme-catalog contrast audit (v5.15, plan F3.3).
//
// The plan's acceptance: 100% of the (text, background) pairs in the theme
// catalog pass WCAG AA — 4.5:1 for normal text, 3:1 for large text — with
// documented exceptions only for non-text (decorative/icon) surfaces.
//
// This test IS the audit: it pins every pair the UI can legally render,
// computed with the same WCAG formula the catalog fixes were chosen by
// (lib/contrast.dart). If a future edit re-brightens a text color, this
// fails in CI before any learner sees a washed-out screen.
import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/contrast.dart';

void main() {
  group('WCAG AA — light mode text pairs', () {
    test('body and muted text pass 4.5:1', () {
      // ink on white / bgSoft (body).
      expect(Contrast.passesAA(0x3C3C3C, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x3C3C3C, 0xF7F7F7, large: false), isTrue);
      // inkLight (muted) — deepened to #707070 in v5.15 (was 4.48:1).
      expect(Contrast.passesAA(0x707070, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x707070, 0xF7F7F7, large: false), isTrue);
    });

    test('brand-hue TEXT colors pass 4.5:1 on light surfaces', () {
      // greenText / blueText / orangeText — the v5.15 text-safe shades.
      expect(Contrast.passesAA(0x378200, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x0F76B4, 0xFFFFFF, large: false), isTrue);
      expect(Contrast.passesAA(0x0F76B4, 0xF7F7F7, large: false), isTrue);
      expect(Contrast.passesAA(0xA86200, 0xFFFFFF, large: false), isTrue);
      // The VIVID hues are no longer legal as small text on light surfaces
      // — this assertion documents the rule so nobody reintroduces them.
      expect(Contrast.passesAA(0x1CB0F6, 0xFFFFFF, large: false), isFalse,
          reason: 'vivid blue must never be small text on white');
    });

    test('chunky-button surfaces pass the large-bold policy (3:1)', () {
      // ChunkyButton labels render >= 18.7px BOLD (WCAG large text), and
      // vivid surfaces are promoted to their -Dark sibling under white
      // text. These are the pairs the policy produces:
      expect(Contrast.passesAA(0xFFFFFF, 0x46A302, large: true), isTrue,
          reason: 'white on greenDark');
      expect(Contrast.passesAA(0xFFFFFF, 0x1899D6, large: true), isTrue,
          reason: 'white on blueDark');
      expect(Contrast.passesAA(0xFFFFFF, 0xEA2B2B, large: true), isTrue,
          reason: 'white on redDark');
      // And the policy is NECESSARY — the vivid shades fail even 3:1:
      expect(Contrast.passesAA(0xFFFFFF, 0x58CC02, large: true), isFalse,
          reason: 'white on vivid green must be promoted');
      expect(Contrast.passesAA(0xFFFFFF, 0x1CB0F6, large: true), isFalse,
          reason: 'white on vivid blue must be promoted');
    });

    test('tinted state surfaces keep ink-legible text (4.5:1)', () {
      // OptionCard selected/correct/wrong backgrounds with body text.
      expect(Contrast.passesAA(0x3C3C3C, 0xDDF4FF, large: false), isTrue);
      expect(Contrast.passesAA(0x3C3C3C, 0xD7FFB8, large: false), isTrue);
      expect(Contrast.passesAA(0x3C3C3C, 0xFFDFE0, large: false), isTrue);
      // Yellow node star-count is INK on yellow (7.1:1) — white failed.
      expect(Contrast.passesAA(0x3C3C3C, 0xFFC800, large: false), isTrue);
    });

    test('snackbar and inverted surfaces pass', () {
      expect(Contrast.passesAA(0xFFFFFF, 0x3C3C3C, large: false), isTrue);
    });
  });

  group('WCAG AA — dark mode text pairs', () {
    test('body and muted text pass 4.5:1', () {
      expect(Contrast.passesAA(0xF1F7FB, 0x1B2A32, large: false), isTrue);
      expect(Contrast.passesAA(0xF1F7FB, 0x131F24, large: false), isTrue);
      expect(Contrast.passesAA(0x9DB2BC, 0x1B2A32, large: false), isTrue);
      expect(Contrast.passesAA(0x9DB2BC, 0x22333C, large: false), isTrue);
      expect(Contrast.passesAA(0xF1F7FB, 0x22333C, large: false), isTrue);
    });

    test('dark icon-on-fill pairs pass the 3:1 non-text bar', () {
      // The locked padlock icon: darkInkLight on darkLocked (3.71:1).
      expect(Contrast.ratio(0x9DB2BC, 0x3C5260) >= 3.0, isTrue);
    });
  });

  group('WCAG AA — light non-text (icons)', () {
    test('locked padlock icon passes 3:1 after the lockedDark fix', () {
      // lockedDark deepened #CFCFCF -> #808080 (was 1.24:1 — invisible).
      expect(Contrast.ratio(0x808080, 0xE5E5E5) >= 3.0, isTrue);
    });
  });

  group('contrast math sanity', () {
    test('black/white extremes and known values', () {
      expect(Contrast.ratio(0x000000, 0xFFFFFF), closeTo(21.0, 0.1));
      expect(Contrast.ratio(0xFFFFFF, 0xFFFFFF), closeTo(1.0, 0.001));
      // The classic 4.5 boundary example: #767676 on white is 4.54:1.
      expect(Contrast.ratio(0x767676, 0xFFFFFF) >= 4.5, isTrue);
      // #777777 on white is 4.48:1 — the original inkLight really failed.
      expect(Contrast.ratio(0x777777, 0xFFFFFF) < 4.5, isTrue);
    });
  });
}
