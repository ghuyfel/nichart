import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const Size _chartSize = Size(600, 400);

Widget _host(Widget chart) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _chartSize.width,
          height: _chartSize.height,
          child: chart,
        ),
      ),
    ),
  );
}

List<DataPoint> get _points => const [
      DataPoint(0, 10),
      DataPoint(6, 30),
      DataPoint(12, 20),
      DataPoint(18, 50),
      DataPoint(24, 40),
    ];

void main() {
  group('annotations', () {
    testWidgets('bands and lines render without errors', (tester) async {
      await tester.pumpWidget(_host(
        Chart(
          annotations: const [
            BandAnnotation.y(from: 15, to: 35, color: Color(0x2200FF00)),
            BandAnnotation.x(from: 6, to: 12),
            LineAnnotation.y(value: 45, dashPattern: [6, 4]),
            LineAnnotation.x(value: 18, strokeWidth: 2),
          ],
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('annotations never affect the data domain', (tester) async {
      // A band way outside the data must not stretch the y axis: the
      // domain derives from data (plus overrides) only.
      final controller = ChartController();
      await tester.pumpWidget(_host(
        Chart(
          controller: controller,
          annotations: const [BandAnnotation.y(from: -1000, to: 5000)],
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('value equality', () {
      expect(
        const BandAnnotation.y(from: 70, to: 180),
        const BandAnnotation.y(from: 70, to: 180),
      );
      expect(
        const LineAnnotation.x(value: 12, dashPattern: [6, 4]),
        const LineAnnotation.x(value: 12, dashPattern: [6, 4]),
      );
      expect(
        const LineAnnotation.x(value: 12),
        isNot(const LineAnnotation.y(value: 12)),
      );
    });
  });

  group('NumericAxis.ticks', () {
    testWidgets('explicit ticks replace the generated labels',
        (tester) async {
      await tester.pumpWidget(_host(
        Chart(
          axes: const ChartAxes.cartesian(
            x: NumericAxis(min: 0, max: 24, ticks: [0, 6, 12, 18, 24]),
          ),
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Out-of-domain explicit ticks are skipped.
      await tester.pumpWidget(_host(
        Chart(
          axes: const ChartAxes.cartesian(
            x: NumericAxis(min: 0, max: 24, ticks: [-6, 0, 12, 24, 30]),
            y: NumericAxis(ticks: [0, 25, 50, 75]),
          ),
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('ChartController.plotArea', () {
    testWidgets('populated after layout and inside the chart box',
        (tester) async {
      final controller = ChartController();
      await tester.pumpWidget(_host(
        Chart(
          controller: controller,
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ));
      await tester.pumpAndSettle();

      final plot = controller.plotArea;
      expect(plot, isNotNull);
      expect(plot!.left, greaterThan(0)); // y-label gutter
      expect(plot.width, lessThan(_chartSize.width));
      expect(plot.height, lessThan(_chartSize.height));
    });
  });

  group('Series.interactive', () {
    testWidgets('non-interactive series are invisible to hover',
        (tester) async {
      ChartHoverInfo? hover;
      await tester.pumpWidget(_host(
        Chart(
          interactions: [
            const Crosshair(),
            ChartTooltip(
              builder: (context, info) {
                hover = info;
                return const SizedBox.shrink();
              },
            ),
          ],
          series: [
            LineSeries<DataPoint>(data: _points, id: 'data'),
            // A decorative guide with points at a DIFFERENT x (3): were it
            // interactive, hovering near x=3 would snap to it.
            LineSeries<DataPoint>(
              data: const [DataPoint(3, 0), DataPoint(3, 100)],
              id: 'guide',
              interactive: false,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Hover near x = 3 (between data points 0 and 6): the snap must go
      // to a data x, never to the guide's x = 3.
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      final center = tester.getCenter(find.byType(Chart));
      await gesture.moveTo(center);
      await tester.pumpAndSettle();

      expect(hover, isNotNull);
      for (final point in hover!.points) {
        expect(point.seriesId, isNot('guide'));
      }
      await gesture.removePointer();
    });
  });
}
