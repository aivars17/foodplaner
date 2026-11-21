import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/meal_plan.dart';

/// Parses JSON returned by Ollama into domain models, assigning fresh ids and
/// sync fields. Tolerant of minor shape drift from the model.
class AiParser {
  final Uuid _uuid = const Uuid();

  String _now() => DateTime.now().toUtc().toIso8601String();

  MealPlan _emptyPlan(String name) => MealPlan(
        id: _uuid.v4(),
        name: name,
        weekStart: DateTime.now().toIso8601String().substring(0, 10),
        isCurrent: true,
        meals: [],
        updatedAt: _now(),
        version: 1,
      );

  /// Parse a full-week plan. Returns an empty plan on malformed JSON.
  MealPlan parseMealPlan(String raw) {
    final plan = _emptyPlan('AI planas');
    var map = _safeMap(raw);
    if (map == null) return plan;

    final meals = <Meal>[];
    final list = map['meals'];
    if (list is List) {
      for (final e in list) {
        final mj = _asMap(e);
        if (mj == null) continue;
        meals.add(_parseMeal(mj, plan.id));
      }
    }
    return plan.copyWith(meals: meals, updatedAt: _now());
  }

  Meal _parseMeal(Map<String, dynamic> j, String planId) {
    var dishes = <Dish>[];
    final dl = j['dishes'];
    if (dl is List) {
      for (final e in dl) {
        final dj = _asMap(e);
        if (dj == null) continue;
        dishes.add(_parseDish(dj));
      }
    }
    return Meal(
      id: _uuid.v4(),
      planId: planId,
      dayOfWeek: (j['dayOfWeek'] ?? 0) as int,
      mealType: (j['mealType'] ?? 'dinner').toString(),
      order: (j['dayOfWeek'] ?? 0) as int,
      dishes: dishes,
      confirmed: false,
      updatedAt: _now(),
      version: 1,
    );
  }

  Dish _parseDish(Map<String, dynamic> j) => Dish(
        id: _uuid.v4(),
        name: (j['name'] ?? 'Be pavadinimo').toString(),
        kind: (j['kind'] ?? 'main').toString(),
        covers: (j['covers'] ?? 1) as int,
        recipe: _parseRecipe(j['recipe']),
        notes: j['notes']?.toString(),
        updatedAt: _now(),
        version: 1,
      );

  Recipe _parseRecipe(dynamic raw) {
    final m = _asMap(raw);
    if (m == null) return const Recipe();
    var ingredients = <Ingredient>[];
    final il = m['ingredients'];
    if (il is List) {
      for (final e in il) {
        final ij = _asMap(e);
        if (ij != null) ingredients.add(Ingredient.fromJson(ij));
      }
    }
    final steps = <String>[];
    final sl = m['steps'];
    if (sl is List) {
      for (final e in sl) {
        steps.add(e.toString());
      }
    }
    return Recipe(ingredients: ingredients, steps: steps);
  }

  /// Parse one dish for the "plan for the remaining" flow.
  Dish parseDish(String raw) {
    final m = _safeMap(raw);
    if (m == null) {
      return Dish(
        id: _uuid.v4(),
        name: 'Be pavadinimo',
        kind: 'main',
        covers: 1,
        updatedAt: _now(),
        version: 1,
      );
    }
    return _parseDish(m);
  }

  /// Parse a cooking schedule returned as {"schedule":[{startMinutes,dish,action}]}.
  List<CookingScheduleStep> parseCookingSchedule(String raw) {
    final decoded = _safeDecode(raw);
    if (decoded is! Map) return const [];
    final arr = decoded['schedule'];
    if (arr is! List) return const [];
    final out = <CookingScheduleStep>[];
    for (final e in arr) {
      final m = _asMap(e);
      if (m == null) continue;
      out.add(CookingScheduleStep(
        startMinutes: (m['startMinutes'] ?? 0) is int
            ? m['startMinutes'] as int
            : double.tryParse(m['startMinutes']?.toString() ?? '0')?.round() ?? 0,
        dish: (m['dish'] ?? '').toString(),
        action: (m['action'] ?? '').toString(),
      ));
    }
    return out..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  /// Parse side-dish variants returned as a JSON array.
  List<Dish> parseSideVariants(String raw) {
    final decoded = _safeDecode(raw);
    if (decoded is List) {
      return decoded
          .map(_asMap)
          .whereType<Map>()
          .map((m) => _parseDish(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  // --- helpers ---

  Map<String, dynamic>? _safeMap(String raw) {
    final decoded = _safeDecode(raw);
    return _asMap(decoded);
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  dynamic _safeDecode(String raw) {
    var text = raw.trim();
    // Strip code fences the model sometimes adds despite JSON mode.
    if (text.startsWith('```')) {
      final nl = text.indexOf('\n');
      if (nl > 0) text = text.substring(nl + 1);
      if (text.endsWith('```')) text = text.substring(0, text.length - 3);
      text = text.trim();
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}

/// A single step in a cooking schedule.
class CookingScheduleStep {
  final int startMinutes;
  final String dish;
  final String action;
  const CookingScheduleStep({
    required this.startMinutes,
    required this.dish,
    required this.action,
  });
}
