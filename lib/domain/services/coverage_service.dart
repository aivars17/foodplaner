import '../models/meal_plan.dart';
import '../models/dish.dart';

/// Result of analyzing one meal slot's coverage against the household size.
class CoverageResult {
  final Meal meal;
  final int covered;
  final int household;
  final int uncovered;

  const CoverageResult({
    required this.meal,
    required this.covered,
    required this.household,
  }) : uncovered = household > covered ? household - covered : 0;

  bool get isComplete => uncovered == 0;
  bool get needsMore => !isComplete;

  /// How many people still need a dish for this slot — the `covers` value to
  /// pass to the AI when generating a "plan for the remaining" dish.
  int get remainingCovers => uncovered;
}

/// Pure coverage logic for the "this dish is only for N people" feature.
class CoverageService {
  const CoverageService();

  int covered(Meal meal) =>
      meal.dishes.fold(0, (sum, d) => sum + (d.covers > 0 ? d.covers : 0));

  CoverageResult analyze(Meal meal, int household) {
    final c = covered(meal);
    return CoverageResult(meal: meal, covered: c, household: household);
  }

  /// All meal slots in the plan that still need more dishes.
  List<CoverageResult> uncovered(MealPlan plan, int household) {
    return plan.meals
        .map((m) => analyze(m, household))
        .where((r) => r.needsMore)
        .toList();
  }

  /// Whether the whole plan covers every slot for the household.
  bool isPlanComplete(MealPlan plan, int household) =>
      uncovered(plan, household).isEmpty;

  /// Mark a meal complete by capping its total covers to the household size.
  /// Returns a new meal with `confirmed` set when fully covered.
  Meal markConfirmedIfComplete(Meal meal, int household) {
    final complete = covered(meal) >= household && household > 0;
    return meal.copyWith(confirmed: complete);
  }
}
