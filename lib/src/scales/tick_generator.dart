import 'dart:math' as math;

/// A "nice" numeric domain: rounded bounds and the tick step that produced
/// them.
typedef NiceDomain = ({double min, double max, double step});

/// Rounds [range] to a "nice" number (1, 2, 5 × 10ⁿ).
///
/// With [round] true the result is the nice number closest to [range]
/// (used for tick steps); otherwise the smallest nice number ≥ [range]
/// (used for domain extents). Based on Heckbert's "Nice numbers for graph
/// labels" (Graphics Gems, 1990).
double niceNum(double range, {required bool round}) {
  if (range <= 0 || !range.isFinite) return 1;
  final exponent = (math.log(range) / math.ln10).floorToDouble();
  final magnitude = math.pow(10, exponent).toDouble();
  final fraction = range / magnitude;
  double niceFraction;
  if (round) {
    if (fraction < 1.5) {
      niceFraction = 1;
    } else if (fraction < 3) {
      niceFraction = 2;
    } else if (fraction < 7) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  } else {
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  }
  return niceFraction * magnitude;
}

/// Expands `[min, max]` to bounds that land on nice tick values.
///
/// Degenerate extents (`min == max`, reversed, or non-finite) are repaired to
/// a sensible non-empty domain so a chart always renders.
///
/// ```dart
/// niceDomain(3, 97) // (min: 0, max: 100, step: 20)
/// ```
NiceDomain niceDomain(double min, double max, {int targetTickCount = 5}) {
  var lo = min;
  var hi = max;
  if (!lo.isFinite || !hi.isFinite) {
    lo = 0;
    hi = 1;
  }
  if (lo > hi) {
    final t = lo;
    lo = hi;
    hi = t;
  }
  if (lo == hi) {
    final pad = lo == 0 ? 1.0 : lo.abs() * 0.1;
    lo -= pad;
    hi += pad;
  }
  final ticks = math.max(2, targetTickCount);
  final step = niceNum((hi - lo) / (ticks - 1), round: true);
  final niceMin = (lo / step).floorToDouble() * step;
  var niceMax = (hi / step).ceilToDouble() * step;
  if (niceMax == niceMin) niceMax = niceMin + step;
  return (min: niceMin, max: niceMax, step: step);
}

/// Generates nice tick values that fall inside `[min, max]` (inclusive,
/// with a small tolerance for floating-point drift).
///
/// Unlike [niceDomain] this never widens the domain — use it for axes whose
/// bounds must match the data exactly (for example the x axis of a line
/// chart).
List<double> ticksWithin(double min, double max, {int targetTickCount = 5}) {
  if (!min.isFinite || !max.isFinite || min >= max) {
    return <double>[if (min.isFinite) min];
  }
  final ticks = math.max(2, targetTickCount);
  final step = niceNum((max - min) / (ticks - 1), round: true);
  final first = (min / step).ceilToDouble() * step;
  final result = <double>[];
  final tolerance = step * 1e-6;
  for (var i = 0; ; i++) {
    // Recompute from `first` each iteration (instead of accumulating), then
    // round-trip through a fixed decimal representation so binary
    // floating-point dust (0.30000000000000004) never reaches callers.
    var t = first + i * step;
    t = double.parse(t.toStringAsFixed(12));
    if (t > max + tolerance) break;
    result.add(t);
  }
  return result;
}

/// Step used by [ticksWithin] for the given extent — exposed so label
/// formatting can match tick precision.
double tickStepFor(double min, double max, {int targetTickCount = 5}) {
  if (!min.isFinite || !max.isFinite || min >= max) return 1;
  return niceNum((max - min) / (math.max(2, targetTickCount) - 1), round: true);
}

/// Formats a tick [value] for display, using [step] to pick the number of
/// decimals and compacting large magnitudes (`12k`, `3.4M`, `1.2B`).
///
/// ```dart
/// formatTickLabel(1500000, 500000) // '1.5M'
/// formatTickLabel(2.5, 2.5)        // '2.5'
/// ```
String formatTickLabel(double value, double step) {
  final abs = value.abs();
  if (abs >= 1e9) return '${_fixed(value / 1e9, step / 1e9)}B';
  if (abs >= 1e6) return '${_fixed(value / 1e6, step / 1e6)}M';
  if (abs >= 1e4) return '${_fixed(value / 1e3, step / 1e3)}k';
  return _fixed(value, step);
}

String _fixed(double value, double step) {
  final v = value == 0 ? 0.0 : value; // Normalize -0.0.
  var s = v.toStringAsFixed(_decimalsFor(step));
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return s == '-0' ? '0' : s;
}

int _decimalsFor(double step) {
  if (step <= 0 || !step.isFinite) return 0;
  var decimals = 0;
  var s = step;
  while (decimals < 3 && (s - s.roundToDouble()).abs() > 1e-9) {
    s *= 10;
    decimals++;
  }
  return decimals;
}
