import 'package:flutter/foundation.dart';

import 'scale.dart';

/// A band scale over an ordered list of categories.
///
/// Each category owns an equal-width band of the plot; values map to band
/// centers. The domain is the category *index* (as a double), which keeps
/// the projection linear — series resolve their categories to indices once
/// and painters work in index space like any other numeric domain.
@immutable
final class CategoryScale extends Scale<double> {
  /// Creates a scale over [categories], in display order.
  CategoryScale({required List<String> categories})
      : assert(categories.isNotEmpty, 'categories must not be empty'),
        categories = List<String>.unmodifiable(categories);

  /// The categories, left to right.
  final List<String> categories;

  /// Number of bands.
  int get length => categories.length;

  /// Fraction of the plot width one band occupies.
  double get bandFraction => 1.0 / categories.length;

  /// Normalizes a category *index* to the center of its band.
  @override
  double normalize(double index) => (index + 0.5) / categories.length;

  /// The index of [category], or -1 when absent.
  int indexOf(String category) => categories.indexOf(category);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryScale && listEquals(other.categories, categories);

  @override
  int get hashCode => Object.hashAll(categories);

  @override
  String toString() => 'CategoryScale(${categories.join(', ')})';
}
