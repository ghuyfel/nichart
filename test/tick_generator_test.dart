import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

void main() {
  group('niceNum', () {
    test('rounds to 1-2-5 steps', () {
      expect(niceNum(24.25, round: true), 20);
      expect(niceNum(2.8, round: true), 2);
      expect(niceNum(3.2, round: true), 5);
      expect(niceNum(0.7, round: true), 0.5);
      expect(niceNum(8, round: true), 10);
    });

    test('ceiling variant covers the range', () {
      expect(niceNum(24.25, round: false), 50);
      expect(niceNum(1.2, round: false), 2);
      expect(niceNum(5.0, round: false), 5);
    });

    test('degenerate input falls back to 1', () {
      expect(niceNum(0, round: true), 1);
      expect(niceNum(-3, round: true), 1);
      expect(niceNum(double.nan, round: true), 1);
    });
  });

  group('niceDomain', () {
    test('expands to round bounds', () {
      final d = niceDomain(3, 97);
      expect(d.min, 0);
      expect(d.max, 100);
      expect(d.step, 20);
    });

    test('handles negative ranges', () {
      final d = niceDomain(-42, 17);
      expect(d.min, lessThanOrEqualTo(-42));
      expect(d.max, greaterThanOrEqualTo(17));
      expect(d.step, greaterThan(0));
    });

    test('repairs min == max', () {
      final d = niceDomain(5, 5);
      expect(d.min, lessThan(5));
      expect(d.max, greaterThan(5));
    });

    test('repairs zero-only domain', () {
      final d = niceDomain(0, 0);
      expect(d.max, greaterThan(d.min));
    });

    test('repairs reversed and non-finite input', () {
      final reversed = niceDomain(10, 2);
      expect(reversed.min, lessThanOrEqualTo(2));
      expect(reversed.max, greaterThanOrEqualTo(10));
      final broken = niceDomain(double.nan, double.infinity);
      expect(broken.min.isFinite, isTrue);
      expect(broken.max.isFinite, isTrue);
    });
  });

  group('ticksWithin', () {
    test('produces round ticks inside the domain', () {
      final ticks = ticksWithin(3, 97);
      expect(ticks, [20, 40, 60, 80]);
    });

    test('includes bounds when they are round', () {
      final ticks = ticksWithin(0, 100);
      expect(ticks.first, 0);
      expect(ticks.last, 100);
    });

    test('has no floating point drift', () {
      final ticks = ticksWithin(0, 1, targetTickCount: 11);
      expect(ticks, contains(0.3));
      expect(ticks, contains(0.7));
    });

    test('degenerate domain yields a single tick', () {
      expect(ticksWithin(5, 5), [5]);
    });
  });

  group('formatTickLabel', () {
    test('trims trailing zeros', () {
      expect(formatTickLabel(20, 20), '20');
      expect(formatTickLabel(2.5, 2.5), '2.5');
      expect(formatTickLabel(5, 2.5), '5');
    });

    test('compacts large magnitudes', () {
      expect(formatTickLabel(1500000, 500000), '1.5M');
      expect(formatTickLabel(2000000000, 1000000000), '2B');
      expect(formatTickLabel(12000, 4000), '12k');
    });

    test('normalizes negative zero', () {
      expect(formatTickLabel(0, 0.5), '0');
      expect(formatTickLabel(-0.0, 0.5), '0');
    });

    test('handles negatives', () {
      expect(formatTickLabel(-25000, 5000), '-25k');
      expect(formatTickLabel(-2.5, 2.5), '-2.5');
    });
  });

  group('NumericScale', () {
    test('normalizes linearly', () {
      const scale = NumericScale(min: 0, max: 100);
      expect(scale.normalize(0), 0);
      expect(scale.normalize(50), 0.5);
      expect(scale.normalize(100), 1);
      expect(scale.normalize(150), 1.5); // Out-of-domain maps outside [0,1].
    });

    test('fromExtent nices the domain by default', () {
      final scale = NumericScale.fromExtent(3, 97);
      expect(scale.min, 0);
      expect(scale.max, 100);
    });

    test('fromExtent keeps exact extent when nice is false', () {
      final scale = NumericScale.fromExtent(3, 97, nice: false);
      expect(scale.min, 3);
      expect(scale.max, 97);
    });

    test('overrides pin bounds', () {
      final scale =
          NumericScale.fromExtent(3, 97, minOverride: 0, maxOverride: 200);
      expect(scale.min, 0);
      expect(scale.max, 200);
    });

    test('repairs degenerate extents', () {
      final scale = NumericScale.fromExtent(5, 5);
      expect(scale.max, greaterThan(scale.min));
      final broken = NumericScale.fromExtent(double.nan, double.nan);
      expect(broken.max, greaterThan(broken.min));
    });

    test('value semantics', () {
      const a = NumericScale(min: 0, max: 10);
      const b = NumericScale(min: 0, max: 10);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(max: 20), const NumericScale(min: 0, max: 20));
    });
  });
}
