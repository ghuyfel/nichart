import 'package:flutter/foundation.dart';

/// A visible-domain window: `[min, max]` in domain units (numeric values,
/// epoch milliseconds for time axes).
@immutable
class DomainWindow {
  /// Creates a window spanning `[min, max]`.
  const DomainWindow({required this.min, required this.max})
      : assert(min <= max, 'min must be ≤ max');

  /// Lower bound of the visible domain.
  final double min;

  /// Upper bound of the visible domain.
  final double max;

  /// The window's span (`max - min`).
  double get width => max - min;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DomainWindow && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'DomainWindow($min → $max)';
}

/// Programmatic control of a chart's visible domain.
///
/// Attach via `Chart(controller: ...)`. Setting a domain moves the chart;
/// user pan/zoom gestures write back, so listeners always see the current
/// window:
///
/// ```dart
/// final controller = ChartController();
/// Chart(series: [...], controller: controller,
///     interactions: const [PanZoom()]);
///
/// controller.setXDomain(20, 80);          // zoom to x ∈ [20, 80]
/// controller.addListener(() => print(controller.xDomain));
/// controller.reset();                      // back to the full data domain
/// ```
///
/// Domain units follow the axis: numeric values for `NumericAxis`, epoch
/// milliseconds for `TimeAxis` (see [setXDomainTime]).
class ChartController extends ChangeNotifier {
  DomainWindow? _xDomain;
  DomainWindow? _yDomain;

  /// The visible x window, or null when showing the full data domain.
  DomainWindow? get xDomain => _xDomain;

  /// The visible y window, or null when showing the full data domain.
  DomainWindow? get yDomain => _yDomain;

  /// Sets the visible x window (domain units).
  void setXDomain(double min, double max) {
    assert(min < max, 'min must be < max');
    if (_xDomain?.min == min && _xDomain?.max == max) return;
    _xDomain = DomainWindow(min: min, max: max);
    notifyListeners();
  }

  /// Sets the visible x window of a time axis.
  void setXDomainTime(DateTime min, DateTime max) => setXDomain(
        min.millisecondsSinceEpoch.toDouble(),
        max.millisecondsSinceEpoch.toDouble(),
      );

  /// Sets the visible y window (domain units).
  void setYDomain(double min, double max) {
    assert(min < max, 'min must be < max');
    if (_yDomain?.min == min && _yDomain?.max == max) return;
    _yDomain = DomainWindow(min: min, max: max);
    notifyListeners();
  }

  /// Restores the full data domain on both axes.
  void reset() {
    if (_xDomain == null && _yDomain == null) return;
    _xDomain = null;
    _yDomain = null;
    notifyListeners();
  }
}
