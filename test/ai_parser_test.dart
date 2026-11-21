import 'package:flutter_test/flutter_test.dart';
import 'package:foodplaner/domain/services/ai_parser.dart';

void main() {
  final parser = AiParser();

  test('parses a full week plan with mains and sides', () {
    const raw = '''
{
  "meals": [
    {
      "dayOfWeek": 0,
      "mealType": "dinner",
      "dishes": [
        {"kind":"main","name":"Kotletai","covers":4,
         "recipe":{"ingredients":[{"name":"Mėsa","amount":"500","unit":"g","storeCategory":"Mėsos"}],"steps":["Sutepti","Ikepti"]}},
        {"kind":"side","name":"Bulvės","covers":4,
         "recipe":{"ingredients":[{"name":"Bulvės","amount":"1","unit":"kg","storeCategory":"Daržovės"}],"steps":["Sugrežti","Apkepk"]}}
      ]
    }
  ]
}
''';
    final plan = parser.parseMealPlan(raw);
    expect(plan.meals.length, 1);
    final meal = plan.meals.single;
    expect(meal.dayOfWeek, 0);
    expect(meal.dishes.length, 2);
    expect(meal.dishes.first.name, 'Kotletai');
    expect(meal.dishes.first.recipe.ingredients.single.name, 'Mėsa');
    expect(meal.dishes.last.kind, 'side');
  });

  test('tolerates code fences around JSON', () {
    const raw = '```\n{"meals":[]}\n```';
    final plan = parser.parseMealPlan(raw);
    expect(plan.meals, isEmpty);
  });

  test('returns empty plan on garbage', () {
    final plan = parser.parseMealPlan('not json');
    expect(plan.meals, isEmpty);
  });

  test('parses a single dish', () {
    const raw = '{"kind":"main","name":"Virsve","covers":2,'
        '"recipe":{"ingredients":[{"name":"Jautiena","amount":"300","unit":"g"}],"steps":["Virt"]}}';
    final dish = parser.parseDish(raw);
    expect(dish.name, 'Virsve');
    expect(dish.covers, 2);
    expect(dish.recipe.ingredients.single.name, 'Jautiena');
  });

  test('parseCookingSchedule sorts steps by start time', () {
    const raw = '''
    {"schedule":[
      {"startMinutes":15,"dish":"Bulvės","action":"Krosnis 40 min"},
      {"startMinutes":0,"dish":"Troškinys","action":"Ruošti 20 min"}
    ]}
    ''';
    final steps = parser.parseCookingSchedule(raw);
    expect(steps.map((s) => s.startMinutes).toList(), [0, 15]);
    expect(steps.first.dish, 'Troškinys');
  });

  test('parseCookingSchedule accepts startMinutes as a string number', () {
    const raw = '{"schedule":[{"startMinutes":"10","dish":"X","action":"a"}]}';
    final steps = parser.parseCookingSchedule(raw);
    expect(steps.single.startMinutes, 10);
  });

  test('parseCookingSchedule skips malformed entries but keeps valid ones',
      () {
    const raw =
        '{"schedule":[{"startMinutes":0,"dish":"A","action":"x"},'
        '{"startMinutes":"notanumber","dish":"B","action":"y"}]}';
    final steps = parser.parseCookingSchedule(raw);
    expect(steps.map((s) => s.dish).toList(), containsAll(['A', 'B']));
    expect(steps.length, 2);
    // 'notanumber' falls back to 0, so B is present.
    expect(steps.any((s) => s.dish == 'B' && s.startMinutes == 0), isTrue);
  });

  test('parseCookingSchedule returns empty on garbage', () {
    expect(parser.parseCookingSchedule('not json'), isEmpty);
  });

  test('parseSideVariants parses a JSON array of dishes', () {
    const raw =
        '[{"kind":"side","name":"Garnyras","covers":2,'
        '"recipe":{"ingredients":[{"name":"X","amount":"1","unit":"vnt."}],"steps":["a"]}}]';
    final dishes = parser.parseSideVariants(raw);
    expect(dishes.length, 1);
    expect(dishes.single.kind, 'side');
    expect(dishes.single.name, 'Garnyras');
    expect(dishes.single.recipe.ingredients.single.name, 'X');
  });

  test('parseSideVariants returns empty on garbage', () {
    expect(parser.parseSideVariants('not json'), isEmpty);
  });
}
