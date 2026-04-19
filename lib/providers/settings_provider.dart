import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _textScaleKey = 'text_scale_factor';

  ThemeMode _themeMode = ThemeMode.light;
  double _textScaleFactor = 1.0;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0; // 0 = light, 1 = dark
      _themeMode = themeIndex == 1 ? ThemeMode.dark : ThemeMode.light;

      final textScale = prefs.getDouble(_textScaleKey) ?? 1.0;
      _textScaleFactor = textScale.clamp(0.8, 1.5);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // If loading fails, use defaults
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = mode == ThemeMode.dark ? 1 : 0;
      await prefs.setInt(_themeKey, themeIndex);
    } catch (e) {
      // Silently fail if saving fails
    }
  }

  Future<void> _saveTextScaleFactor(double scale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, scale);
    } catch (e) {
      // Silently fail if saving fails
    }
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveThemeMode(_themeMode);
    notifyListeners();
  }

  void setTextScaleFactor(double scale) {
    _textScaleFactor = scale.clamp(0.8, 1.5);
    _saveTextScaleFactor(_textScaleFactor);
    notifyListeners();
  }
}