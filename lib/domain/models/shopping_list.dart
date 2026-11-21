/// A single line in a shopping list, after aggregation across confirmed dishes.
class ShoppingItem {
  final String name;
  final double amount;
  final String unit;
  final String storeCategory;
  final List<String> dishes; // which dishes contribute this item

  const ShoppingItem({
    required this.name,
    required this.amount,
    required this.unit,
    required this.storeCategory,
    this.dishes = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'storeCategory': storeCategory,
        'dishes': dishes,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        name: (j['name'] ?? '').toString(),
        amount: double.tryParse((j['amount'] ?? '0').toString()) ?? 0,
        unit: (j['unit'] ?? 'vnt.').toString(),
        storeCategory: (j['storeCategory'] ?? 'Kita').toString(),
        dishes: (j['dishes'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// A materialized shopping list generated from a plan's confirmed dishes.
class ShoppingList {
  final String id;
  final String planId;
  final List<ShoppingItem> items;
  final String updatedAt;
  final int version;

  const ShoppingList({
    required this.id,
    required this.planId,
    this.items = const [],
    required this.updatedAt,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'items': items.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
        'version': version,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
        id: (j['id'] ?? '').toString(),
        planId: (j['planId'] ?? '').toString(),
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) =>
                ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );
}
