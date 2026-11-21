import 'package:flutter_test/flutter_test.dart';

import 'package:foodplaner/domain/models/household.dart';
import 'package:foodplaner/domain/services/prompt_builder.dart';

void main() {
  const builder = PromptBuilder();

  // A household with global + per-member dietary restrictions and items on hand.
  const settings = HouseholdSettings(
    dietary: ['vegetarian'],
    onHand: ['bulvės', 'svogūnai'],
    defaultServings: 3,
    members: [
      FamilyMember(id: 'a', name: 'A', dietary: ['be glitimo']),
      FamilyMember(id: 'b', name: 'B'),
    ],
    updatedAt: '0',
    version: 0,
  );

  test('mealPlan builds a JSON prompt with household context', () {
    final p = builder.mealPlan(settings: settings);
    expect(p.json, isTrue);
    expect(p.system, contains('"meals"'));
    expect(p.system, contains('dayOfWeek'));
    expect(p.user, contains('7 dienų')); // default days
    expect(p.user, contains('Šeimos narių skaičius: 2')); // 2 members
    expect(p.user, contains('Numatytos porcijos: 3'));
    expect(p.user, contains('vegetarian')); // global dietary
    expect(p.user, contains('be glitimo')); // per-member dietary
    expect(p.user, contains('bulvės')); // on hand
    expect(p.user, contains('svogūnai'));
  });

  test('mealPlan honors custom days and meal types', () {
    final p = builder.mealPlan(
      settings: settings,
      days: 5,
      mealTypes: const ['lunch', 'dinner'],
    );
    expect(p.user, contains('5 dienų'));
    expect(p.user, contains('lunch, dinner'));
  });

  test('dishForRemaining names the day, covers and JSON shape', () {
    final p =
        builder.dishForRemaining(settings: settings, dayOfWeek: 2, mealType: 'dinner', covers: 2);
    expect(p.json, isTrue);
    expect(p.system, contains('"kind":"main"'));
    expect(p.user, contains('Trečiadienis')); // dayOfWeek 2
    expect(p.user, contains('2 žmonių')); // covers
  });

  test('sideVariants asks for a JSON array of side dishes', () {
    final p = builder.sideVariants(mainName: 'Troškinys', count: 3);
    expect(p.json, isTrue);
    expect(p.system, contains('"kind":"side"'));
    expect(p.user, contains('Troškinys'));
    expect(p.user, contains('3 skirtingų'));
  });

  test('cookingSchedule lists every dish by number', () {
    final p = builder.cookingSchedule(const ['Troškinys', 'Bulvės', 'Salotos']);
    expect(p.json, isTrue);
    expect(p.system, contains('schedule'));
    expect(p.user, contains('1. Troškinys'));
    expect(p.user, contains('2. Bulvės'));
    expect(p.user, contains('3. Salotos'));
  });
}
