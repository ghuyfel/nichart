import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

Widget _host(Widget chart, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 600, height: 400, child: chart),
        ),
      ),
    ),
  );
}

List<DataPoint> get _dataA => const [
      DataPoint(0, 10),
      DataPoint(1, 30),
      DataPoint(2, 20),
      DataPoint(3, 40),
    ];

List<DataPoint> get _dataB => const [
      DataPoint(0, 40),
      DataPoint(1, 5),
      DataPoint(2, 35),
      DataPoint(3, 15),
      DataPoint(4, 25),
    ];

void main() {
  testWidgets('entrance animation runs and settles', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _dataA)));
    // Mid-entrance frames paint without errors.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data change morphs old → new', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _dataA)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(Chart.line(data: _dataB)));
    // A morph is running…
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    // …and settles cleanly with no timers left behind.
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interrupted morph continues without errors', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _dataA)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(Chart.line(data: _dataB)));
    await tester.pump(const Duration(milliseconds: 150)); // Mid-morph…
    await tester.pumpWidget(_host(Chart.line(data: _dataA))); // …interrupt.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('morph handles point count changes both ways', (tester) async {
    await tester.pumpWidget(_host(Chart.line(data: _dataA))); // 4 points
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(Chart.line(data: _dataB))); // grow to 5
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(Chart.line(data: _dataA))); // shrink to 4
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bars morph on data change', (tester) async {
    Widget bars(List<CategoryPoint> data) => _host(
          Chart(series: [BarSeries<CategoryPoint>(data: data)]),
        );
    await tester.pumpWidget(bars(const [
      CategoryPoint('Mon', 12),
      CategoryPoint('Tue', 18),
      CategoryPoint('Wed', 9),
    ]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(bars(const [
      CategoryPoint('Mon', 4),
      CategoryPoint('Tue', 22),
      CategoryPoint('Wed', 15),
      CategoryPoint('Thu', 7), // New category grows in.
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartAnimation.none renders settled immediately',
      (tester) async {
    await tester.pumpWidget(_host(
      Chart.line(data: _dataA, animation: const ChartAnimation.none()),
    ));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_host(
      Chart.line(data: _dataB, animation: const ChartAnimation.none()),
    ));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion disables entrance and morphing',
      (tester) async {
    await tester.pumpWidget(
      _host(Chart.line(data: _dataA), disableAnimations: true),
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      _host(Chart.line(data: _dataB), disableAnimations: true),
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  test('ChartAnimation value semantics', () {
    expect(const ChartAnimation(), const ChartAnimation());
    expect(const ChartAnimation.none(), const ChartAnimation.none());
    expect(const ChartAnimation(), isNot(const ChartAnimation.none()));
    expect(const ChartAnimation.none().entrance, isFalse);
    expect(const ChartAnimation.none().morph, isFalse);
  });
}
