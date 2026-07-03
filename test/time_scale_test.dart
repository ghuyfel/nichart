import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

void main() {
  group('timeTicks', () {
    test('hour spans tick on whole minutes', () {
      final r = timeTicks(
        DateTime(2026, 3, 5, 9, 7),
        DateTime(2026, 3, 5, 10, 7),
      );
      expect(r.granularity, TimeGranularity.minute);
      for (final t in r.ticks) {
        expect(t.second, 0);
        expect(t.minute % 15, 0, reason: 'expected 15-minute boundaries');
      }
    });

    test('week spans tick on midnights', () {
      final r = timeTicks(
        DateTime(2026, 3, 2, 14, 30),
        DateTime(2026, 3, 9, 8, 15),
      );
      expect(r.granularity, TimeGranularity.day);
      for (final t in r.ticks) {
        expect(t.hour, 0);
        expect(t.minute, 0);
      }
      expect(r.ticks.first.isAfter(DateTime(2026, 3, 2, 14, 30)), isTrue);
    });

    test('year spans tick on month starts', () {
      final r = timeTicks(DateTime(2026, 1, 15), DateTime(2026, 12, 20));
      expect(r.granularity, TimeGranularity.month);
      for (final t in r.ticks) {
        expect(t.day, 1);
      }
    });

    test('decade spans tick on year starts', () {
      final r = timeTicks(DateTime(2018, 6), DateTime(2026, 3));
      expect(r.granularity, TimeGranularity.year);
      for (final t in r.ticks) {
        expect(t.month, 1);
        expect(t.day, 1);
      }
    });

    test('very long spans use nice multi-year steps', () {
      final r = timeTicks(DateTime(1900), DateTime(2026), targetTickCount: 6);
      expect(r.granularity, TimeGranularity.year);
      expect(r.ticks.length, lessThanOrEqualTo(8));
      final step = r.ticks[1].year - r.ticks[0].year;
      expect(step, greaterThanOrEqualTo(10));
    });

    test('ticks stay inside the domain', () {
      final min = DateTime(2026, 3, 5, 9, 7);
      final max = DateTime(2026, 3, 8, 10, 7);
      final r = timeTicks(min, max);
      for (final t in r.ticks) {
        expect(t.isBefore(min), isFalse);
        expect(t.isAfter(max), isFalse);
      }
    });

    test('degenerate domain yields a single tick', () {
      final at = DateTime(2026, 3, 5);
      final r = timeTicks(at, at);
      expect(r.ticks, [at]);
    });
  });

  group('formatTimeTick', () {
    test('per-granularity formats', () {
      final t = DateTime(2026, 3, 5, 14, 30, 5);
      expect(formatTimeTick(t, TimeGranularity.second), '14:30:05');
      expect(formatTimeTick(t, TimeGranularity.minute), '14:30');
      expect(formatTimeTick(t, TimeGranularity.day), 'Mar 5');
      expect(formatTimeTick(t, TimeGranularity.month), 'Mar');
      expect(formatTimeTick(t, TimeGranularity.year), '2026');
    });

    test('boundary ticks promote themselves', () {
      // Midnight shows the date instead of 00:00.
      expect(
        formatTimeTick(DateTime(2026, 3, 5), TimeGranularity.hour),
        'Mar 5',
      );
      // January shows the year instead of the month.
      expect(
        formatTimeTick(DateTime(2026, 1, 1), TimeGranularity.month),
        '2026',
      );
    });
  });

  group('TimeScale', () {
    test('normalizes linearly over milliseconds', () {
      final scale = TimeScale(
        min: DateTime(2026, 1, 1),
        max: DateTime(2026, 1, 3),
      );
      expect(scale.normalize(DateTime(2026, 1, 1)), 0);
      expect(scale.normalize(DateTime(2026, 1, 2)), 0.5);
      expect(scale.normalize(DateTime(2026, 1, 3)), 1);
    });

    test('degenerate domain maps to center', () {
      final at = DateTime(2026);
      final scale = TimeScale(min: at, max: at);
      expect(scale.normalize(at), 0.5);
    });
  });

  group('CategoryScale', () {
    test('maps indices to band centers', () {
      final scale = CategoryScale(categories: const ['a', 'b', 'c', 'd']);
      expect(scale.normalize(0), 0.125);
      expect(scale.normalize(3), 0.875);
      expect(scale.bandFraction, 0.25);
      expect(scale.indexOf('c'), 2);
      expect(scale.indexOf('missing'), -1);
    });

    test('value semantics', () {
      final a = CategoryScale(categories: const ['x', 'y']);
      final b = CategoryScale(categories: const ['x', 'y']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
