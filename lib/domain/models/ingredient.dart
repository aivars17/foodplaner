import 'dart:convert';

/// A single ingredient with an amount. Units are free-form strings (g, kg, ml,
/// tsk., vnt.) so the AI can express any quantity.
class Ingredient {
  final String name;
  final String amount; // e.g. "500" or "2"
  final String unit; // e.g. "g", "ml", "vnt.", "tsk."
  final String? storeCategory; // e.g. "Daržovės", "Mėsos", "Saldyklevė"

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.storeCategory,
  });

  Ingredient copyWith({
    String? name,
    String? amount,
    String? unit,
    String? storeCategory,
  }) {
    return Ingredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      storeCategory: storeCategory ?? this.storeCategory,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'storeCategory': storeCategory,
      };

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        name: (j['name'] ?? '').toString(),
        amount: (j['amount'] ?? '0').toString(),
        unit: (j['unit'] ?? 'vnt.').toString(),
        storeCategory: j['storeCategory']?.toString(),
      );

  static List<Ingredient> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .map((e) => Ingredient.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// A recipe: ingredients + ordered cooking steps.
class Recipe {
  final List<Ingredient> ingredients;
  final List<String> steps;

  const Recipe({this.ingredients = const [], this.steps = const []});

  Recipe copyWith({List<Ingredient>? ingredients, List<String>? steps}) {
    return Recipe(
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        ingredients: Ingredient.listFromJson(j['ingredients'] as List<dynamic>?),
        steps: (j['steps'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  static String encodeJson(List<Recipe> recipes) =>
      jsonEncode(recipes.map((e) => e.toJson()).toList());
}
