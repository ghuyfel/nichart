import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nichart/nichart.dart';

const Key _boundaryKey = Key('m6-golden');

Widget _host(
  Widget child, {
  required Brightness brightness,
  Size size = const Size(400, 400),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B7CFA),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: size.width,
            height: size.height,
            color: brightness == Brightness.dark
                ? const Color(0xFF141218)
                : Colors.white,
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

List<CategoryPoint> get _shares => const [
      CategoryPoint('Direct', 44),
      CategoryPoint('Search', 31),
      CategoryPoint('Referral', 15),
      CategoryPoint('Other', 10),
    ];

const _sparkValues = [
  12.0,
  18.0,
  9.0,
  24.0,
  21.0,
  33.0,
  29.0,
  41.0,
  35.0,
  48.0,
];

void main() {
  group('donut', () {
    testWidgets('renders with only CategoryPoint data', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [DonutSeries<CategoryPoint>(data: _shares)],
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts custom types via accessors', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              DonutSeries<({String name, int users})>(
                data: const [
                  (name: 'iOS', users: 60),
                  (name: 'Android', users: 40),
                ],
                categoryAccessor: (d) => d.name,
                yAccessor: (d) => d.users.toDouble(),
              ),
            ],
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('sweeps in without errors mid-entrance', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(series: [DonutSeries<CategoryPoint>(data: _shares)]),
          brightness: Brightness.light,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250)); // Mid-sweep.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('morphs when segment values change', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(series: [DonutSeries<CategoryPoint>(data: _shares)]),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              DonutSeries<CategoryPoint>(
                data: const [
                  CategoryPoint('Direct', 20),
                  CategoryPoint('Search', 55),
                  CategoryPoint('Referral', 25),
                ],
              ),
            ],
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200)); // Mid-morph.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('DonutChart shows the center widget', (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            data: _shares,
            center: const Text('84%'),
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('84%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('oversized center content scales down to fit the hole',
        (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            data: _shares,
            // Far wider than the cutout hole.
            center: const Text(
              '1,234,567 visits',
              style: TextStyle(fontSize: 64),
              maxLines: 1,
            ),
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Hole geometry for a 368×368 box: outer (368-8)/2 = 180,
      // inner 180 × 0.72 = 129.6, inscribed side ≈ 168.6. getRect applies
      // the FittedBox scale transform, unlike getSize.
      final rect = tester.getRect(find.text('1,234,567 visits'));
      expect(rect.width, lessThanOrEqualTo(169));
    });

    testWidgets('DonutStyle.radius shrinks the ring', (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            data: _shares,
            style: const DonutStyle(radius: 80),
            center: const Text('84%'),
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        const DonutStyle(radius: 80),
        isNot(const DonutStyle()),
      );
    });

    testWidgets('golden — donut light', (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            data: _shares,
            center: const Text('84%', style: TextStyle(fontSize: 32)),
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_boundaryKey),
        matchesGoldenFile('goldens/donut_light.png'),
      );
    }, tags: 'golden');

    testWidgets('golden — donut dark', (tester) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            data: _shares,
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_boundaryKey),
        matchesGoldenFile('goldens/donut_dark.png'),
      );
    }, tags: 'golden');

    testWidgets('golden — pie (cutout 0) light', (tester) async {
      await tester.pumpWidget(
        _host(
          Chart(
            series: [
              DonutSeries<CategoryPoint>(
                data: _shares,
                style: const DonutStyle(cutout: 0),
              ),
            ],
            animation: const ChartAnimation.none(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_boundaryKey),
        matchesGoldenFile('goldens/pie_light.png'),
      );
    }, tags: 'golden');
  });

  group('sparkline', () {
    testWidgets('gets a default size under unbounded constraints',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [Sparkline(data: _sparkValues)],
            ),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(Sparkline));
      expect(box.size.width, 160);
      expect(box.size.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty and single-value data safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 160,
                  height: 40,
                  child: Sparkline(data: []),
                ),
                SizedBox(
                  width: 160,
                  height: 40,
                  child: Sparkline(data: [5]),
                ),
                SizedBox(
                  width: 160,
                  height: 40,
                  child: Sparkline.bars(data: [5]),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('golden — line and bars, light', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 56,
                child: Sparkline(data: _sparkValues),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 240,
                height: 56,
                child: Sparkline.bars(data: _sparkValues),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 240,
                height: 56,
                child: Sparkline.bars(data: _sparkValues, emphasizeLast: true),
              ),
            ],
          ),
          brightness: Brightness.light,
          size: const Size(320, 320),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_boundaryKey),
        matchesGoldenFile('goldens/sparklines_light.png'),
      );
    }, tags: 'golden');

    testWidgets('golden — line and bars, dark', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 56,
                child: Sparkline(data: _sparkValues),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 240,
                height: 56,
                child: Sparkline.bars(data: _sparkValues, emphasizeLast: true),
              ),
            ],
          ),
          brightness: Brightness.dark,
          size: const Size(320, 240),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_boundaryKey),
        matchesGoldenFile('goldens/sparklines_dark.png'),
      );
    }, tags: 'golden');
  });
}
