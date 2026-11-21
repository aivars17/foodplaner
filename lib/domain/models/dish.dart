import 'ingredient.dart';

/// A planned dish — either a main course or a side. `covers` is how many people
/// this dish serves, which powers the "plan for the remaining family members"
/// feature (a slot may hold multiple dishes, each with its own `covers`).
class Dish {
  final String id;
  final String name;
  final String kind; // 'main' | 'side'
  final int covers;
  final Recipe recipe;
  final String? notes;

  /// Sync fields. For embedded dishes these mirror the owning meal.
  final String updatedAt;
  final int version;

  const Dish({
    required this.id,
    required this.name,
    required this.kind,
    required this.covers,
    this.recipe = const Recipe(),
    this.notes,
    required this.updatedAt,
    required this.version,
  });

  bool get isMain => kind == 'main';
  bool get isSide => kind == 'side';

  Dish copyWith({
    String? name,
    String? kind,
    int? covers,
    Recipe? recipe,
    String? notes,
    String? updatedAt,
    int? version,
  }) {
    return Dish(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      covers: covers ?? this.covers,
      recipe: recipe ?? this.recipe,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'covers': covers,
        'recipe': recipe.toJson(),
        'notes': notes,
        'updatedAt': updatedAt,
        'version': version,
      };

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'main').toString(),
        covers: (j['covers'] ?? 1) as int,
        recipe: j['recipe'] != null
            ? Recipe.fromJson(Map<String, dynamic>.from(j['recipe'] as Map))
            : const Recipe(),
        notes: j['notes']?.toString(),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );

  static List<Dish> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .map((e) => Dish.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// A meal slot in a plan: one (day, mealType) holding a main dish plus side
/// variants.
class Meal {
  final String id;
  final String planId;
  final int dayOfWeek; // 0=Monday .. 6=Sunday
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final int order;
  final List<Dish> dishes;
  final bool confirmed;
  final String updatedAt;
  final int version;

  const Meal({
    required this.id,
    required this.planId,
    required this.dayOfWeek,
    required this.mealType,
    required this.order,
    this.dishes = const [],
    this.confirmed = false,
    required this.updatedAt,
    required this.version,
  });

  Meal copyWith({
    List<Dish>? dishes,
    bool? confirmed,
    String? updatedAt,
    int? version,
  }) {
    return Meal(
      id: id,
      planId: planId,
      dayOfWeek: dayOfWeek,
      mealType: mealType,
      order: order,
      dishes: dishes ?? this.dishes,
      confirmed: confirmed ?? this.confirmed,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'dayOfWeek': dayOfWeek,
        'mealType': mealType,
        'order': order,
        'dishes': dishes.map((e) => e.toJson()).toList(),
        'confirmed': confirmed,
        'updatedAt': updatedAt,
        'version': version,
      };

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: (j['id'] ?? '').toString(),
        planId: (j['planId'] ?? '').toString(),
        dayOfWeek: (j['dayOfWeek'] ?? 0) as int,
        mealType: (j['mealType'] ?? 'dinner').toString(),
        order: (j['order'] ?? 0) as int,
        dishes: Dish.listFromJson(j['dishes'] as List<dynamic>?),
        confirmed: (j['confirmed'] ?? false) as bool,
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );

  static List<Meal> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .map((e) => Meal.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
