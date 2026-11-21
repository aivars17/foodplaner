import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/shopping_list.dart';

/// Shows the shopping list built from the active plan's confirmed dishes,
/// grouped by store category, with a "build list" action.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final list = store.currentShoppingList;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => _build(context, store),
              icon: const Icon(Icons.renew),
              label: const Text('Sudaryti sąrašą'),
            ),
          ),
        ),
        if (list == null || list.items.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Dar nėra pirkinių sąrašo. Patvirtinkite valgius '
                  'ir spauskite „Sudaryti sąrašą“.'),
            ),
          )
        else
          Expanded(child: _buildList(context, list)),
      ],
    );
  }

  Widget _buildList(BuildContext context, ShoppingList list) {
    final groups = <String, List<ShoppingItem>>{};
    for (final item in list.items) {
      groups.putIfAbsent(item.storeCategory, () => []).add(item);
    }
    final categories = groups.keys.toList()..sort();

    return ListView(
      children: [
        for (final cat in categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(cat, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final item in groups[cat]!)
            ListTile(
              title: Text(item.name),
              subtitle: Text('${item.amount.toString().replaceAll('.', ',')} ${item.unit}'),
              trailing: const Icon(Icons.checkbox, size: 18, color: Colors.grey),
            ),
        ],
      ],
    );
  }

  Future<void> _build(BuildContext context, AppStore store) async {
    try {
      await store.buildShoppingList();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Klaida: $e')));
      }
    }
  }
}
