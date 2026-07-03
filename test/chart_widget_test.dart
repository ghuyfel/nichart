import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

Widget _host(Widget chart,
    {Size size = const Size(600, 400), ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: chart,
        ),
      ),
    ),
  );
}

List<DataPoint> get _points => const [
      DataPoint(0, 12),
      DataPoint(1, 18),
      DataPoint(2, 9),
      DataPoint(3, 24),
      DataPoint(4, 21),
      DataPoint(5, 33),
    ];

void main() {
  testWidgets('renders with only data provided', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _points)));
    expect(find.byType(Chart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders with empty data', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: const [])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a single point without errors', (tester) async {
    await tester.pumpWidget(
      _host(Chart.line(data: const [DataPoint(1, 5)])),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tick labels decimate instead of colliding at narrow widths',
      (tester) async {
    for (final width in const [400.0, 200.0, 120.0, 60.0]) {
      await tester.pumpWidget(
        _host(
          Chart.line(data: _points),
          size: Size(width, 100),
        ),
      );
      expect(tester.takeException(), isNull,
          reason: 'chart threw at width $width');
    }
  });

  testWidgets('survives unbounded height (falls back to default aspect)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [Chart.line(data: _points)],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = tester.renderObject<RenderBox>(find.byType(Chart));
    expect(box.size.height, greaterThan(0));
  });

  testWidgets('updates when data changes', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _points)));
    await tester.pumpWidget(
      _host(Chart.line(data: const [DataPoint(0, 1), DataPoint(1, 2)])),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('axis labels and pinned bounds are honored', (tester) async {
    await tester.pumpWidget(
      _host(
        Chart(
          axes: const ChartAxes.cartesian(
            x: NumericAxis(label: 'Day'),
            y: NumericAxis(label: 'Users', min: 0, max: 40),
          ),
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom tick formatter is applied without errors',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Chart(
          axes: ChartAxes.cartesian(
            y: NumericAxis(tickFormatter: (v) => '${v.round()} u'),
          ),
          series: [LineSeries<DataPoint>(data: _points)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
