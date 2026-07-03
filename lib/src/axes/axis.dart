import 'package:meta/meta.dart';

/// Configuration for one chart axis.
///
/// The hierarchy is sealed so the renderer can pattern-match exhaustively.
/// All parameters are optional — an axis renders beautifully with defaults.
sealed class ChartAxis {
  /// Const constructor for subclasses.
  const ChartAxis({this.label, this.tickCount});

  /// Optional axis title, drawn along the axis in the theme's
  /// `axisLabelStyle`.
  final String? label;

  /// Desired number of ticks. When null the chart picks a count that fits
  /// the available space; the exact count may vary so ticks land on round
  /// values.
  final int? tickCount;
}

/// A continuous numeric axis.
///
/// ```dart
/// Chart(
///   axes: ChartAxes.cartesian(
///     y: NumericAxis(label: 'Users', min: 0),
///   ),
///   series: [LineSeries(data: points)],
/// )
/// ```
final class NumericAxis extends ChartAxis {
  /// Creates a numeric axis. All parameters are optional.
  const NumericAxis({
    super.label,
    super.tickCount,
    this.min,
    this.max,
    this.tickFormatter,
  });

  /// Pins the lower domain bound. When null the bound derives from data.
  final double? min;

  /// Pins the upper domain bound. When null the bound derives from data.
  final double? max;

  /// Custom tick label formatter. Defaults to a compact formatter
  /// (`1.5M`, `12k`, decimals matched to the tick step).
  final String Function(double value)? tickFormatter;
}

/// A time axis over a [DateTime] domain.
///
/// Ticks are calendar-aware — they land on whole minutes, midnights, month
/// starts — and labels adapt to the tick granularity (`14:30`, `Mar 5`,
/// `2026`). Data maps to this axis as milliseconds since epoch, which is
/// what the built-in `TimePoint` accessor produces.
///
/// ```dart
/// Chart(
///   axes: const ChartAxes.cartesian(x: TimeAxis()),
///   series: [LineSeries(data: timePoints)],
/// )
/// ```
final class TimeAxis extends ChartAxis {
  /// Creates a time axis. All parameters are optional.
  const TimeAxis({
    super.label,
    super.tickCount,
    this.min,
    this.max,
    this.tickFormatter,
  });

  /// Pins the earliest visible instant. When null it derives from data.
  final DateTime? min;

  /// Pins the latest visible instant. When null it derives from data.
  final DateTime? max;

  /// Custom tick label formatter. Defaults to a granularity-aware formatter
  /// (see `formatTimeTick`).
  final String Function(DateTime value)? tickFormatter;
}

/// A categorical (band) axis — one equal-width band per category.
///
/// Charts substitute this axis automatically when the x axis is left at its
/// default and the data is categorical (`CategoryPoint` or a series with a
/// `categoryAccessor`), so bar charts need zero axis configuration:
///
/// ```dart
/// Chart(series: [BarSeries(data: weekCounts)]) // CategoryAxis inferred
/// ```
final class CategoryAxis extends ChartAxis {
  /// Creates a category axis.
  const CategoryAxis({super.label, this.categories});

  /// Explicit category order. When null, categories appear in the order
  /// they are first encountered across all series. Data categories missing
  /// from this list are appended at the end.
  final List<String>? categories;
}

/// The pair of axes for a cartesian chart.
@immutable
class ChartAxes {
  /// Creates a cartesian axis pair. Both axes default to fully automatic
  /// [NumericAxis] instances (with automatic category detection for
  /// categorical data — see [CategoryAxis]).
  const ChartAxes.cartesian({
    this.x = const NumericAxis(),
    this.y = const NumericAxis(),
  });

  /// The horizontal (domain) axis.
  final ChartAxis x;

  /// The vertical (measure) axis. Only [NumericAxis] is supported here in
  /// this version.
  final ChartAxis y;
}
