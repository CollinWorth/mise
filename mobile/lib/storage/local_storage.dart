import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'app_storage.dart';

const _uuid = Uuid();

Map<String, dynamic> _toStringMap(dynamic m) {
  if (m is Map<String, dynamic>) return m;
  if (m is Map) return m.map((k, v) => MapEntry(k.toString(), v is Map ? _toStringMap(v) : v));
  return {};
}

class LocalStorageImpl extends AppStorage {
  @override
  StorageMode get mode => StorageMode.local;

  @override
  bool get supportsImport => false;

  Box get _recipes => Hive.box('mise_recipes');
  Box get _grocery => Hive.box('mise_grocery');
  Box get _mealPlans => Hive.box('mise_mealplans');

  @override
  Future<List<Map<String, dynamic>>> getRecipes(String userId) async {
    return _recipes.values.map((v) => _toStringMap(v)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getRecipe(String id) async {
    final v = _recipes.get(id);
    return v != null ? _toStringMap(v) : null;
  }

  @override
  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final recipe = {...data, '_id': id};
    await _recipes.put(id, recipe);
    return recipe;
  }

  @override
  Future<Map<String, dynamic>> updateRecipe(String id, Map<String, dynamic> data) async {
    final recipe = {...data, '_id': id};
    await _recipes.put(id, recipe);
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await _recipes.delete(id);
  }

  @override
  Future<Map<String, dynamic>?> getGroceryList(String userId) async {
    final v = _grocery.get('list');
    return v != null ? _toStringMap(v) : null;
  }

  @override
  Future<Map<String, dynamic>> createGroceryList(Map<String, dynamic> data) async {
    final list = {...data, '_id': 'local_list', 'items': []};
    await _grocery.put('list', list);
    return list;
  }

  @override
  Future<void> addGroceryItem(String listId, Map<String, dynamic> item) async {
    final raw = _grocery.get('list');
    if (raw == null) return;
    final list = _toStringMap(raw);
    final items = (list['items'] as List? ?? []).map(_toStringMap).toList();
    items.add(item);
    list['items'] = items;
    await _grocery.put('list', list);
  }

  @override
  Future<void> toggleGroceryItem(String listId, String itemName) async {
    final raw = _grocery.get('list');
    if (raw == null) return;
    final list = _toStringMap(raw);
    final items = (list['items'] as List? ?? []).map(_toStringMap).toList();
    for (final item in items) {
      if (item['name'] == itemName) {
        item['checked'] = !(item['checked'] as bool? ?? false);
      }
    }
    list['items'] = items;
    await _grocery.put('list', list);
  }

  @override
  Future<void> removeGroceryItem(String listId, String itemName) async {
    final raw = _grocery.get('list');
    if (raw == null) return;
    final list = _toStringMap(raw);
    final items = (list['items'] as List? ?? []).map(_toStringMap).toList();
    items.removeWhere((i) => i['name'] == itemName);
    list['items'] = items;
    await _grocery.put('list', list);
  }

  @override
  Future<List<Map<String, dynamic>>> getDayMeals(String userId, String date) async {
    return _mealPlans.values
        .map(_toStringMap)
        .where((m) => m['date'] == date)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> addMealPlan(String userId, String date, String recipeId, Map<String, dynamic> recipeData) async {
    final id = _uuid.v4();
    final plan = {
      '_id': id,
      'mealPlanId': id,
      'date': date,
      'recipe_id': recipeId,
      ...recipeData,
    };
    await _mealPlans.put(id, plan);
    return plan;
  }

  @override
  Future<void> deleteMealPlan(String id) async {
    await _mealPlans.delete(id);
  }
}
