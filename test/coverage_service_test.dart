import 'package:flutter_test/flutter_test.dart';
import 'package:foodplaner/domain/models/dish.dart';
import 'package:foodplaner/domain/models/meal_plan.dart';
import 'package:foodplaner/domain/services/coverage_service.dart';

void main() {
  const svc = CoverageService();

  Dish dish(String id, int covers) => Dish(
        id: id,
        name: 'D $id',
        kind: 'main',
        covers: covers,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      );

  Meal mealWith(int day, List<Dish> dishes) => Meal(
        id: 'm$day',
        planId: 'p',
        dayOfWeek: day,
        mealType: 'dinner',
        order: day,
        dishes: dishes,
        confirmed: false,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      );

  test('a dish covering fewer than household leaves remaining', () {
    final meal = mealWith(0, [dish('d1', 1)]);
    final r = svc.analyze(meal, 4);
    expect(r.covered, 1);
    expect(r.uncovered, 3);
    expect(r.remainingCovers, 3);
    expect(r.isComplete, isFalse);
  });

  test('multiple dishes sum their covers', () {
    final meal = mealWith(0, [dish('d1', 2), dish('d2', 2)]);
    final r = svc.analyze(meal, 4);
    expect(r.isComplete, isTrue);
  });

  test('uncovered returns only incomplete slots', () {
    final plan = MealPlan(
      id: 'p',
      name: 'P',
      weekStart: '2026-01-01',
      meals: [
        mealWith(0, [dish('a', 1)]), // uncovered 3
        mealWith(1, [dish('b', 4)]), // complete
      ],
      updatedAt: '2026-01-01T00:00:00Z',
      version: 1,
    );
    final uncovered = svc.uncovered(plan, 4);
    expect(uncovered.length, 1);
    expect(uncovered.single.meal.dayOfWeek, 0);
    expect(svc.isPlanComplete(plan, 4), isFalse);
  });

  test('markConfirmedIfComplete only confirms when fully covered', () {
    final meal = mealWith(0, [dish('a', 2)]);
    expect(svc.markConfirmedIfComplete(meal, 4).confirmed, isFalse);
    expect(svc.markConfirmedIfComplete(mealWith(0, [dish('a', 4)]), 4).confirmed,
        isTrue);
  });
}
