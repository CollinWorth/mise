import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultPantry = [
  'salt', 'pepper', 'black pepper', 'olive oil', 'vegetable oil', 'canola oil',
  'sugar', 'brown sugar', 'flour', 'all purpose flour', 'bread flour',
  'baking powder', 'baking soda', 'butter', 'water', 'garlic', 'onion',
  'vanilla extract', 'cooking spray',
];

class PantryService {
  static const _key = 'mise_pantry';

  static Future<List<String>> get() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      await save(_defaultPantry);
      return List.from(_defaultPantry);
    }
    return (jsonDecode(raw) as List).cast<String>();
  }

  static Future<void> save(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<void> add(String item) async {
    final list = await get();
    final normalized = item.trim().toLowerCase();
    if (!list.contains(normalized)) {
      list.add(normalized);
      await save(list);
    }
  }

  static Future<void> remove(String item) async {
    final list = await get();
    list.remove(item.trim().toLowerCase());
    await save(list);
  }

  static Future<void> resetToDefaults() async {
    await save(List.from(_defaultPantry));
  }

  static bool matches(String ingredientName, List<String> pantry) {
    final lower = ingredientName.toLowerCase();
    return pantry.any((p) => lower == p || lower.contains(p));
  }
}
