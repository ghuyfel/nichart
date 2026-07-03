import 'package:flutter/animation.dart';
import 'package:meta/meta.dart';

/// Motion configuration for a chart.
///
/// Two kinds of motion, both on by default:
///
/// * **Entrance** — series draw in on first layout: lines reveal
///   progressively along their path, bars grow from the baseline with a
///   slight stagger, scatter markers pop in.
/// * **Morphing** — when `data` changes the chart lerps old → new
///   point-by-point (and the axes glide to their new domain), instead of
///   snapping.
///
/// ## How points match during a morph
///
/// Series match by `Series.id` when set, else by list position. Within a
/// series: bar segments match by x position (new bars grow from zero) and
/// donut segments by category label (new segments sweep in). Line, area
/// and scatter points match by `Series.pointIdAccessor` when provided
/// (unmatched new points appear in place; removed ids simply vanish) —
/// otherwise by index, with extra new points growing out of the old last
/// point and unmatched scatter points fading in. Series that were sliced
/// or downsampled for display skip morphing, since index alignment would
/// lie.
///
/// Charts respect the platform reduced-motion setting
/// (`MediaQuery.disableAnimations`) automatically; [ChartAnimation.none]
/// turns everything off unconditionally.
///
/// ```dart
/// Chart.line(data: points)                                  // animated
/// Chart(series: [...], animation: const ChartAnimation.none())
/// Chart(series: [...], animation: const ChartAnimation(
///   duration: Duration(milliseconds: 900),
/// ))
/// ```
@immutable
class ChartAnimation {
  /// Creates a motion configuration. Every parameter has an opinionated
  /// default.
  const ChartAnimation({
    this.duration = const Duration(milliseconds: 600),
    this.morphDuration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.entrance = true,
    this.morph = true,
  });

  /// Disables all chart motion.
  const ChartAnimation.none()
      : duration = Duration.zero,
        morphDuration = Duration.zero,
        curve = Curves.linear,
        entrance = false,
        morph = false;

  /// Length of the entrance animation.
  final Duration duration;

  /// Length of the data-change morph animation.
  final Duration morphDuration;

  /// Easing curve for both entrance and morphing.
  final Curve curve;

  /// Whether series animate in on first layout.
  final bool entrance;

  /// Whether data changes morph instead of snapping.
  final bool morph;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartAnimation &&
          other.duration == duration &&
          other.morphDuration == morphDuration &&
          other.curve == curve &&
          other.entrance == entrance &&
          other.morph == morph;

  @override
  int get hashCode =>
      Object.hash(duration, morphDuration, curve, entrance, morph);
}
