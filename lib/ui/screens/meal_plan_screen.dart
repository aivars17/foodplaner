import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/dish.dart';
import '../../domain/models/meal_plan.dart';

/// Shows the active weekly plan: meals grouped by day, with coverage status,
/// confirm toggles, and a "plan for the remaining" action when a slot is
/// under-covered for the household.
class MealPlanScreen extends StatelessWidget {
  final void Function(Meal) onOpenDish;
  const MealPlanScreen({super.key, required this.onOpenDish});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final plan = store.activePlan;
    final household = store.household ?? const HouseholdSettings(updatedAt: '0', version: 0);
    final size = household.memberCount;

    if (plan == null) {
      return const Center(child: Text('Dar nėra plano. Paspauskite „Sugeneruoti“.'));
    }

    const dayNames = ['Pirmadienis', 'Antradienis', 'Trečiadienis',
      'Ketvirtadienis', 'Penktadienis', 'Šeštadienis', 'Sekmadienis'];

    return ListView(
      children: [
        for (var day = 0; day < 7; day++)
          _DaySection(
            day: day,
            label: dayNames[day],
            plan: plan,
            store: store,
            household: size,
            onOpenDish: onOpenDish,
          ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final int day;
  final String label;
  final MealPlan plan;
  final AppStore store;
  final int household;
  final void Function(Meal) onOpenDish;

  const _DaySection({
    required this.day,
    required this.label,
    required this.plan,
    required this.store,
    required this.household,
    required this.onOpenDish,
  });

  @override
  Widget build(BuildContext context) {
    final meals = plan.mealsForDay(day);
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final meal in meals)
          _MealTile(
            meal: meal,
            store: store,
            household: household,
            onOpenDish: onOpenDish,
          ),
      ],
    );
  }
}

class _MealTile extends StatelessWidget {
  final Meal meal;
  final AppStore store;
  final int household;
  final void Function(Meal) onOpenDish;

  const _MealTile({
    required this.meal,
    required this.store,
    required this.household,
    required this.onOpenDish,
  });

  @override
  Widget build(BuildContext context) {
    final cov = store.coverage.analyze(meal, household);
    final mealTypeLabel = _mealTypeLabel(meal.mealType);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$mealTypeLabel',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                _CoverageChip(covered: cov.covered, household: household),
              ],
            ),
            const SizedBox(height: 6),
            for (final dish in meal.dishes)
              InkWell(
                onTap: () => onOpenDish(meal),
                child: Row(
                  children: [
                    Icon(dish.isMain ? Icons.star : Icons.leaf, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(dish.name)),
                    Text('${dish.covers} žm.'),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                ToggleButton(
                  isSelected: meal.confirmed,
                  onPressed: () => store
                      .toggleMealConfirmed(meal.dayOfWeek, meal.mealType, !meal.confirmed),
                  child: const Text('Patvirtintas'),
                ),
                if (cov.needsMore)
                  TextButton.icon(
                    onPressed: () => _generateForRemaining(context),
                    icon: const Icon(Icons.person_add),
                    label: Text('Suplanuoti likusiems ${cov.remainingCovers}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateForRemaining(BuildContext context) async {
    try {
      await store.generateForRemaining(meal);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Suplanuota likusiems')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Klaida: $e')));
      }
    }
  }
}

class _CoverageChip extends StatelessWidget {
  final int covered;
  final int household;
  const _CoverageChip({required this.covered, required this.household});

  @override
  Widget build(BuildContext context) {
    final complete = covered >= household && household > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: complete ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$covered / $household žm.',
        style: TextStyle(
          fontSize: 12,
          color: complete ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

String _mealTypeLabel(String t) {
  switch (t) {
    case 'breakfast':
      return 'Pusryčiai';
    case 'lunch':
      return 'Pietūs';
    case 'dinner':
      return 'Vakarienė';
    case 'snack':
      return 'Užkandis';
    default:
      return t;
  }
}
