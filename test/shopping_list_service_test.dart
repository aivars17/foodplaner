import 'package:flutter_test/flutter_test.dart';
import 'package:foodplaner/domain/models/dish.dart';
import 'package:foodplaner/domain/models/ingredient.dart';
import 'package:foodplaner/domain/services/shopping_list_service.dart';

void main() {
  const svc = ShoppingListService();

  test('combines identical ingredients across dishes', () {
    final meals = [
      const Meal(
        id: 'm1',
        planId: 'p',
        dayOfWeek: 0,
        mealType: 'dinner',
        order: 0,
        dishes: [
          Dish(
            id: 'd1',
            name: 'Kotletai',
            kind: 'main',
            covers: 4,
            recipe: Recipe(ingredients: [
              Ingredient(name: 'Mėsa', amount: '500', unit: 'g', storeCategory: 'Mėsos'),
              Ingredient(name: 'Svogūnai', amount: '200', unit: 'g', storeCategory: 'Daržovės'),
            ]),
            updatedAt: '2026-01-01T00:00:00Z',
            version: 1,
          ),
        ],
        confirmed: true,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      ),
      const Meal(
        id: 'm2',
        planId: 'p',
        dayOfWeek: 1,
        mealType: 'dinner',
        order: 1,
        dishes: [
          Dish(
            id: 'd2',
            name: 'Troškinta mėsa',
            kind: 'main',
            covers: 4,
            recipe: Recipe(ingredients: [
              Ingredient(name: 'Mėsa', amount: '300', unit: 'g', storeCategory: 'Mėsos'),
            ]),
            updatedAt: '2026-01-01T00:00:00Z',
            version: 1,
          ),
        ],
        confirmed: true,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      ),
    ];

    final items = svc.build(confirmedMeals: meals);
    final meat = items.firstWhere((i) => i.name == 'Mėsa');
    expect(meat.amount, 800.0);
    expect(meat.dishes.toSet(), {'Kotletai', 'Troškinta mėsa'});
    expect(items.length, 2); // Mėsa + Svogūnai
  });

  test('drops ingredients that are already on hand', () {
    final meals = [
      const Meal(
        id: 'm1',
        planId: 'p',
        dayOfWeek: 0,
        mealType: 'dinner',
        order: 0,
        dishes: [
          Dish(
            id: 'd1',
            name: 'Kotletai',
            kind: 'main',
            covers: 4,
            recipe: Recipe(ingredients: [
              Ingredient(name: 'Mėsa', amount: '500', unit: 'g'),
              Ingredient(name: 'Bulvės', amount: '1', unit: 'kg'),
            ]),
            updatedAt: '2026-01-01T00:00:00Z',
            version: 1,
          ),
        ],
        confirmed: true,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      ),
    ];
    final items = svc.build(
      confirmedMeals: meals,
      onHand: ['bulvės'], // lowercase match
    );
    expect(items.length, 1);
    expect(items.single.name, 'Mėsa');
  });

  test('groups and sorts by store category', () {
    final meals = [
      const Meal(
        id: 'm1',
        planId: 'p',
        dayOfWeek: 0,
        mealType: 'dinner',
        order: 0,
        dishes: [
          Dish(
            id: 'd1',
            name: 'X',
            kind: 'main',
            covers: 1,
            recipe: Recipe(ingredients: [
              Ingredient(name: 'Pienas', amount: '1', unit: 'l', storeCategory: 'Saldyklevė'),
              Ingredient(name: 'Svogūnai', amount: '100', unit: 'g', storeCategory: 'Daržovės'),
            ]),
            updatedAt: '2026-01-01T00:00:00Z',
            version: 1,
          ),
        ],
        confirmed: true,
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1,
      ),
    ];
    final items = svc.build(confirmedMeals: meals);
    expect(items[0].storeCategory, 'Daržovės'); // D < S
    expect(items[1].storeCategory, 'Saldyklevė');
  });
}
