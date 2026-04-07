import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _key = 'mise_theme';
  static final notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = _fromString(prefs.getString(_key));
  }

  static Future<void> set(ThemeMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  static ThemeMode _fromString(String? s) => switch (s) {
    'light' => ThemeMode.light,
    'dark'  => ThemeMode.dark,
    _       => ThemeMode.system,
  };

  static String _toString(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark  => 'dark',
    _               => 'system',
  };
}
