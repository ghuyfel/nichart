import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

void main() {
  group('ChartTheme', () {
    test('light and dark differ and carry matching palettes', () {
      final light = ChartTheme.light();
      final dark = ChartTheme.dark();
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.palette, ChartPalettes.categoricalLight);
      expect(dark.palette, ChartPalettes.categoricalDark);
      expect(light.gridLineColor, isNot(dark.gridLineColor));
    });

    test('fromColorScheme follows scheme brightness', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: Brightness.dark,
      );
      final theme = ChartTheme.fromColorScheme(scheme);
      expect(theme.brightness, Brightness.dark);
      expect(theme.surfaceColor, scheme.surface);
    });

    test('value semantics and copyWith', () {
      final a = ChartTheme.light();
      final b = ChartTheme.light();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final custom = a.copyWith(gridLineWidth: 2);
      expect(custom.gridLineWidth, 2);
      expect(custom, isNot(a));
      expect(custom.palette, a.palette);
    });

    testWidgets('of() derives from ambient Theme brightness',
        (tester) async {
      late ChartTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              resolved = ChartTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.dark);
    });

    testWidgets('of() prefers an enclosing ChartThemeScope', (tester) async {
      final override = ChartTheme.light().copyWith(gridLineWidth: 3);
      late ChartTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: ChartThemeScope(
            theme: override,
            child: Builder(
              builder: (context) {
                resolved = ChartTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(resolved, override);
    });
  });

  group('Series accessors', () {
    test('DataPoint and TimePoint get default accessors', () {
      final line = LineSeries<DataPoint>(data: const [DataPoint(1, 2)]);
      expect(line.resolvePoints(), const [Offset(1, 2)]);

      final time = LineSeries<TimePoint>(
        data: [TimePoint(DateTime.fromMillisecondsSinceEpoch(1000), 7)],
      );
      expect(time.resolvePoints(), const [Offset(1000, 7)]);
    });

    test('custom types without accessors throw a helpful error', () {
      expect(
        () => LineSeries<String>(data: const ['a']),
        throwsArgumentError,
      );
    });

    test('custom accessors map domain models', () {
      final series = LineSeries<({int day, int count})>(
        data: const [(day: 1, count: 10), (day: 2, count: 20)],
        xAccessor: (d) => d.day.toDouble(),
        yAccessor: (d) => d.count.toDouble(),
      );
      expect(series.resolvePoints(), const [Offset(1, 10), Offset(2, 20)]);
    });
  });

  group('CoordinateSpace', () {
    test('maps domain to pixels with flipped y', () {
      const space = CoordinateSpace(
        plotArea: Rect.fromLTWH(10, 10, 100, 100),
        xScale: NumericScale(min: 0, max: 10),
        yScale: NumericScale(min: 0, max: 10),
      );
      expect(space.toPixel(const Offset(0, 0)), const Offset(10, 110));
      expect(space.toPixel(const Offset(10, 10)), const Offset(110, 10));
      expect(space.toPixel(const Offset(5, 5)), const Offset(60, 60));
    });
  });
}
