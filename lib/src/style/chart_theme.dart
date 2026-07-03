import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

/// Visual styling for charts: grid, labels, palette and surface colors.
///
/// Charts need zero theme configuration — with no [ChartThemeScope] above
/// them they derive a theme from the ambient [Theme] via [ChartTheme.of],
/// flipping correctly between light and dark mode automatically.
///
/// ```dart
/// // Override for a subtree:
/// ChartThemeScope(
///   theme: ChartTheme.dark(),
///   child: Chart.line(data: points),
/// )
///
/// // White-label from a brand scheme:
/// ChartTheme.fromColorScheme(myScheme)
/// ```
@immutable
class ChartTheme {
  /// Creates a fully specified theme. Prefer [ChartTheme.light],
  /// [ChartTheme.dark] or [ChartTheme.fromColorScheme] unless you need full
  /// manual control.
  const ChartTheme({
    required this.brightness,
    required this.surfaceColor,
    required this.gridLineColor,
    required this.axisLineColor,
    required this.tickLabelStyle,
    required this.axisLabelStyle,
    required this.contextColor,
    required this.palette,
    required this.tooltipBackgroundColor,
    required this.tooltipTextStyle,
    this.gridLineWidth = 1.0,
  });

  /// The default light theme.
  factory ChartTheme.light() => ChartTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: const Color(0xFF5B7CFA)),
      );

  /// The default dark theme.
  factory ChartTheme.dark() => ChartTheme.fromColorScheme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B7CFA),
          brightness: Brightness.dark,
        ),
      );

  /// Derives a theme from a Material [ColorScheme].
  ///
  /// Gridlines, labels and the context color are drawn from
  /// [ColorScheme.onSurface] at reduced opacities; the palette follows the
  /// scheme's brightness.
  factory ChartTheme.fromColorScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    return ChartTheme(
      brightness: scheme.brightness,
      surfaceColor: scheme.surface,
      gridLineColor: onSurface.withValues(alpha: isDark ? 0.10 : 0.07),
      axisLineColor: onSurface.withValues(alpha: isDark ? 0.18 : 0.13),
      tickLabelStyle: TextStyle(
        fontSize: 11,
        color: onSurface.withValues(alpha: 0.62),
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      axisLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface.withValues(alpha: 0.78),
      ),
      contextColor: onSurface.withValues(alpha: 0.38),
      palette: isDark
          ? ChartPalettes.categoricalDark
          : ChartPalettes.categoricalLight,
      tooltipBackgroundColor:
          scheme.inverseSurface.withValues(alpha: 0.96),
      tooltipTextStyle: TextStyle(
        fontSize: 11,
        color: scheme.onInverseSurface,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  /// Resolves the ambient chart theme.
  ///
  /// Uses the nearest [ChartThemeScope] if present, otherwise derives a
  /// theme from `Theme.of(context).colorScheme` — so charts adapt to light
  /// and dark mode with zero configuration.
  static ChartTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChartThemeScope>();
    if (scope != null) return scope.theme;
    return ChartTheme.fromColorScheme(Theme.of(context).colorScheme);
  }

  /// Whether this theme targets light or dark surfaces.
  final Brightness brightness;

  /// The color charts sit on — used for gaps, marker rings and any element
  /// that must "cut out" of the drawing to the background.
  final Color surfaceColor;

  /// Color of the horizontal grid hairlines.
  final Color gridLineColor;

  /// Color of the (minimal) axis baseline.
  final Color axisLineColor;

  /// Style for tick labels (11 px, tabular figures, reduced-opacity
  /// on-surface color by default).
  final TextStyle tickLabelStyle;

  /// Style for axis title labels.
  final TextStyle axisLabelStyle;

  /// Muted color used by context/comparison series
  /// (see `LineStyle.context`).
  final Color contextColor;

  /// Categorical series palette, assigned to series in fixed order.
  final List<Color> palette;

  /// Background of the built-in tooltip card (an inverse-surface tone, so
  /// it reads as "dark card" in light mode and flips in dark mode).
  final Color tooltipBackgroundColor;

  /// Text style inside the built-in tooltip card.
  final TextStyle tooltipTextStyle;

  /// Stroke width of grid hairlines.
  final double gridLineWidth;

  /// Returns a copy of this theme with the given fields replaced.
  ChartTheme copyWith({
    Brightness? brightness,
    Color? surfaceColor,
    Color? gridLineColor,
    Color? axisLineColor,
    TextStyle? tickLabelStyle,
    TextStyle? axisLabelStyle,
    Color? contextColor,
    List<Color>? palette,
    Color? tooltipBackgroundColor,
    TextStyle? tooltipTextStyle,
    double? gridLineWidth,
  }) {
    return ChartTheme(
      brightness: brightness ?? this.brightness,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      axisLineColor: axisLineColor ?? this.axisLineColor,
      tickLabelStyle: tickLabelStyle ?? this.tickLabelStyle,
      axisLabelStyle: axisLabelStyle ?? this.axisLabelStyle,
      contextColor: contextColor ?? this.contextColor,
      palette: palette ?? this.palette,
      tooltipBackgroundColor:
          tooltipBackgroundColor ?? this.tooltipBackgroundColor,
      tooltipTextStyle: tooltipTextStyle ?? this.tooltipTextStyle,
      gridLineWidth: gridLineWidth ?? this.gridLineWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartTheme &&
          other.brightness == brightness &&
          other.surfaceColor == surfaceColor &&
          other.gridLineColor == gridLineColor &&
          other.axisLineColor == axisLineColor &&
          other.tickLabelStyle == tickLabelStyle &&
          other.axisLabelStyle == axisLabelStyle &&
          other.contextColor == contextColor &&
          listEquals(other.palette, palette) &&
          other.tooltipBackgroundColor == tooltipBackgroundColor &&
          other.tooltipTextStyle == tooltipTextStyle &&
          other.gridLineWidth == gridLineWidth;

  @override
  int get hashCode => Object.hash(
        brightness,
        surfaceColor,
        gridLineColor,
        axisLineColor,
        tickLabelStyle,
        axisLabelStyle,
        contextColor,
        Object.hashAll(palette),
        tooltipBackgroundColor,
        tooltipTextStyle,
        gridLineWidth,
      );
}

/// Provides a [ChartTheme] to all charts below it in the tree.
///
/// ```dart
/// ChartThemeScope(
///   theme: ChartTheme.fromColorScheme(brandScheme),
///   child: DashboardGrid(),
/// )
/// ```
class ChartThemeScope extends InheritedWidget {
  /// Creates a scope that overrides the chart theme for [child].
  const ChartThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// The theme charts below this widget will use.
  final ChartTheme theme;

  @override
  bool updateShouldNotify(ChartThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
