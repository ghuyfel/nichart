import 'package:meta/meta.dart';

/// An `(x, y)` pair on a numeric domain.
///
/// This is the default data type for cartesian series. Series constructed
/// with `List<DataPoint>` need no accessors:
///
/// ```dart
/// Chart.line(data: [DataPoint(0, 2), DataPoint(1, 5), DataPoint(2, 3)])
/// ```
@immutable
class DataPoint {
  /// Creates a point at ([x], [y]).
  const DataPoint(this.x, this.y);

  /// Position on the horizontal (domain) axis.
  final double x;

  /// Position on the vertical (measure) axis.
  final double y;

  /// Returns a copy of this point with the given fields replaced.
  DataPoint copyWith({double? x, double? y}) =>
      DataPoint(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'DataPoint($x, $y)';
}

/// A timestamped value, for time-series charts.
///
/// The [time] is mapped to the x axis (as milliseconds since epoch until a
/// dedicated `TimeScale` interprets it) and [value] to the y axis.
///
/// ```dart
/// LineSeries(data: [TimePoint(DateTime(2026, 1, 1), 42.0)])
/// ```
@immutable
class TimePoint {
  /// Creates a point at [time] with the given [value].
  const TimePoint(this.time, this.value);

  /// Position on the time (x) axis.
  final DateTime time;

  /// Position on the vertical (measure) axis.
  final double value;

  /// Returns a copy of this point with the given fields replaced.
  TimePoint copyWith({DateTime? time, double? value}) =>
      TimePoint(time ?? this.time, value ?? this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimePoint && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);

  @override
  String toString() => 'TimePoint($time, $value)';
}

/// A labeled value, for categorical charts (bars, donuts).
///
/// The [category] is mapped to a `CategoryScale` (milestone M2) and [value]
/// to the measure axis.
///
/// ```dart
/// BarSeries(data: [CategoryPoint('Mon', 12), CategoryPoint('Tue', 18)])
/// ```
@immutable
class CategoryPoint {
  /// Creates a point for [category] with the given [value].
  const CategoryPoint(this.category, this.value);

  /// The category label.
  final String category;

  /// The measured value.
  final double value;

  /// Returns a copy of this point with the given fields replaced.
  CategoryPoint copyWith({String? category, double? value}) =>
      CategoryPoint(category ?? this.category, value ?? this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryPoint &&
          other.category == category &&
          other.value == value;

  @override
  int get hashCode => Object.hash(category, value);

  @override
  String toString() => 'CategoryPoint($category, $value)';
}
