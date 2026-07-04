import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const _points = [
  DataPoint(0, 10),
  DataPoint(1, 30),
  DataPoint(2, 20),
  DataPoint(3, 40),
  DataPoint(4, 25),
  DataPoint(5, 35),
  DataPoint(6, 15),
  DataPoint(7, 45),
];

void main() {
  testWidgets('builder tooltip stays inside the chart near the right edge',
      (tester) async {
    const tooltipKey = Key('tooltip');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: [
              const Crosshair(),
              ChartTooltip(
                builder: (context, info) => Container(
                  key: tooltipKey,
                  width: 160,
                  height: 48,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chartRect = tester.getRect(find.byType(Chart));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover near the right of the plot: the tooltip must flip/clamp
    // instead of running past the chart's right edge.
    await gesture
        .moveTo(Offset(chartRect.right - 40, chartRect.center.dy));
    await tester.pump();

    expect(find.byKey(tooltipKey), findsOneWidget);
    final tooltipRect = tester.getRect(find.byKey(tooltipKey));
    expect(tooltipRect.right, lessThanOrEqualTo(chartRect.right + 0.001));
    expect(tooltipRect.left, greaterThanOrEqualTo(chartRect.left - 0.001));

    // And near the top of the plot it never leaves the chart bounds
    // vertically either.
    await gesture.moveTo(Offset(chartRect.center.dx, chartRect.top + 40));
    await tester.pump();
    final topRect = tester.getRect(find.byKey(tooltipKey));
    expect(topRect.top, greaterThanOrEqualTo(chartRect.top - 0.001));
    expect(
      topRect.bottom,
      lessThanOrEqualTo(chartRect.bottom + 0.001),
    );

    await gesture.moveTo(Offset.zero);
    await tester.pump();
  });
}
