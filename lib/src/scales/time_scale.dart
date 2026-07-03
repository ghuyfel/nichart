import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'scale.dart';
import 'tick_generator.dart';

/// Calendar granularity of generated time ticks — drives label formatting.
enum TimeGranularity {
  /// Ticks land on second boundaries (`14:30:05`).
  second,

  /// Ticks land on minute boundaries (`14:30`).
  minute,

  /// Ticks land on hour boundaries (`14:00`; midnight shows `Mar 5`).
  hour,

  /// Ticks land on day boundaries (`Mar 5`).
  day,

  /// Ticks land on month starts (`Mar`; January shows the year).
  month,

  /// Ticks land on year starts (`2026`).
  year,
}

/// The result of [timeTicks]: tick instants plus the granularity that
/// produced them (needed to format labels consistently).
typedef TimeTicks = ({List<DateTime> ticks, TimeGranularity granularity});

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A continuous scale over a [DateTime] domain.
///
/// Positioning maps linearly over milliseconds since epoch; tick generation
/// is calendar-aware ([timeTicks]) so ticks land on round instants — whole
/// minutes, midnights, month starts — instead of arbitrary millisecond
/// multiples.
@immutable
final class TimeScale extends Scale<DateTime> {
  /// Creates a scale spanning `[min, max]`.
  TimeScale({required this.min, required this.max})
      : assert(!max.isBefore(min), 'max must not be before min');

  /// Lower domain bound.
  final DateTime min;

  /// Upper domain bound.
  final DateTime max;

  @override
  double normalize(DateTime value) {
    final total = max.millisecondsSinceEpoch - min.millisecondsSinceEpoch;
    if (total == 0) return 0.5;
    return (value.millisecondsSinceEpoch - min.millisecondsSinceEpoch) / total;
  }

  /// Calendar-aware ticks inside the domain. See [timeTicks].
  TimeTicks ticks({int targetTickCount = 6}) =>
      timeTicks(min, max, targetTickCount: targetTickCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeScale && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'TimeScale($min → $max)';
}

// Candidate steps: (granularity, amount, approximate milliseconds).
const List<(TimeGranularity, int, int)> _steps = <(TimeGranularity, int, int)>[
  (TimeGranularity.second, 1, 1000),
  (TimeGranularity.second, 5, 5000),
  (TimeGranularity.second, 15, 15000),
  (TimeGranularity.second, 30, 30000),
  (TimeGranularity.minute, 1, 60000),
  (TimeGranularity.minute, 2, 120000),
  (TimeGranularity.minute, 5, 300000),
  (TimeGranularity.minute, 15, 900000),
  (TimeGranularity.minute, 30, 1800000),
  (TimeGranularity.hour, 1, 3600000),
  (TimeGranularity.hour, 3, 10800000),
  (TimeGranularity.hour, 6, 21600000),
  (TimeGranularity.hour, 12, 43200000),
  (TimeGranularity.day, 1, 86400000),
  (TimeGranularity.day, 2, 172800000),
  (TimeGranularity.day, 7, 604800000),
  (TimeGranularity.day, 14, 1209600000),
  (TimeGranularity.month, 1, 2629800000),
  (TimeGranularity.month, 3, 7889400000),
  (TimeGranularity.month, 6, 15778800000),
  (TimeGranularity.year, 1, 31557600000),
];

/// Generates calendar-aligned ticks inside `[min, max]`.
///
/// Picks the smallest step (5 s, 15 min, 6 h, 1 day, 3 months, …) that
/// yields at most roughly [targetTickCount] ticks, then walks calendar
/// boundaries in local time — so daily ticks land on midnight and monthly
/// ticks on the 1st, even across DST changes.
///
/// ```dart
/// timeTicks(DateTime(2026, 3, 1), DateTime(2026, 3, 8))
/// // ticks: Mar 2, Mar 3, ... (midnights), granularity: day
/// ```
TimeTicks timeTicks(DateTime min, DateTime max, {int targetTickCount = 6}) {
  if (!min.isBefore(max)) {
    return (ticks: <DateTime>[min], granularity: TimeGranularity.day);
  }
  final target = math.max(2, targetTickCount);
  final spanMs = max.millisecondsSinceEpoch - min.millisecondsSinceEpoch;

  var granularity = TimeGranularity.year;
  var amount = 1;
  var found = false;
  for (final (g, a, ms) in _steps) {
    if (spanMs / ms <= target) {
      granularity = g;
      amount = a;
      found = true;
      break;
    }
  }
  if (!found) {
    // Multi-year spans: nice year steps (1, 2, 5, 10, …).
    const yearMs = 31557600000;
    final spanYears = spanMs / yearMs;
    amount = math.max(1, niceNum(spanYears / (target - 1), round: true).ceil());
  }

  DateTime tickAt(int i) {
    switch (granularity) {
      case TimeGranularity.second:
        return DateTime(min.year, min.month, min.day, min.hour, min.minute,
            (min.second ~/ amount) * amount + amount * i);
      case TimeGranularity.minute:
        return DateTime(min.year, min.month, min.day, min.hour,
            (min.minute ~/ amount) * amount + amount * i);
      case TimeGranularity.hour:
        return DateTime(min.year, min.month, min.day,
            (min.hour ~/ amount) * amount + amount * i);
      case TimeGranularity.day:
        return DateTime(min.year, min.month, min.day + amount * i);
      case TimeGranularity.month:
        return DateTime(
            min.year, ((min.month - 1) ~/ amount) * amount + 1 + amount * i);
      case TimeGranularity.year:
        return DateTime((min.year ~/ amount) * amount + amount * i);
    }
  }

  final ticks = <DateTime>[];
  for (var i = 0; i < 1000; i++) {
    final t = tickAt(i);
    if (t.isAfter(max)) break;
    if (!t.isBefore(min)) ticks.add(t);
  }
  if (ticks.isEmpty) ticks.add(min);
  return (ticks: ticks, granularity: granularity);
}

/// Formats a time tick for display, matched to the tick [granularity]
/// (English month abbreviations, 24-hour clock, no locale dependency).
///
/// Context-boundary ticks promote themselves: midnight shows the date
/// instead of `00:00`, and January shows the year instead of `Jan`.
String formatTimeTick(DateTime tick, TimeGranularity granularity) {
  switch (granularity) {
    case TimeGranularity.second:
      return '${_two(tick.hour)}:${_two(tick.minute)}:${_two(tick.second)}';
    case TimeGranularity.minute:
    case TimeGranularity.hour:
      if (tick.hour == 0 && tick.minute == 0) {
        return '${_months[tick.month - 1]} ${tick.day}';
      }
      return '${_two(tick.hour)}:${_two(tick.minute)}';
    case TimeGranularity.day:
      return '${_months[tick.month - 1]} ${tick.day}';
    case TimeGranularity.month:
      return tick.month == 1 ? '${tick.year}' : _months[tick.month - 1];
    case TimeGranularity.year:
      return '${tick.year}';
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
