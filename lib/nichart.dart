/// Beautiful, animated, theme-aware charts for Flutter with gorgeous
/// defaults.
///
/// A chart is three lines of code:
///
/// ```dart
/// import 'package:nichart/nichart.dart';
///
/// Chart.line(data: [DataPoint(0, 2), DataPoint(1, 5), DataPoint(2, 3)])
/// ```
///
/// Everything is customizable — series styles, axes, themes, palettes —
/// but nothing is required: every chart renders beautifully with only
/// `data` provided, and adapts to light/dark mode automatically.
library;

export 'src/animation/chart_animation.dart';
export 'src/annotations/annotation.dart';
export 'src/axes/axis.dart';
export 'src/data/data_point.dart';
export 'src/data/downsampling.dart';
export 'src/data/lttb.dart';
export 'src/interaction/chart_controller.dart';
export 'src/interaction/chart_interaction.dart';
export 'src/interaction/hover_info.dart';
export 'src/scales/category_scale.dart';
export 'src/scales/scale.dart';
export 'src/scales/tick_generator.dart';
export 'src/scales/time_scale.dart';
export 'src/series/area_fill.dart';
export 'src/series/bar_style.dart';
export 'src/series/donut_style.dart';
export 'src/series/line_style.dart';
export 'src/series/scatter_style.dart';
export 'src/series/series.dart';
export 'src/style/chart_theme.dart';
export 'src/style/emphasis.dart';
export 'src/style/palette.dart';
export 'src/widgets/chart.dart';
export 'src/widgets/donut_chart.dart';
export 'src/widgets/legend.dart';
export 'src/widgets/sparkline.dart';
