import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/dish.dart';
import '../../domain/models/meal_plan.dart';
import '../../domain/services/prompt_builder.dart';

/// Shows one meal slot: the main dish + side variants, with full recipes
/// (ingredients + steps). Can also generate a cooking schedule across dishes.
class DishDetailScreen extends StatelessWidget {
  final String mealId;
  final String planId;
  const DishDetailScreen({super.key, required this.mealId, required this.planId});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final plan = store.activePlan;
    Meal? meal;
    if (plan != null) {
      for (final m in plan.meals) {
        if (m.id == mealId) {
          meal = m;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Patiekalas')),
      body: meal == null
          ? const Center(child: Text('Valgis nerastas'))
          : ListView(
              children: [
                for (final dish in meal!.dishes) _DishCard(dish: dish),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _generateSchedule(context, store, meal!),
                    icon: const Icon(Icons.timeline),
                    label: const Text('Sudaryti ruošimo eilę'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _generateSchedule(
      BuildContext context, AppStore store, Meal meal) async {
    if (store.activePlan == null) return;
    try {
      final names = meal.dishes.map((d) => d.name).toList();
      final p = const PromptBuilder().cookingSchedule(names);
      final raw = await store.runPrompt(p);
      final schedule = store.parser.parseCookingSchedule(raw);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ruošimo eilė'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in schedule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${s.startMinutes} min — ${s.dish}: ${s.action}'),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Uždaryti'))],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Klaida: $e')));
      }
    }
  }
}

class _DishCard extends StatelessWidget {
  final Dish dish;
  const _DishCard({required this.dish});

  @override
  Widget build(BuildContext context) {
    final main = dish.isMain;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(main ? Icons.star : Icons.leaf, size: 18),
            const SizedBox(width: 8),
            Text('${dish.name} (${dish.covers} žm.)'),
          ],
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Ingredientai:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final ing in dish.recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Text('• ${ing.amount} ${ing.unit} ${ing.name}'),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Ruošimas:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (var i = 0; i < dish.recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Text('${i + 1}. ${dish.recipe.steps[i]}'),
            ),
        ],
      ),
    );
  }
}
