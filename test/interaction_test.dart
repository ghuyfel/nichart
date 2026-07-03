import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      DataPoint(1, 30),
      DataPoint(2, 20),
      DataPoint(3, 50),
      DataPoint(4, 40),
      DataPoint(5, 70),
      DataPoint(6, 60),
      DataPoint(7, 90),
    ];

void main() {
  group('ChartController', () {
    test('set, read back, reset, notify', () {
      final controller = ChartController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setXDomain(2, 5);
      expect(controller.xDomain, const DomainWindow(min: 2, max: 5));
      expect(notifications, 1);

      controller.setXDomain(2, 5); // No-op — same window.
      expect(notifications, 1);

      controller.setYDomain(0, 10);
      expect(controller.yDomain, const DomainWindow(min: 0, max: 10));
      expect(notifications, 2);

      controller.reset();
      expect(controller.xDomain, isNull);
      expect(controller.yDomain, isNull);
      expect(notifications, 3);

      controller.reset(); // No-op — already reset.
      expect(notifications, 3);
    });

    test('setXDomainTime maps to epoch milliseconds', () {
      final controller = ChartController();
      final min = DateTime(2026, 3, 1);
      final max = DateTime(2026, 3, 8);
      controller.setXDomainTime(min, max);
      expect(
        controller.xDomain,
        DomainWindow(
          min: min.millisecondsSinceEpoch.toDouble(),
          max: max.millisecondsSinceEpoch.toDouble(),
        ),
      );
    });
  });

  group('hover / crosshair', () {
    testWidgets('mouse hover shows the builder tooltip and exit hides it',
        (tester) async {
      const tooltipKey = Key('custom-tooltip');
      ChartHoverInfo? lastInfo;
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points, label: 'Users')],
            animation: const ChartAnimation.none(),
            interactions: [
              const Crosshair(),
              ChartTooltip(
                builder: (context, info) {
                  lastInfo = info;
                  return Container(
                    key: tooltipKey,
                    padding: const EdgeInsets.all(4),
                    color: const Color(0xFF222222),
                    child: Text('${info.points.length} series'),
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
      await gesture.moveTo(tester.getCenter(find.byType(Chart)));
      await tester.pump();

      expect(find.byKey(tooltipKey), findsOneWidget);
      expect(lastInfo, isNotNull);
      expect(lastInfo!.points, hasLength(1));
      expect(lastInfo!.points.first.seriesLabel, 'Users');
      // Center of an x∈[0,7] plot snaps to a mid-domain point.
      expect(lastInfo!.points.first.x, inInclusiveRange(2, 5));

      // Moving off the chart clears the hover.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(find.byKey(tooltipKey), findsNothing);
    });

    testWidgets('touch drag scrubs the crosshair when pan/zoom is off',
        (tester) async {
      const tooltipKey = Key('scrub-tooltip');
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: [
              const Crosshair(),
              ChartTooltip(
                builder: (context, info) =>
                    const SizedBox(key: tooltipKey, width: 10, height: 10),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(Chart));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(find.byKey(tooltipKey), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('long-press scrubs and releases', (tester) async {
      const tooltipKey = Key('longpress-tooltip');
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: [
              const Crosshair(),
              ChartTooltip(
                builder: (context, info) =>
                    const SizedBox(key: tooltipKey, width: 10, height: 10),
              ),
              const PanZoom(), // Drag pans, so scrubbing needs long-press.
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(Chart));
      final gesture = await tester.startGesture(center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.byKey(tooltipKey), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(find.byKey(tooltipKey), findsNothing);
    });
  });

  group('pan/zoom', () {
    testWidgets('controller domain moves the chart and drag pans it',
        (tester) async {
      final controller = ChartController();
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: const [PanZoom()],
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setXDomain(2, 5);
      await tester.pumpAndSettle();

      // Drag left: the window slides toward larger x.
      await tester.drag(find.byType(Chart), const Offset(-120, 0));
      await tester.pumpAndSettle();

      final window = controller.xDomain;
      expect(window, isNotNull);
      expect(window!.min, greaterThan(2));
      // Width preserved by a pure pan.
      expect(window.max - window.min, moreOrLessEquals(3, epsilon: 0.01));
      // Never pans past the data domain.
      expect(window.max, lessThanOrEqualTo(7));
    });

    testWidgets('double-tap resets the domain', (tester) async {
      final controller = ChartController();
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: const [PanZoom()],
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setXDomain(2, 5);
      await tester.pumpAndSettle();
      expect(controller.xDomain, isNotNull);

      final center = tester.getCenter(find.byType(Chart));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(controller.xDomain, isNull);
    });

    testWidgets('ctrl+scroll zooms in around the pointer', (tester) async {
      final controller = ChartController();
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: const [PanZoom()],
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(Chart));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);

      // Without the modifier nothing happens.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -240)));
      await tester.pumpAndSettle();
      expect(controller.xDomain, isNull);

      // With ctrl held the domain narrows.
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -240)));
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final window = controller.xDomain;
      expect(window, isNotNull);
      expect(window!.max - window.min, lessThan(7));
      expect(window.min, greaterThanOrEqualTo(0));
      expect(window.max, lessThanOrEqualTo(7));
    });

    testWidgets('pinch zoom narrows the window', (tester) async {
      final controller = ChartController();
      await tester.pumpWidget(
        _host(
          Chart(
            series: [LineSeries<DataPoint>(data: _points)],
            animation: const ChartAnimation.none(),
            interactions: const [PanZoom()],
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(Chart));
      final finger1 = await tester.startGesture(center - const Offset(40, 0));
      final finger2 = await tester.startGesture(center + const Offset(40, 0));
      await finger1.moveBy(const Offset(-60, 0));
      await finger2.moveBy(const Offset(60, 0));
      await tester.pump();
      await finger1.up();
      await finger2.up();
      await tester.pumpAndSettle();

      final window = controller.xDomain;
      expect(window, isNotNull);
      expect(window!.max - window.min, lessThan(7));
    });
  });

  group('goldens', () {
    testWidgets('crosshair, markers and tooltip — light', (tester) async {
      const boundaryKey = Key('interaction-golden');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B7CFA),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  width: _chartSize.width,
                  height: _chartSize.height,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Chart(
                    series: [
                      LineSeries<DataPoint>(data: _points, label: 'This week'),
                      LineSeries<DataPoint>(
                        label: 'Last week',
                        data: const [
                          DataPoint(0, 40),
                          DataPoint(1, 20),
                          DataPoint(2, 45),
                          DataPoint(3, 30),
                          DataPoint(4, 60),
                          DataPoint(5, 50),
                          DataPoint(6, 80),
                          DataPoint(7, 70),
                        ],
                        style: const LineStyle.context(),
                      ),
                    ],
                    animation: const ChartAnimation.none(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(Chart)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/interaction_tooltip_light.png'),
      );
    }, tags: 'golden');
  });
}
