// FSRS-lite spaced repetition engine (simplified Anki-inspired SM-2/FSRS hybrid).
import 'models.dart';

class Srs {
  static const int again = 0;
  static const int hard = 1;
  static const int good = 2;
  static const int easy = 3;

  static const int dayMs = 86400000;
  static const int tenMinMs = 10 * 60 * 1000;

  /// Apply a review rating [q] (0..3) to a card, mutating it in place.
  static void rate(CardData c, int q, {DateTime? now}) {
    final n = now ?? DateTime.now();
    c.reps += 1;

    switch (q) {
      case again:
        c.lapses += 1;
        c.ease = (c.ease - 0.20).clamp(1.3, 3.0);
        c.intervalDays = 0;
        c.state = 'learning';
        c.dueEpochMs = n.millisecondsSinceEpoch + tenMinMs;
        break;
      case hard:
        c.ease = (c.ease - 0.05).clamp(1.3, 3.0);
        if (c.intervalDays <= 0) {
          c.intervalDays = 0;
          c.state = 'learning';
          c.dueEpochMs = n.millisecondsSinceEpoch + tenMinMs;
        } else {
          c.intervalDays =
              (c.intervalDays * 1.2).round().clamp(1, 365);
          c.state = 'review';
          c.dueEpochMs = n.millisecondsSinceEpoch + c.intervalDays * dayMs;
        }
        break;
      case good:
        if (c.intervalDays <= 0) {
          c.intervalDays = 1;
        } else {
          c.intervalDays =
              (c.intervalDays * c.ease).round().clamp(1, 365);
        }
        c.state = 'review';
        c.dueEpochMs = n.millisecondsSinceEpoch + c.intervalDays * dayMs;
        break;
      case easy:
      default:
        c.ease = (c.ease + 0.05).clamp(1.3, 3.0);
        if (c.intervalDays <= 0) {
          c.intervalDays = 3;
        } else {
          c.intervalDays =
              (c.intervalDays * c.ease * 1.3).round().clamp(2, 365);
        }
        c.state = 'review';
        c.dueEpochMs = n.millisecondsSinceEpoch + c.intervalDays * dayMs;
        break;
    }
  }

  /// Human friendly hint for the next interval of a card given a rating.
  static String hintFor(CardData c, int q) {
    switch (q) {
      case again:
        return '10m';
      case hard:
        if (c.intervalDays <= 0) return '10m';
        final d = (c.intervalDays * 1.2).round().clamp(1, 365);
        return d == 1 ? '1d' : '${d}d';
      case good:
        final d = c.intervalDays <= 0
            ? 1
            : (c.intervalDays * c.ease).round().clamp(1, 365);
        return d == 1 ? '1d' : '${d}d';
      case easy:
      default:
        final d = c.intervalDays <= 0
            ? 3
            : (c.intervalDays * c.ease * 1.3).round().clamp(2, 365);
        return '${d}d';
    }
  }
}
