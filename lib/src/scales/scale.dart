import 'package:meta/meta.dart';

import 'tick_generator.dart';

/// Maps values from a data domain onto the unit interval `[0, 1]`.
///
/// Scales are pure domain→normalized mappings; converting the normalized
/// value to pixels is the job of `CoordinateSpace`, which knows the plot
/// rectangle. Concrete scales for time, category and log domains arrive in
/// later milestones without breaking this contract.
abstract class Scale<D> {
  /// Const constructor for subclasses.
  const Scale();

  /// Normalizes [value] to `[0, 1]` within this scale's domain.
  ///
  /// Values outside the domain map outside the unit interval; callers clip
  /// at the paint layer rather than here so lines can run off-plot cleanly.
  double normalize(D value);
}

/// A continuous linear scale over a `double` domain.
///
/// ```dart
/// final scale = NumericScale.fromExtent(3, 97); // nice → [0, 100]
/// scale.normalize(50); // 0.5
/// scale.ticks();       // [0, 20, 40, 60, 80, 100]
/// ```
@immutable
final class NumericScale extends Scale<double> {
  /// Creates a scale with an explicit `[min, max]` domain.
  const NumericScale({required this.min, required this.max})
      : assert(min <= max, 'min must be ≤ max');

  /// Creates a scale from a raw data extent.
  ///
  /// With [nice] true (the default) the domain is expanded outward to
  /// round tick boundaries — the right choice for measure (y) axes. Pass
  /// false to keep the exact data extent — the right choice for domain (x)
  /// axes. [minOverride] / [maxOverride] pin either bound regardless of
  /// [nice]. Degenerate extents are repaired so a chart always renders.
  factory NumericScale.fromExtent(
    double dataMin,
    double dataMax, {
    bool nice = true,
    int targetTickCount = 5,
    double? minOverride,
    double? maxOverride,
  }) {
    final domain =
        niceDomain(dataMin, dataMax, targetTickCount: targetTickCount);
    var lo = nice ? domain.min : dataMin;
    var hi = nice ? domain.max : dataMax;
    if (!lo.isFinite || !hi.isFinite || lo == hi) {
      lo = domain.min;
      hi = domain.max;
    }
    lo = minOverride ?? lo;
    hi = maxOverride ?? hi;
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    if (lo == hi) hi = lo + 1;
    return NumericScale(min: lo, max: hi);
  }

  /// Lower domain bound.
  final double min;

  /// Upper domain bound.
  final double max;

  /// The domain length (`max - min`).
  double get range => max - min;

  @override
  double normalize(double value) =>
      range == 0 ? 0.5 : (value - min) / range;

  /// Nice tick values inside the domain.
  ///
  /// Roughly [targetTickCount] ticks; the exact count varies so that ticks
  /// land on round numbers.
  List<double> ticks({int targetTickCount = 5}) =>
      ticksWithin(min, max, targetTickCount: targetTickCount);

  /// The tick step [ticks] would use — handy for matching label precision.
  double tickStep({int targetTickCount = 5}) =>
      tickStepFor(min, max, targetTickCount: targetTickCount);

  /// Returns a copy of this scale with the given bounds replaced.
  NumericScale copyWith({double? min, double? max}) =>
      NumericScale(min: min ?? this.min, max: max ?? this.max);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NumericScale && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'NumericScale($min → $max)';
}
