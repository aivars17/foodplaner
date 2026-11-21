import 'package:flutter_test/flutter_test.dart';

import 'package:foodplaner/domain/services/cooking_scheduler.dart';

void main() {
  const scheduler = CookingScheduler();

  test('empty input yields an empty schedule with zero duration', () {
    final s = scheduler.schedule(const []);
    expect(s.steps, isEmpty);
    expect(s.totalMinutes, 0);
  });

  test('prep is serialized on the single cook; oven serializes separately',
      () {
    final s = scheduler.schedule(const [
      ScheduleDish(name: 'Troškinys', prepMinutes: 20, cookMinutes: 40, usesOven: true),
      ScheduleDish(name: 'Salotos', prepMinutes: 10),
      ScheduleDish(name: 'Bulvės', prepMinutes: 5, cookMinutes: 40, usesOven: true),
    ]);

    // Deterministic order: by start minute, then input order on ties.
    final ordered = s.steps
        .map((e) => '${e.startMinutes}:${e.dish}:${e.action}')
        .toList();
    expect(
      ordered,
      [
        '0:Troškinys:Ruošti 20 min',
        '20:Troškinys:Krosnis 40 min',
        '20:Salotos:Ruošti 10 min',
        '30:Bulvės:Ruošti 5 min',
        '60:Bulvės:Krosnis 40 min',
      ],
    );
    // Oven overlaps later prep, so the makespan is far less than 20+40+10+5+40.
    expect(s.totalMinutes, 100);
  });

  test('two oven dishes serialize on the oven (no overlap)', () {
    final s = scheduler.schedule(const [
      ScheduleDish(name: 'A', prepMinutes: 0, cookMinutes: 30, usesOven: true),
      ScheduleDish(name: 'B', prepMinutes: 0, cookMinutes: 30, usesOven: true),
    ]);
    final cooks =
        s.steps.where((e) => e.action.startsWith('Krosnis')).toList();
    expect(cooks.map((e) => e.startMinutes).toList(), [0, 30]);
    expect(s.totalMinutes, 60);
  });

  test('non-oven dishes do not consume the oven resource', () {
    final s = scheduler.schedule(const [
      ScheduleDish(name: 'Virsve', prepMinutes: 15),
      ScheduleDish(name: 'Garnyras', prepMinutes: 5),
    ]);
    expect(s.totalMinutes, 20);
    expect(s.steps.every((e) => !e.action.startsWith('Krosnis')), isTrue);
  });

  test('the same input always produces the same schedule', () {
    const dishes = [
      ScheduleDish(name: 'A', prepMinutes: 10, cookMinutes: 20, usesOven: true),
      ScheduleDish(name: 'B', prepMinutes: 7),
      ScheduleDish(name: 'C', prepMinutes: 3, cookMinutes: 20, usesOven: true),
    ];
    final a = scheduler.schedule(dishes);
    final b = scheduler.schedule(dishes);
    expect(a.steps.map((e) => e.startMinutes).toList(),
        b.steps.map((e) => e.startMinutes).toList());
    expect(a.totalMinutes, b.totalMinutes);
  });
}
