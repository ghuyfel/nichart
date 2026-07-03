import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

List<CategoryPoint> get _shares => const [
      CategoryPoint('Direct', 44),
      CategoryPoint('Search', 31),
      CategoryPoint('Referral', 15),
      CategoryPoint('Other', 10),
    ];

Widget _host(Widget child, {Size size = const Size(400, 400)}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  group('donut interaction', () {
    testWidgets('hovering a segment reports it and shows the tooltip halo',
        (tester) async {
      ChartHoverInfo? lastInfo;
      await tester.pumpWidget(
        _host(
          Chart(
            series: [DonutSeries<CategoryPoint>(data: _shares)],
            animation: const ChartAnimation.none(),
            interactions: [
              ChartTooltip(
                builder: (context, info) {
                  lastInfo = info;
                  return const SizedBox(
                    key: Key('donut-tip'),
                    width: 10,
                    height: 10,
                  );
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Segments start at 12 o'clock and sweep clockwise; 'Direct' (44%)
      // covers the right side. Probe mid-ring to the right of center.
      final center = tester.getCenter(find.byType(Chart));
      // 400×400 box → plot deflated by 4 → outer ~196, inner ~141;
      // mid-ring at radius ~168.
      await gesture.moveTo(center + const Offset(168, 0));
      await tester.pump();

      expect(find.byKey(const Key('donut-tip')), findsOneWidget);
      expect(lastInfo, isNotNull);
      expect(lastInfo!.xLabel, 'Direct');
      expect(lastInfo!.points.single.y, 44);

      // The hole is not interactive.
      await gesture.moveTo(center);
      await tester.pump();
      expect(find.byKey(const Key('donut-tip')), findsNothing);
    });

    testWidgets('built-in donut tooltip paints without errors', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [DonutSeries<CategoryPoint>(data: _shares)],
            animation: const ChartAnimation.none(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final center = tester.getCenter(find.byType(Chart));
      await gesture.moveTo(center + const Offset(-168, 0)); // Left side.
      await tester.pump();
      await gesture.moveTo(center + const Offset(0, -168)); // Top.
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('ChartLegend', () {
    testWidgets('lists series labels with palette colors', (tester) async {
      await tester.pumpWidget(
        _host(
          ChartLegend(
            series: [
              LineSeries<DataPoint>(
                data: const [DataPoint(0, 1)],
                label: 'This week',
              ),
              LineSeries<DataPoint>(
                data: const [DataPoint(0, 1)],
                label: 'Last week',
                style: const LineStyle.context(),
              ),
              LineSeries<DataPoint>(data: const [DataPoint(0, 1)]),
            ],
          ),
        ),
      );
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Last week'), findsOneWidget);
      expect(find.text('Series 3'), findsOneWidget);
    });

    testWidgets('lists donut segments', (tester) async {
      await tester.pumpWidget(
        _host(
          ChartLegend(
            series: [DonutSeries<CategoryPoint>(data: _shares)],
          ),
        ),
      );
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Referral'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('charts compose a screen-reader description', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              LineSeries<DataPoint>(
                data: const [DataPoint(0, 1)],
                label: 'Revenue',
              ),
              LineSeries<DataPoint>(
                data: const [DataPoint(0, 2)],
                label: 'Costs',
              ),
            ],
            animation: const ChartAnimation.none(),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Line chart: Revenue, Costs'),
        findsOneWidget,
      );
    });

    testWidgets('donut description includes segments and values',
        (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(data: _shares, animation: const ChartAnimation.none()),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Donut chart: Direct 44, Search 31, Referral 15, Other 10',
        ),
        findsOneWidget,
      );
    });

    testWidgets('semanticLabel overrides and sparklines are labeled',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              SizedBox(
                height: 100,
                child: Chart.line(
                  data: const [DataPoint(0, 1), DataPoint(1, 2)],
                  semanticLabel: 'Sales trend for March',
                  animation: const ChartAnimation.none(),
                ),
              ),
              const SizedBox(
                width: 160,
                height: 40,
                child: Sparkline(data: [1, 2, 3]),
              ),
              const SizedBox(
                width: 160,
                height: 40,
                child: Sparkline.bars(
                  data: [1, 2, 3],
                  semanticLabel: 'Weekly orders',
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Sales trend for March'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Sparkline'), findsOneWidget);
      expect(find.bySemanticsLabel('Weekly orders'), findsOneWidget);
    });
  });
}
