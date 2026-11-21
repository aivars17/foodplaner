import 'package:flutter/material.dart';

import '../../app.dart';
import 'dish_detail_screen.dart';
import 'shopping_list_screen.dart';
import 'settings_screen.dart';
import 'meal_plan_screen.dart';

/// The main navigation shell: Plan / Shopping / Settings tabs, plus a
/// "generate weekly plan" action in the app bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _tabs = <Widget>[
    Tab(icon: Icon(Icons.restaurant), text: 'Planas'),
    Tab(icon: Icon(Icons.shopping_cart), text: 'Pirkimai'),
    Tab(icon: Icon(Icons.settings), text: 'Nustatymai'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('FoodPlaner'),
              actions: [
                TextButton(
                  onPressed: () => _generate(store, context),
                  child: store.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sugeneruoti'),
                ),
              ],
              bottom: TabBar(tabs: _tabs),
            ),
            body: TabBarView(
              children: [
                MealPlanScreen(
                  onOpenDish: (meal) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DishDetailScreen(mealId: meal.id, planId: meal.planId),
                    ),
                  ),
                ),
                const ShoppingListScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generate(AppStore store, BuildContext ctx) async {
    try {
      await store.generateWeeklyPlan();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('Savaitės planas sugeneruotas')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Klaida: $e')));
      }
    }
  }
}
