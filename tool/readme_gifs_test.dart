// Generates the animated GIFs referenced by the README into doc/gifs/.
//
// Not part of the test suite (lives in tool/, so `flutter test` ignores
// it). Run explicitly after visual changes:
//
//   flutter test tool/readme_gifs_test.dart
//
// Frames are captured from the real widget pipeline (so the GIFs show
// exactly what the package renders) using the Roboto font from the
// Flutter SDK cache instead of the blocky test font, and encoded with
// package:image — no external tooling.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nichart/nichart.dart';

const Size _canvas = Size(640, 360);
const Key _boundaryKey = Key('gif-boundary');
const Duration _frame = Duration(milliseconds: 40); // 25 fps
const int _frameCs = 4; // GIF frame delay, centiseconds.

const _seed = Color(0xFF5B7CFA);

const _thisWeek = [
  DataPoint(0, 120),
  DataPoint(1, 180),
  DataPoint(2, 95),
  DataPoint(3, 240),
  DataPoint(4, 205),
  DataPoint(5, 330),
  DataPoint(6, 290),
  DataPoint(7, 410),
];

const _lastWeek = [
  DataPoint(0, 140),
  DataPoint(1, 130),
  DataPoint(2, 160),
  DataPoint(3, 150),
  DataPoint(4, 235),
  DataPoint(5, 260),
  DataPoint(6, 305),
  DataPoint(7, 300),
];

List<CategoryPoint> _bars(int generation) => [
      for (final (i, day)
          in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexed)
        CategoryPoint(day, 6 + ((i * 29 + generation * 41) % 31).toDouble()),
    ];

Future<void> _loadRoboto(WidgetTester tester) async {
  await tester.runAsync(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ??
        '${Platform.environment['USERPROFILE']}\\flutter';
    final fonts = Directory('$root\\bin\\cache\\artifacts\\material_fonts');
    final candidates = ['roboto-regular.ttf', 'roboto-medium.ttf'];
    for (final name in candidates) {
      final file = File('${fonts.path}\\$name');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return;
    }
    fail('Roboto not found under ${fonts.path}');
  });
}

/// A chart theme whose text actually uses Roboto — the chart's TextPainters
/// don't inherit the app font family, so it must be set on the theme.
ChartTheme _gifTheme() {
  final base = ChartTheme.fromColorScheme(
    ColorScheme.fromSeed(seedColor: _seed),
  );
  return base.copyWith(
    tickLabelStyle: base.tickLabelStyle.copyWith(fontFamily: 'Roboto'),
    axisLabelStyle: base.axisLabelStyle.copyWith(fontFamily: 'Roboto'),
    tooltipTextStyle: base.tooltipTextStyle.copyWith(fontFamily: 'Roboto'),
  );
}

Widget _host(Widget chart) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      fontFamily: 'Roboto',
    ),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: _canvas.width,
            height: _canvas.height,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
            child: chart,
          ),
        ),
      ),
    ),
  );
}

Future<img.Image> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  late img.Image frame;
  await tester.runAsync(() async {
    final uiImage = await boundary.toImage(pixelRatio: 1.25);
    final data = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame = img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: data!.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    );
    uiImage.dispose();
  });
  return frame;
}

Future<void> _writeGif(
  WidgetTester tester,
  String name,
  List<img.Image> frames, {
  int lastFrameCs = 160,
}) async {
  await tester.runAsync(() async {
    final encoder = img.GifEncoder(repeat: 0);
    for (var i = 0; i < frames.length; i++) {
      encoder.addFrame(
        frames[i],
        duration: i == frames.length - 1 ? lastFrameCs : _frameCs,
      );
    }
    final bytes = encoder.finish()!;
    File('doc/gifs/$name.gif')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    // Emitted so the runner log shows what was produced.
    // ignore: avoid_print
    print('doc/gifs/$name.gif — ${frames.length} frames, '
        '${(bytes.length / 1024).round()} KB');
  });
}

void main() {
  testWidgets(
    'generate README gifs',
    (tester) async {
      await _loadRoboto(tester);
      final theme = _gifTheme();

      // ---- hero.gif: entrance animation of the signature look. --------
      var frames = <img.Image>[];
      await tester.pumpWidget(
        _host(
          Chart(
            theme: theme,
            axes: const ChartAxes.cartesian(y: NumericAxis(min: 0)),
            series: [
              LineSeries<DataPoint>(
                data: _thisWeek,
                style: const LineStyle(area: AreaFill.gradient()),
              ),
              LineSeries<DataPoint>(
                data: _lastWeek,
                style: const LineStyle.context(),
              ),
            ],
          ),
        ),
      );
      frames.add(await _capture(tester));
      for (var i = 0; i < 20; i++) {
        await tester.pump(_frame);
        frames.add(await _capture(tester));
      }
      await tester.pumpAndSettle();
      frames.add(await _capture(tester));
      await _writeGif(tester, 'hero', frames);

      // ---- morph.gif: bars re-shuffling through three datasets. -------
      frames = <img.Image>[];
      Widget barChart(int generation) => _host(
            Chart(
              theme: theme,
              series: [BarSeries<CategoryPoint>(data: _bars(generation))],
            ),
          );
      await tester.pumpWidget(barChart(0));
      await tester.pumpAndSettle();
      for (final generation in [1, 2, 0]) {
        for (var i = 0; i < 6; i++) {
          frames.add(await _capture(tester)); // Hold before each shuffle.
        }
        await tester.pumpWidget(barChart(generation));
        for (var i = 0; i < 15; i++) {
          await tester.pump(_frame);
          frames.add(await _capture(tester));
        }
        await tester.pumpAndSettle();
      }
      await _writeGif(tester, 'morph', frames, lastFrameCs: 120);

      // ---- interact.gif: crosshair + tooltip scrubbing. ----------------
      frames = <img.Image>[];
      await tester.pumpWidget(
        _host(
          Chart(
            theme: theme,
            series: [
              LineSeries<DataPoint>(data: _thisWeek, label: 'This week'),
              LineSeries<DataPoint>(
                data: _lastWeek,
                label: 'Last week',
                style: const LineStyle.context(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(_boundaryKey));
      final y = rect.center.dy + 20;
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      const steps = 26;
      for (var i = 0; i <= steps; i++) {
        final x = rect.left + 90 + (rect.width - 160) * i / steps;
        await gesture.moveTo(Offset(x, y));
        await tester.pump(_frame);
        frames.add(await _capture(tester));
      }
      await gesture.moveTo(Offset.zero); // Leave: tooltip fades for loop.
      await tester.pump(_frame);
      frames.add(await _capture(tester));
      await _writeGif(tester, 'interact', frames, lastFrameCs: 80);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
