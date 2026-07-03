import 'package:meta/meta.dart';

/// Highlights one series and mutes the rest.
///
/// The emphasized series renders at full saturation and is painted on top;
/// every other series drops to [mutedOpacity]. This is the "highlight one,
/// mute the rest" pattern:
///
/// ```dart
/// Chart(
///   series: [
///     LineSeries(data: north, id: 'north'),
///     LineSeries(data: south, id: 'south'),
///     LineSeries(data: west, id: 'west'),
///   ],
///   emphasis: const SeriesEmphasis(id: 'north'),
/// )
/// ```
@immutable
class SeriesEmphasis {
  /// Emphasizes the series with a matching [Series.id], or by [index] when
  /// no id matches. At least one of the two must be provided.
  const SeriesEmphasis({this.id, this.index, this.mutedOpacity = 0.3})
      : assert(id != null || index != null, 'Provide id or index');

  /// The `Series.id` of the emphasized series.
  final String? id;

  /// Position of the emphasized series in the `series` list, used when
  /// [id] is null or matches nothing.
  final int? index;

  /// Opacity multiplier applied to all non-emphasized series.
  final double mutedOpacity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesEmphasis &&
          other.id == id &&
          other.index == index &&
          other.mutedOpacity == mutedOpacity;

  @override
  int get hashCode => Object.hash(id, index, mutedOpacity);
}
