import 'dart:ui';

/// Built-in color palettes.
///
/// nichart ships one 8-color categorical palette in two lightness variants.
/// Colors are assigned to series in fixed order — color follows the series'
/// position in the `series` list, never its rank or value. A ninth hue is
/// never generated; datasets with more than eight categories should fold the
/// tail into an "Other" series.
abstract final class ChartPalettes {
  /// Categorical palette tuned for light surfaces.
  static const List<Color> categoricalLight = <Color>[
    Color(0xFF5B7CFA), // indigo
    Color(0xFF14B8A6), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFF0EA5E9), // sky
    Color(0xFFF97316), // orange
  ];

  /// Categorical palette tuned for dark surfaces (same hues, lifted
  /// lightness so strokes hold up against dark backgrounds).
  static const List<Color> categoricalDark = <Color>[
    Color(0xFF7C97FF),
    Color(0xFF2DD4BF),
    Color(0xFFFBBF24),
    Color(0xFFFB7185),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFF38BDF8),
    Color(0xFFFB923C),
  ];
}
