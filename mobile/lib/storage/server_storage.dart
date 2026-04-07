import 'dart:async';
import 'dart:convert';
import '../api.dart';
import 'app_storage.dart';

class ServerStorageImpl extends AppStorage {
  ServerStorageImpl({String? baseUrl}) {
    if (baseUrl != null) Api.setBaseUrl(baseUrl);
  }

  @override
  StorageMode get mode => StorageMode.server;

  @override
  Future<List<Map<String, dynamic>>> getRecipes(String userId) async {
    try {
      final r = await Api.get('/recipes/user/$userId');
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      }
    } on TimeoutException { /* server unreachable */ }
    catch (_) {}
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getRecipe(String id) async {
    final r = await Api.get('/recipes/$id');
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    return null;
  }

  @override
  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> data) async {
    final r = await Api.post('/recipes/', data);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create recipe: ${r.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> updateRecipe(String id, Map<String, dynamic> data) async {
    final r = await Api.put('/recipes/$id', data);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update recipe: ${r.statusCode}');
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await Api.delete('/recipes/$id');
  }

  @override
  Future<Map<String, dynamic>?> getGroceryList(String userId) async {
    try {
      final r = await Api.get('/groceryList/userID/$userId');
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as List;
        return data.isNotEmpty ? data[0] as Map<String, dynamic> : null;
      }
    } on TimeoutException {} catch (_) {}
    return null;
  }

  @override
  Future<Map<String, dynamic>> createGroceryList(Map<String, dynamic> data) async {
    final r = await Api.post('/groceryList/', data);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create grocery list');
  }

  @override
  Future<void> addGroceryItem(String listId, Map<String, dynamic> item) async {
    await Api.put('/groceryList/$listId', item);
  }

  @override
  Future<void> toggleGroceryItem(String listId, String itemName) async {
    await Api.patch('/groceryList/$listId/${Uri.encodeComponent(itemName)}/check');
  }

  @override
  Future<void> removeGroceryItem(String listId, String itemName) async {
    await Api.delete('/groceryList/$listId/${Uri.encodeComponent(itemName)}');
  }

  @override
  Future<List<Map<String, dynamic>>> getDayMeals(String userId, String date) async {
    try {
      final r = await Api.get('/mealPlans/$date/$userId');
      if (r.statusCode != 200) return [];
      final plans = jsonDecode(r.body) as List;
      final results = await Future.wait(
        plans.map((p) async {
          try {
            final rr = await Api.get('/recipes/${p['recipe_id']}');
            if (rr.statusCode == 200) {
              final recipe = jsonDecode(rr.body) as Map<String, dynamic>;
              return {...recipe, 'mealPlanId': p['_id']};
            }
          } catch (_) {}
          return null;
        }),
      );
      return results.whereType<Map<String, dynamic>>().toList();
    } on TimeoutException {} catch (_) {}
    return [];
  }

  @override
  Future<Map<String, dynamic>> addMealPlan(String userId, String date, String recipeId, Map<String, dynamic> recipeData) async {
    final r = await Api.post('/mealPlans/Create/$date/$userId/$recipeId', {});
    if (r.statusCode == 200) {
      final plan = jsonDecode(r.body) as Map<String, dynamic>;
      return {...recipeData, 'mealPlanId': plan['_id']};
    }
    throw Exception('Failed to add meal plan');
  }

  @override
  Future<void> deleteMealPlan(String id) async {
    await Api.delete('/mealPlans/Delete/$id');
  }
}
