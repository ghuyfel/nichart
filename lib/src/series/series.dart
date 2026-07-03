import 'dart:ui';

import '../data/data_point.dart';
import '../data/downsampling.dart';
import 'area_fill.dart';
import 'bar_style.dart';
import 'donut_style.dart';
import 'line_style.dart';
import 'scatter_style.dart';

/// Extracts a numeric axis value from a datum of type [T].
typedef ChartAccessor<T> = double Function(T datum);

/// Extracts a category label from a datum of type [T].
typedef CategoryAccessor<T> = String Function(T datum);

/// A dataset drawn on a chart.
///
/// The hierarchy is sealed: donut and future series types join in later
/// milestones without breaking changes. Series accept any element type
/// [T]; for the built-in [DataPoint], [TimePoint] and [CategoryPoint]
/// types the accessors are inferred, and for domain models you pass them
/// explicitly:
///
/// ```dart
/// LineSeries(
///   data: signups,
///   xAccessor: (s) => s.day.toDouble(),
///   yAccessor: (s) => s.count.toDouble(),
/// )
/// BarSeries(
///   data: sales,
///   categoryAccessor: (s) => s.region,
///   yAccessor: (s) => s.revenue,
/// )
/// ```
sealed class Series<T> {
  /// Base constructor: resolves default accessors for built-in point types.
  Series({
    required this.data,
    ChartAccessor<T>? xAccessor,
    ChartAccessor<T>? yAccessor,
    CategoryAccessor<T>? categoryAccessor,
    this.pointIdAccessor,
    this.id,
    this.label,
    this.color,
    this.downsampling = const Downsampling.auto(),
    this.interactive = true,
  })  : xAccessor = xAccessor ?? _inferX<T>(),
        categoryAccessor = categoryAccessor ?? _inferCategory<T>(),
        yAccessor = yAccessor ?? _requireY<T>();

  /// The data to draw, in x order for line-like series.
  final List<T> data;

  /// Maps a datum to its numeric x (domain) value. Null for purely
  /// categorical data — such series render on a [CategoryAxis]
  /// (substituted automatically for default axes).
  final ChartAccessor<T>? xAccessor;

  /// Maps a datum to its y (measure) value.
  final ChartAccessor<T> yAccessor;

  /// Maps a datum to its category, for categorical (band) x axes.
  /// Inferred for [CategoryPoint]; null otherwise unless provided.
  final CategoryAccessor<T>? categoryAccessor;

  /// Optional stable per-point identity for data-change morphing.
  ///
  /// When provided, morphing matches old and new points by this id instead
  /// of by list index — so inserting or removing points animates the
  /// survivors correctly instead of shifting everything by one. Points
  /// with an id that did not exist before appear at their final position.
  /// Bar segments always match by x position and donut segments by
  /// category label, so those series ignore this.
  final String Function(T datum)? pointIdAccessor;

  /// Stable identity for animation matching, emphasis targeting and color
  /// assignment across rebuilds. Defaults to the series' position in the
  /// `series` list.
  final String? id;

  /// Human-readable name, used by legends and tooltips.
  final String? label;

  /// Explicit series color. When null the theme palette assigns one by
  /// position, in fixed order.
  final Color? color;

  /// LTTB downsampling policy for line/area painting. Automatic by
  /// default: series beyond ~2× the plot width in points are reduced
  /// before painting, while hover/tooltips keep seeing the raw data.
  final Downsampling downsampling;

  /// Whether this series participates in hover: crosshair snapping,
  /// hover markers and tooltips. Set false for purely decorative series
  /// (visual overlays, guides) so they never steal the crosshair or add
  /// tooltip rows. Painting is unaffected.
  final bool interactive;

  /// Whether this series can resolve numeric x values.
  ///
  /// Prefer this over `xAccessor != null` when the series is held through
  /// an erased type (`Series<Object?>`): reading the function-typed
  /// [xAccessor] field through a supertype fails Dart's covariance check
  /// at runtime, while this boolean does not.
  bool get hasXAccessor => xAccessor != null;

  /// Whether this series can resolve category labels.
  ///
  /// See [hasXAccessor] for why this exists alongside [categoryAccessor].
  bool get hasCategoryAccessor => categoryAccessor != null;

  /// Resolves [data] through the numeric accessors into domain-space
  /// points (`dx` = x value, `dy` = y value).
  ///
  /// Throws [ArgumentError] when the series has no numeric x accessor —
  /// categorical data resolves via [resolveCategoryPoints] instead.
  List<Offset> resolvePoints() {
    final xa = xAccessor;
    if (xa == null) {
      throw ArgumentError(
        'Series over $T has no numeric xAccessor. Categorical data renders '
        'on a CategoryAxis (inferred automatically for default axes); for '
        'numeric or time axes pass xAccessor explicitly.',
      );
    }
    return <Offset>[
      for (final datum in data) Offset(xa(datum), yAccessor(datum)),
    ];
  }

  /// Resolves [data] through [yAccessor] into plain magnitudes (used by
  /// radial series, where there is no x).
  List<double> resolveValues() =>
      <double>[for (final datum in data) yAccessor(datum)];

  /// Resolves per-point morph identities, or null when [pointIdAccessor]
  /// is not set.
  ///
  /// A method rather than direct field access so callers holding a
  /// `Series<Object?>` don't trip Dart's function-field covariance check.
  List<String>? resolvePointIds() {
    final accessor = pointIdAccessor;
    if (accessor == null) return null;
    return <String>[for (final datum in data) accessor(datum)];
  }

  /// Resolves [data] into (category, y) pairs for categorical x axes.
  ///
  /// Throws [ArgumentError] when the series has no [categoryAccessor].
  List<(String, double)> resolveCategoryPoints() {
    final ca = categoryAccessor;
    if (ca == null) {
      throw ArgumentError(
        'Series over $T has no categoryAccessor, which a CategoryAxis '
        'requires. Pass categoryAccessor, or use CategoryPoint data.',
      );
    }
    return <(String, double)>[
      for (final datum in data) (ca(datum), yAccessor(datum)),
    ];
  }

  static ChartAccessor<T>? _inferX<T>() {
    if (T == DataPoint) {
      return (datum) => (datum as DataPoint).x;
    }
    if (T == TimePoint) {
      return (datum) =>
          (datum as TimePoint).time.millisecondsSinceEpoch.toDouble();
    }
    return null;
  }

  static CategoryAccessor<T>? _inferCategory<T>() {
    if (T == CategoryPoint) {
      return (datum) => (datum as CategoryPoint).category;
    }
    return null;
  }

  static ChartAccessor<T> _requireY<T>() {
    if (T == DataPoint) {
      return (datum) => (datum as DataPoint).y;
    }
    if (T == TimePoint) {
      return (datum) => (datum as TimePoint).value;
    }
    if (T == CategoryPoint) {
      return (datum) => (datum as CategoryPoint).value;
    }
    throw ArgumentError(
      'No default yAccessor for $T. Pass yAccessor explicitly, or use the '
      'built-in DataPoint/TimePoint/CategoryPoint types.',
    );
  }
}

/// A line series: points connected by a smooth monotone stroke.
///
/// ```dart
/// Chart(
///   series: [
///     LineSeries(data: thisPeriod),
///     LineSeries(data: lastPeriod, style: const LineStyle.context()),
///   ],
/// )
/// ```
final class LineSeries<T> extends Series<T> {
  /// Creates a line series over [data].
  LineSeries({
    required super.data,
    super.xAccessor,
    super.yAccessor,
    super.categoryAccessor,
    super.pointIdAccessor,
    super.id,
    super.label,
    super.color,
    super.downsampling,
    super.interactive,
    this.style = const LineStyle(),
  });

  /// Visual style of the stroke. Defaults to a 2 px monotone-smooth line.
  final LineStyle style;
}

/// A line series with the signature gradient fill below it.
///
/// Identical to a [LineSeries] whose style carries an [AreaFill]; provided
/// as its own type so the common case reads declaratively:
///
/// ```dart
/// Chart(series: [AreaSeries(data: points)])
/// ```
final class AreaSeries<T> extends Series<T> {
  /// Creates an area series over [data].
  AreaSeries({
    required super.data,
    super.xAccessor,
    super.yAccessor,
    super.categoryAccessor,
    super.pointIdAccessor,
    super.id,
    super.label,
    super.color,
    super.downsampling,
    super.interactive,
    this.style = const LineStyle(area: AreaFill.gradient()),
  });

  /// Visual style: stroke plus fill. Defaults to a 2 px monotone stroke
  /// over a gradient fill fading to the baseline.
  final LineStyle style;
}

/// A bar series. Renders on a [CategoryAxis] band per category (inferred
/// automatically for `CategoryPoint` data), or on numeric/time axes using
/// the smallest x gap as the band.
///
/// Multiple bar series share bands side by side ([BarArrangement.grouped])
/// or stack ([BarArrangement.stacked]).
///
/// ```dart
/// Chart(series: [BarSeries(data: weekCounts)])
/// ```
final class BarSeries<T> extends Series<T> {
  /// Creates a bar series over [data].
  BarSeries({
    required super.data,
    super.xAccessor,
    super.yAccessor,
    super.categoryAccessor,
    super.id,
    super.label,
    super.color,
    super.interactive,
    this.style = const BarStyle(),
    this.arrangement = BarArrangement.grouped,
    this.emphasizedIndex,
  });

  /// Visual style of the bars.
  final BarStyle style;

  /// How this series shares bands with other bar series. All bar series in
  /// a chart must agree.
  final BarArrangement arrangement;

  /// When set, the bar at this data index renders at full color and all
  /// other bars in this series are muted — the "highlight one bar"
  /// pattern.
  final int? emphasizedIndex;
}

/// A donut (or pie) series: one annular segment per datum, palette colors
/// assigned in display order.
///
/// Renders radially — a chart containing a [DonutSeries] draws no axes or
/// grid, and cannot mix in cartesian series. Segment magnitudes come from
/// the y accessor; labels (for legends/tooling) from the category
/// accessor. Both are inferred for [CategoryPoint] data:
///
/// ```dart
/// Chart(series: [DonutSeries(data: shares)])          // 72% cutout donut
/// DonutChart(data: shares, center: Text('84%'))       // with hero center
/// DonutSeries(data: shares, style: DonutStyle(cutout: 0))  // pie
/// ```
final class DonutSeries<T> extends Series<T> {
  /// Creates a donut series over [data].
  DonutSeries({
    required super.data,
    super.yAccessor,
    super.categoryAccessor,
    super.id,
    super.label,
    this.style = const DonutStyle(),
  });

  /// Visual style: cutout, segment gaps, corner radius, start angle.
  final DonutStyle style;
}

/// A scatter series: one circular marker per datum.
///
/// ```dart
/// Chart(series: [ScatterSeries(data: samples)])
/// ```
final class ScatterSeries<T> extends Series<T> {
  /// Creates a scatter series over [data].
  ScatterSeries({
    required super.data,
    super.xAccessor,
    super.yAccessor,
    super.categoryAccessor,
    super.pointIdAccessor,
    super.id,
    super.label,
    super.color,
    super.interactive,
    this.style = const ScatterStyle(),
  });

  /// Visual style of the markers.
  final ScatterStyle style;
}
