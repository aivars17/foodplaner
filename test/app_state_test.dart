import 'package:flutter_test/flutter_test.dart';

import 'package:foodplaner/core/app_state.dart';
import 'package:foodplaner/core/config/app_config.dart';
import 'package:foodplaner/core/local/document_store.dart';
import 'package:foodplaner/domain/models/dish.dart';
import 'package:foodplaner/domain/models/household.dart';
import 'package:foodplaner/domain/models/ingredient.dart';
import 'package:foodplaner/domain/models/meal_plan.dart';

// A deterministic timestamp so last-write-wins ordering is predictable.
const _ts = '2026-01-01T00:00:00Z';

Dish _dish(List<Ingredient> ings) => Dish(
      id: 'd1',
      name: 'Kotletai',
      kind: 'main',
      covers: 4,
      recipe: Recipe(ingredients: ings),
      updatedAt: _ts,
      version: 1,
    );

Meal _dinner(Dish d, {bool confirmed = true}) => Meal(
      id: 'm1',
      planId: 'p1',
      dayOfWeek: 0,
      mealType: 'dinner',
      order: 0,
      dishes: [d],
      confirmed: confirmed,
      updatedAt: _ts,
      version: 1,
    );

MealPlan _plan(
  Dish d, {
  String id = 'p1',
  bool isCurrent = true,
  bool confirmed = true,
}) =>
    MealPlan(
      id: id,
      name: 'P',
      weekStart: '2026-01-01',
      isCurrent: isCurrent,
      meals: [_dinner(d, confirmed: confirmed)],
      updatedAt: _ts,
      version: 1,
    );

// AppStore with no sync client and no AI client — exercises the local-only
// paths without any network or platform-channel I/O.
AppStore _newStore(LocalDocumentStore docs) =>
    AppStore(docs: docs, config: AppConfig());

void main() {
  test('load() with an empty store yields sensible defaults', () async {
    final store = _newStore(LocalDocumentStore());
    await store.load();
    expect(store.household, isNotNull);
    expect(store.household!.memberCount, 1); // empty members => single-person default
    expect(store.plans, isEmpty);
    expect(store.currentPlan, isNull);
    expect(store.currentShoppingList, isNull);
  });

  test('saveHousehold persists settings and they reload', () async {
    final docs = LocalDocumentStore();
    final store = _newStore(docs);

    await store.saveHousehold(const HouseholdSettings(
      dietary: ['vegetarian'],
      onHand: ['bulvės'],
      defaultServings: 4,
      members: [FamilyMember(id: 'm1', name: 'Tėvas')],
      updatedAt: _ts,
      version: 1,
    ));

    final store2 = _newStore(docs);
    await store2.load();
    expect(store2.household!.dietary, ['vegetarian']);
    expect(store2.household!.onHand, ['bulvės']);
    expect(store2.household!.defaultServings, 4);
    expect(store2.household!.members.single.name, 'Tėvas');
  });

  test('buildShoppingList aggregates confirmed dishes and drops on-hand',
      () async {
    final docs = LocalDocumentStore();

    // Seed a confirmed plan and a household that already has potatoes on hand.
    final plan = _plan(_dish(const [
      Ingredient(name: 'Mėsa', amount: '500', unit: 'g', storeCategory: 'Mėsos'),
      Ingredient(name: 'Bulvės', amount: '1', unit: 'kg', storeCategory: 'Daržovės'),
    ]));
    docs.upsert(DocEntity(
        type: 'plans',
        id: plan.id,
        data: plan.toJson(),
        updatedAt: plan.updatedAt,
        version: plan.version));
    docs.upsert(DocEntity(
        type: 'settings',
        id: 'default',
        data: const HouseholdSettings(onHand: ['bulvės'], defaultServings: 4)
            .toJson(),
        updatedAt: _ts,
        version: 1));

    final store = _newStore(docs);
    await store.load();
    expect(store.currentPlan, isNotNull);

    final list = await store.buildShoppingList();
    // Potatoes are on hand, so only meat remains.
    expect(list.items.length, 1);
    expect(list.items.single.name, 'Mėsa');
    expect(list.items.single.amount, 500.0);
  });

  test('toggleMealConfirmed flips confirmation and persists it', () async {
    final docs = LocalDocumentStore();

    final plan = _plan(
      _dish(const [Ingredient(name: 'X', amount: '1', unit: 'vnt.')]),
      confirmed: false,
    );
    docs.upsert(DocEntity(
        type: 'plans',
        id: plan.id,
        data: plan.toJson(),
        updatedAt: plan.updatedAt,
        version: plan.version));

    final store = _newStore(docs);
    await store.load();
    final meal = store.currentPlan!.meals.single;
    expect(meal.confirmed, isFalse);

    await store.toggleMealConfirmed(meal.dayOfWeek, meal.mealType, true);
    expect(store.currentPlan!.meals.single.confirmed, isTrue);

    // Re-load from the store to confirm it was actually written.
    final store2 = _newStore(docs);
    await store2.load();
    expect(store2.currentPlan!.meals.single.confirmed, isTrue);
  });

  test('generateWeeklyPlan throws when the AI client is not configured',
      () async {
    final store = _newStore(LocalDocumentStore());
    await store.load();
    await expectLater(store.generateWeeklyPlan(), throwsStateError);
  });

  test('syncNow is a no-op when no sync client is configured', () async {
    final store = _newStore(LocalDocumentStore());
    await store.load();
    await store.syncNow(); // must not throw
    expect(store.lastError, isNull);
  });

  test('applyRemoteChange upserts a remote plan into the store', () async {
    final store = _newStore(LocalDocumentStore());
    await store.load();

    final remote = _plan(
      _dish(const [Ingredient(name: 'X', amount: '1', unit: 'vnt.')]),
      id: 'p_remote',
      isCurrent: true,
    );
    store.applyRemoteChange(DocChange(
      type: 'plans',
      id: 'p_remote',
      op: 'upsert',
      data: remote.toJson(),
      updatedAt: _ts,
      version: 1,
    ));
    // applyRemoteChange fires load() without awaiting; re-load for determinism.
    await store.load();
    expect(store.plans.map((p) => p.id), contains('p_remote'));
  });
}
