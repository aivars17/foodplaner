import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'config/app_config.dart';
import 'local/document_store.dart';
import '../core/network/ollama_client.dart';
import '../core/network/sync_client.dart';
import '../domain/models/dish.dart';
import '../domain/models/household.dart';
import '../domain/models/meal_plan.dart';
import '../domain/models/shopping_list.dart';
import '../domain/services/ai_parser.dart';
import '../domain/services/coverage_service.dart';
import '../domain/services/prompt_builder.dart';
import '../domain/services/shopping_list_service.dart';

/// The central application state. Holds the in-memory mirror of the document
/// store and orchestrates AI generation, coverage, shopping-list building and
/// sync. Injected with [LocalDocumentStore], [SyncClient] and [AiClient] so it
/// can be driven in tests without platform I/O.
class AppStore extends ChangeNotifier {
  final LocalDocumentStore _docs;
  final SyncClient? _sync;
  final AiClient? _ai;
  final AppConfig config;
  final CoverageService coverage = const CoverageService();
  final ShoppingListService shopping = const ShoppingListService();
  final PromptBuilder prompts = const PromptBuilder();
  final AiParser parser = AiParser();
  final Uuid _uuid = const Uuid();

  HouseholdSettings? household;
  List<MealPlan> plans = [];
  MealPlan? currentPlan;
  ShoppingList? currentShoppingList;

  /// Set to true while an async operation (AI/sync) is in flight.
  bool busy = false;
  String? lastError;

  AppStore({
    required LocalDocumentStore docs,
    required AppConfig config,
    SyncClient? sync,
    AiClient? ai,
  })  : _docs = docs,
        _sync = sync,
        _ai = ai,
        config = config;

  MealPlan? get activePlan => currentPlan;

  Future<void> load() async {
    final settings = _docs.get('settings', 'default');
    if (settings != null) {
      household = HouseholdSettings.fromJson(settings.data);
    } else {
      household = const HouseholdSettings(updatedAt: '0', version: 0);
    }
    plans = _docs
        .allOfType('plans')
        .map((e) => MealPlan.fromJson(e.data))
        .toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    final current = plans.firstWhereOrNull((p) => p.isCurrent);
    currentPlan = current ?? (plans.isEmpty ? null : plans.first);
    if (currentPlan != null) {
      final sl = _docs.get('shopping_lists', currentPlan!.id);
      if (sl != null) currentShoppingList = ShoppingList.fromJson(sl.data);
    }
    notifyListeners();
  }

  Future<void> saveHousehold(HouseholdSettings h) async {
    household = h;
    await _persist('settings', h);
    notifyListeners();
  }

  /// Generate a fresh weekly plan via AI and make it the active plan.
  Future<MealPlan> generateWeeklyPlan({
    int days = 7,
    List<String> mealTypes = const ['breakfast', 'lunch', 'dinner'],
  }) async {
    _begin();
    try {
      if (_ai == null) throw const StateError('AI nekonfigūruotas');
      final p = prompts.mealPlan(
        settings: household ?? const HouseholdSettings(updatedAt: '0', version: 0),
        days: days,
        mealTypes: mealTypes,
      );
      final raw = await _ai!.generate(p);
      var plan = parser.parseMealPlan(raw);
      // Confirm all meals so the shopping list can be built.
      plan = plan.copyWith(
        meals:
            plan.meals.map((m) => m.copyWith(confirmed: true)).toList(),
        updatedAt: _now(),
      );
      plans = [plan, ...plans];
      currentPlan = plan;
      await _persist('plans', plan);
      notifyListeners();
      return plan;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _end();
    }
  }

  /// Confirm (or unconfirm) a single meal slot.
  Future<void> toggleMealConfirmed(
      int dayOfWeek, String mealType, bool confirmed) async {
    final plan = currentPlan;
    if (plan == null) return;
    final updated = plan.copyWith(
      meals: plan.meals.map((m) {
        if (m.dayOfWeek == dayOfWeek && m.mealType == mealType) {
          return m.copyWith(confirmed: confirmed, updatedAt: _now());
        }
        return m;
      }).toList(),
      updatedAt: _now(),
    );
    currentPlan = updated;
    await _persist('plans', updated);
    notifyListeners();
  }

  /// The "plan for the remaining family members" flow: generate a dish for the
  /// still-uncovered people in this slot and add it to the meal.
  Future<Dish> generateForRemaining(Meal meal) async {
    final plan = currentPlan;
    final h =
        household ?? const HouseholdSettings(updatedAt: '0', version: 0);
    if (_ai == null) throw const StateError('AI nekonfigūruotas');
    _begin();
    try {
      final covers =
          coverage.analyze(meal, h.memberCount).remainingCovers;
      if (covers <= 0) {
        throw const StateError('Šis valgis jau uždengtas visai šeimai');
      }
      final p = prompts.dishForRemaining(
        settings: h,
        dayOfWeek: meal.dayOfWeek,
        mealType: meal.mealType,
        covers: covers,
      );
      final raw = await _ai!.generate(p);
      final dish = parser.parseDish(raw);
      final updatedMeal =
          meal.copyWith(dishes: [...meal.dishes, dish], updatedAt: _now());
      final updatedPlan = plan!.copyWith(
        meals:
            plan!.meals.map((m) => m.id == meal.id ? updatedMeal : m).toList(),
        updatedAt: _now(),
      );
      currentPlan = updatedPlan;
      await _persist('plans', updatedPlan);
      notifyListeners();
      return dish;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _end();
    }
  }

  /// Build the shopping list from the active plan's confirmed dishes.
  Future<ShoppingList> buildShoppingList() async {
    final plan = currentPlan;
    final h = household;
    final items = shopping.build(
      confirmedMeals: plan?.confirmedMeals() ?? const [],
      onHand: h?.onHand ?? const [],
    );
    final list = ShoppingList(
      id: plan?.id ?? _uuid.v4(),
      planId: plan?.id ?? '',
      items: items,
      updatedAt: _now(),
      version: 1,
    );
    currentShoppingList = list;
    if (plan != null) {
      await _persist('shopping_lists', list);
    }
    notifyListeners();
    return list;
  }

  /// Run an arbitrary prompt through the configured AI (used for ad-hoc flows
  /// like the cooking schedule). Returns the raw model text.
  Future<String> runPrompt(Prompt p) async {
    if (_ai == null) throw const StateError('AI nekonfigūruotas');
    return _ai!.generate(p);
  }

  Future<void> syncNow() async {
    final change = _docs.lastChange();
    if (change == null || _sync == null) return;
    final entity = _docs.get(change.type, change.id);
    await _sync!.push(change, entity: entity);
  }

  /// Apply a remote change coming from the sync server. The full body arrives
  /// in the change itself (the server carries it on upserts).
  void applyRemoteChange(DocChange c) {
    if (c.op == 'delete') {
      _docs.delete(DocEntity(
        type: c.type,
        id: c.id,
        updatedAt: c.updatedAt,
        version: c.version,
      ));
    } else if (c.data.isNotEmpty) {
      _docs.upsert(DocEntity(
        type: c.type,
        id: c.id,
        data: c.data,
        updatedAt: c.updatedAt,
        version: c.version,
      ));
    }
    load();
  }

  // --- helpers ---

  Future<void> _persist(String type, dynamic obj) async {
    final json = obj.toJson();
    _docs.upsert(DocEntity(
      type: type,
      id: json['id']?.toString() ?? _uuid.v4(),
      data: json,
      updatedAt: json['updatedAt']?.toString() ?? _now(),
      version: (json['version'] as int?) ?? 1,
    ));
    await _docs.save();
  }

  void _begin() {
    busy = true;
    lastError = null;
    notifyListeners();
  }

  void _end() {
    busy = false;
    notifyListeners();
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}

// Minimal helpers so we don't depend on the `collection` package.
extension _ListExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
