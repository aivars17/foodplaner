import '../../models/dish.dart';
import '../../models/shopping_list.dart';

/// Deterministically builds a shopping list from a plan's confirmed dishes.
///
/// This is pure logic (no I/O) so it is fully unit-testable. It:
///  1. sums ingredients across all confirmed dishes,
///  2. combines identical ingredients (same normalized name + unit),
///  3. drops ingredients already on hand,
///  4. groups by store category, then sorts.
class ShoppingListService {
  const ShoppingListService();

  /// Build the list. `onHand` names are matched case-insensitively (trimmed).
  List<ShoppingItem> build({
    required List<Meal> confirmedMeals,
    List<String> onHand = const [],
  }) {
    final onHandSet =
        onHand.map((n) => _norm(n)).toSet();

    // key -> accumulator
    final acc = <String, _Accumulator>{};

    for (final meal in confirmedMeals) {
      for (final dish in meal.dishes) {
        for (final ing in dish.recipe.ingredients) {
          if (onHandSet.contains(_norm(ing.name))) continue; // already have it

          final key = '${_norm(ing.name)}\u0000${_norm(ing.unit)}';
          var a = acc[key];
          if (a == null) {
            a = _Accumulator(
              name: ing.name,
              unit: ing.unit,
              storeCategory: ing.storeCategory ?? _guessCategory(ing.name),
            );
            acc[key] = a;
          }
          a.amount += _parseAmount(ing.amount);
          a.dishes.add(dish.name);
        }
      }
    }

    final items = acc.values
        .map((a) => ShoppingItem(
              name: a.name,
              amount: _round(a.amount),
              unit: a.unit,
              storeCategory: a.storeCategory,
              dishes: a.dishes.toSet().toList(),
            ))
        .toList()
      ..sort((x, y) {
        final c = x.storeCategory.compareTo(y.storeCategory);
        if (c != 0) return c;
        return x.name.compareTo(y.name);
      });
    return items;
  }

  /// Total number of distinct ingredients that must be bought.
  int count(List<ShoppingItem> items) => items.length;

  static String _norm(String s) => s.trim().toLowerCase();

  static double _parseAmount(String s) {
    final cleaned = s.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  static double _round(double v) {
    // Round to 3 decimals, drop trailing zeros for clean display.
    final scaled = (v * 1000).roundToDouble() / 1000;
    return scaled;
  }

  static String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('pienas') ||
        n.contains('sūris') ||
        n.contains('sūrio') ||
        n.contains('jogurto')) return 'Saldyklevė';
    if (n.contains('mėsa') ||
        n.contains('žuv') ||
        n.contains('kiauš') ||
        n.contains('jaut') ||
        n.contains('višt')) return 'Mėsos';
    if (n.contains('darž') ||
        n.contains('daržovių') ||
        n.contains('svogūn') ||
        n.contains('bulv') ||
        n.contains('mork') ||
        n.contains('pomidor')) return 'Daržovės';
    if (n.contains('milt') ||
        n.contains('druska') ||
        n.contains('cukru') ||
        n.contains('alyv') ||
        n.contains('priesk') ||
        n.contains('mink') ||
        n.contains('ryž')) return 'Drovė / Prieskoniai';
    return 'Kita';
  }
}

class _Accumulator {
  final String name;
  final String unit;
  final String storeCategory;
  double amount;
  final Set<String> dishes = {};

  _Accumulator({
    required this.name,
    required this.unit,
    required this.storeCategory,
  }) : amount = 0;
}
