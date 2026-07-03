import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';
import 'package:nichart/src/core/chart_layers.dart';

void main() {
  group('lttbDownsample', () {
    test('is the identity below the threshold', () {
      final points = [for (var i = 0; i < 100; i++) Offset(i * 1.0, i * 2.0)];
      expect(identical(lttbDownsample(points, 100), points), isTrue);
      expect(identical(lttbDownsample(points, 500), points), isTrue);
      expect(identical(lttbDownsample(points, 2), points), isTrue);
    });

    test('keeps endpoints and hits the requested length', () {
      final points = [
        for (var i = 0; i < 5000; i++)
          Offset(i * 1.0, math.sin(i / 50) * 100),
      ];
      final sampled = lttbDownsample(points, 300);
      expect(sampled.length, 300);
      expect(sampled.first, points.first);
      expect(sampled.last, points.last);
    });

    test('preserves x order', () {
      final points = [
        for (var i = 0; i < 10000; i++)
          Offset(i * 1.0, ((i * 37) % 89) * 1.0),
      ];
      final sampled = lttbDownsample(points, 500);
      for (var i = 1; i < sampled.length; i++) {
        expect(sampled[i].dx, greaterThan(sampled[i - 1].dx));
      }
    });

    test('survives a single-point spike', () {
      final points = [
        for (var i = 0; i < 10000; i++)
          Offset(i * 1.0, i == 5000 ? 100000.0 : math.sin(i / 100) * 10),
      ];
      final sampled = lttbDownsample(points, 400);
      expect(
        sampled.any((p) => p.dy == 100000.0),
        isTrue,
        reason: 'LTTB must keep the extreme spike',
      );
    });
  });

  group('Downsampling', () {
    test('auto scales with plot width, floored at 256', () {
      const auto = Downsampling.auto();
      expect(auto.thresholdFor(600), 1200);
      expect(auto.thresholdFor(50), 256);
    });

    test('none disables, fixed pins', () {
      expect(const Downsampling.none().thresholdFor(600), isNull);
      expect(const Downsampling.fixed(2000).thresholdFor(600), 2000);
      expect(const Downsampling.fixed(1).thresholdFor(600), 3);
    });

    test('value semantics', () {
      expect(const Downsampling.auto(), const Downsampling.auto());
      expect(const Downsampling.fixed(100), const Downsampling.fixed(100));
      expect(const Downsampling.auto(),
          isNot(const Downsampling.none()));
    });
  });

  group('large series', () {
    List<DataPoint> bigData(int n) => [
          for (var i = 0; i < n; i++)
            DataPoint(i.toDouble(), ((i * 37) % 997) * 1.0),
        ];

    testWidgets('20k-point line renders with auto downsampling',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Chart(
                series: [LineSeries<DataPoint>(data: bigData(20000))],
                animation: const ChartAnimation.none(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('20k-point line renders with downsampling off',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Chart(
                series: [
                  LineSeries<DataPoint>(
                    data: bigData(20000),
                    downsampling: const Downsampling.none(),
                    style: const LineStyle(
                      interpolation: LineInterpolation.linear,
                    ),
                  ),
                ],
                animation: const ChartAnimation.none(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('5k-point scatter renders via raw point batches',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Chart(
                series: [
                  ScatterSeries<DataPoint>(
                    data: [
                      for (var i = 0; i < 5000; i++)
                        DataPoint((i % 100) * 1.0, (i * 31 % 89) * 1.0),
                    ],
                  ),
                ],
                animation: const ChartAnimation.none(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('layered repaint', () {
    testWidgets('moving the crosshair repaints ONLY the interaction layer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 400,
                child: Chart(
                  series: [
                    LineSeries<DataPoint>(
                      data: const [
                        DataPoint(0, 10),
                        DataPoint(1, 30),
                        DataPoint(2, 20),
                        DataPoint(3, 50),
                        DataPoint(4, 40),
                      ],
                    ),
                  ],
                  animation: const ChartAnimation.none(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backgroundLayer = tester.renderObject(
        find.byWidgetPredicate(
          (w) => w is ChartLayerWidget && w.kind == ChartLayerKind.background,
        ),
      );
      final dataLayer = tester.renderObject(
        find.byWidgetPredicate(
          (w) => w is ChartLayerWidget && w.kind == ChartLayerKind.data,
        ),
      );
      final interactionLayer =
          tester.renderObject(find.byType(ChartInteractionWidget));

      // All three are compositor repaint boundaries.
      expect(backgroundLayer.isRepaintBoundary, isTrue);
      expect(dataLayer.isRepaintBoundary, isTrue);
      expect(interactionLayer.isRepaintBoundary, isTrue);

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final center = tester.getCenter(find.byType(Chart));
      await gesture.moveTo(center);
      await tester.pump();

      // Move the crosshair to a different data point: the hover event is
      // dispatched synchronously, so the dirty flags are observable before
      // the next pump.
      await gesture.moveTo(center + const Offset(80, 0));
      expect(interactionLayer.debugNeedsPaint, isTrue,
          reason: 'crosshair move must repaint the interaction layer');
      expect(dataLayer.debugNeedsPaint, isFalse,
          reason: 'crosshair move must NOT repaint the series');
      expect(backgroundLayer.debugNeedsPaint, isFalse,
          reason: 'crosshair move must NOT repaint the grid');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
