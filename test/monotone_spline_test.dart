import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/src/series/monotone_spline.dart';

/// Samples every Hermite segment densely and returns the interpolated y
/// values (50 samples per segment).
List<double> _sampleSpline(List<Offset> points) {
  final m = monotoneTangents(points);
  final samples = <double>[];
  for (var i = 0; i < points.length - 1; i++) {
    for (var s = 0; s <= 50; s++) {
      samples.add(hermiteY(points[i], points[i + 1], m[i], m[i + 1], s / 50));
    }
  }
  return samples;
}

void main() {
  group('monotoneTangents (Fritsch–Carlson)', () {
    test('no overshoot: every segment stays inside its endpoint bounds', () {
      final points = <Offset>[
        const Offset(0, 0),
        const Offset(1, 10),
        const Offset(2, 10.2), // Near-flat step — classic Catmull-Rom killer.
        const Offset(3, 50),
        const Offset(4, 49),
        const Offset(5, 100),
      ];
      final m = monotoneTangents(points);
      for (var i = 0; i < points.length - 1; i++) {
        final lo = math.min(points[i].dy, points[i + 1].dy) - 1e-9;
        final hi = math.max(points[i].dy, points[i + 1].dy) + 1e-9;
        for (var s = 0; s <= 100; s++) {
          final y = hermiteY(points[i], points[i + 1], m[i], m[i + 1], s / 100);
          expect(y, inInclusiveRange(lo, hi),
              reason: 'segment $i overshoots at t=${s / 100}');
        }
      }
    });

    test('monotone data yields a monotone curve', () {
      final points = <Offset>[
        for (var i = 0; i < 8; i++) Offset(i.toDouble(), i * i * 1.0),
      ];
      final samples = _sampleSpline(points);
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i] + 1e-9, greaterThanOrEqualTo(samples[i - 1]));
      }
    });

    test('flat segments stay exactly flat', () {
      final points = <Offset>[
        const Offset(0, 5),
        const Offset(1, 5),
        const Offset(2, 5),
        const Offset(3, 12),
      ];
      final m = monotoneTangents(points);
      // Both ends of each flat segment must have zero tangent.
      expect(m[0], 0);
      expect(m[1], 0);
      expect(m[2], 0);
      for (var s = 0; s <= 50; s++) {
        expect(hermiteY(points[0], points[1], m[0], m[1], s / 50),
            moreOrLessEquals(5));
        expect(hermiteY(points[1], points[2], m[1], m[2], s / 50),
            moreOrLessEquals(5));
      }
    });

    test('local extrema get zero tangents', () {
      final points = <Offset>[
        const Offset(0, 0),
        const Offset(1, 10), // Peak.
        const Offset(2, 0),
      ];
      final m = monotoneTangents(points);
      expect(m[1], 0);
    });

    test('edge cases: empty, single, pair', () {
      expect(monotoneTangents(const <Offset>[]), isEmpty);
      expect(monotoneTangents(const <Offset>[Offset(1, 2)]), [0]);
      final pair =
          monotoneTangents(const <Offset>[Offset(0, 0), Offset(2, 4)]);
      expect(pair, [2, 2]); // Both tangents equal the secant slope.
    });

    test('duplicate x values do not divide by zero', () {
      final m = monotoneTangents(
          const <Offset>[Offset(0, 0), Offset(0, 5), Offset(1, 6)]);
      expect(m.every((t) => t.isFinite), isTrue);
    });
  });

  group('paths', () {
    test('monotonePath visits all points', () {
      final points = <Offset>[
        const Offset(0, 0),
        const Offset(10, 5),
        const Offset(20, 2),
      ];
      final path = monotonePath(points);
      expect(path.contains(const Offset(0, 0)), isTrue);
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 20);
    });

    test('empty and single-point paths are safe', () {
      expect(monotonePath(const <Offset>[]).getBounds(), Rect.zero);
      expect(linearPath(const <Offset>[]).getBounds(), Rect.zero);
      expect(
        monotonePath(const <Offset>[Offset(3, 4)]).getBounds().topLeft,
        const Offset(3, 4),
      );
    });

    test('dashPath produces disjoint subpaths of the source length', () {
      final source = linearPath(
          const <Offset>[Offset(0, 0), Offset(100, 0)]);
      final dashed = dashPath(source, const <double>[6, 4]);
      var drawn = 0.0;
      for (final metric in dashed.computeMetrics()) {
        drawn += metric.length;
      }
      // 10 full on/off cycles of 6px on = 60px drawn.
      expect(drawn, moreOrLessEquals(60, epsilon: 1));
    });
  });
}
