import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage.dart';
import 'server_storage.dart';

enum StorageMode { local, server, cloud }

abstract class AppStorage {
  StorageMode get mode;
  bool get supportsImport => mode == StorageMode.server;

  // Recipes
  Future<List<Map<String, dynamic>>> getRecipes(String userId);
  Future<Map<String, dynamic>?> getRecipe(String id);
  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateRecipe(String id, Map<String, dynamic> data);
  Future<void> deleteRecipe(String id);

  // Grocery
  Future<Map<String, dynamic>?> getGroceryList(String userId);
  Future<Map<String, dynamic>> createGroceryList(Map<String, dynamic> data);
  Future<void> addGroceryItem(String listId, Map<String, dynamic> item);
  Future<void> toggleGroceryItem(String listId, String itemName);
  Future<void> removeGroceryItem(String listId, String itemName);
  Future<void> clearGroceryItems(String listId, {bool checkedOnly = false});

  // Meal plans — returns merged {recipe fields + mealPlanId}
  Future<List<Map<String, dynamic>>> getDayMeals(String userId, String date);
  Future<Map<String, dynamic>> addMealPlan(String userId, String date, String recipeId, Map<String, dynamic> recipeData, {int multiplier = 1});
  Future<void> deleteMealPlan(String id);
}

// Global singleton accessor
class Store {
  static AppStorage? _instance;
  static AppStorage get i {
    assert(_instance != null, 'Store not initialized — call Store.init() in main()');
    return _instance ?? ServerStorageImpl();
  }
  static bool get isReady => _instance != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('storage_mode');
    if (modeStr == null) return; // not yet configured

    if (modeStr == 'local') {
      _instance = LocalStorageImpl();
    } else if (modeStr == 'server') {
      final url = prefs.getString('server_url');
      _instance = ServerStorageImpl(baseUrl: url);
    }
    // cloud: TBD
  }

  static void setLocal() {
    _instance = LocalStorageImpl();
  }

  static void setServer({String? baseUrl}) {
    _instance = ServerStorageImpl(baseUrl: baseUrl);
  }

  static Future<void> saveMode(StorageMode mode, {String? serverUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storage_mode', mode.name);
    if (serverUrl != null) await prefs.setString('server_url', serverUrl);
  }

  static Future<StorageMode?> getSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('storage_mode');
    if (s == null) return null;
    return StorageMode.values.firstWhere((m) => m.name == s, orElse: () => StorageMode.server);
  }
}
