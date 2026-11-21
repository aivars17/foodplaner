import 'dish.dart';

/// A weekly meal plan. For simplicity a plan holds its whole week of meals in
/// one document (single-household last-write-wins is fine for this size).
class MealPlan {
  final String id;
  final String name;
  final String weekStart; // ISO date, e.g. 2026-11-16
  final bool isCurrent;
  final List<Meal> meals;
  final String updatedAt;
  final int version;

  const MealPlan({
    required this.id,
    required this.name,
    required this.weekStart,
    this.isCurrent = false,
    this.meals = const [],
    required this.updatedAt,
    required this.version,
  });

  MealPlan copyWith({
    String? name,
    String? weekStart,
    bool? isCurrent,
    List<Meal>? meals,
    String? updatedAt,
    int? version,
  }) {
    return MealPlan(
      id: id,
      name: name ?? this.name,
      weekStart: weekStart ?? this.weekStart,
      isCurrent: isCurrent ?? this.isCurrent,
      meals: meals ?? this.meals,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  /// Meals for a given day (0=Mon..6=Sun), ordered.
  List<Meal> mealsForDay(int dayOfWeek) => meals
      .where((m) => m.dayOfWeek == dayOfWeek)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  /// All confirmed meals across the week (used to build the shopping list).
  List<Meal> confirmedMeals() =>
      meals.where((m) => m.confirmed).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekStart': weekStart,
        'isCurrent': isCurrent,
        'meals': meals.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
        'version': version,
      };

  factory MealPlan.fromJson(Map<String, dynamic> j) => MealPlan(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        weekStart: (j['weekStart'] ?? '').toString(),
        isCurrent: (j['isCurrent'] ?? false) as bool,
        meals: Meal.listFromJson(j['meals'] as List<dynamic>?),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );

  static List<MealPlan> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .map((e) => MealPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
