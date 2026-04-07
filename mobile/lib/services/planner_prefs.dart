import 'package:shared_preferences/shared_preferences.dart';

class PlannerPrefs {
  static const _viewKey = 'planner_view';
  static const _weekStartKey = 'planner_week_start';

  static Future<bool> isWeekView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewKey) == 'week';
  }

  static Future<void> setWeekView(bool week) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewKey, week ? 'week' : 'day');
  }

  // 0 = Sunday, 1 = Monday
  static Future<int> weekStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weekStartKey) ?? 0;
  }

  static Future<void> setWeekStart(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weekStartKey, day);
  }
}
