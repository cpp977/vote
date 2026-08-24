import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available theme seed colors for the app's Material 3 color scheme.
class ColorOption {
  /// Human-readable name of the color.
  final String name;

  /// The seed [Color] used to generate the Material 3 [ColorScheme].
  final Color color;

  const ColorOption(this.name, this.color);
}

/// Controller for managing runtime theme configuration.
///
/// Holds the current theme seed color and the desired [ThemeMode] and
/// notifies listeners when either changes. Both settings are persisted via
/// [shared_preferences] so they survive app restarts.
class ConfigurationController extends ChangeNotifier {
  static const String _seedColorKey = 'theme_seed_color';
  static const String _themeModeKey = 'theme_mode';

  Color _seedColor;
  ThemeMode _themeMode;

  /// The current seed color used to generate the Material 3 [ColorScheme].
  Color get seedColor => _seedColor;

  /// The desired theme mode (system, light or dark).
  ThemeMode get themeMode => _themeMode;

  /// Predefined seed colors the user can pick from.
  List<ColorOption> get availableColors => const [
    ColorOption('Deep Purple', Colors.deepPurple),
    ColorOption('Blue', Colors.blue),
    ColorOption('Teal', Colors.teal),
    ColorOption('Green', Colors.green),
    ColorOption('Orange', Colors.orange),
    ColorOption('Red', Colors.red),
    ColorOption('Pink', Colors.pink),
    ColorOption('Cyan', Colors.cyan),
    ColorOption('Indigo', Colors.indigo),
    ColorOption('Amber', Colors.amber),
  ];

  ConfigurationController({
    Color? initialSeedColor,
    ThemeMode? initialThemeMode,
  }) : _seedColor = initialSeedColor ?? Colors.deepPurple,
       _themeMode = initialThemeMode ?? ThemeMode.system;

  /// Changes the theme seed color, notifies listeners, and persists the
  /// selection.
  Future<void> setSeedColor(Color color) async {
    if (_seedColor == color) return;
    _seedColor = color;
    notifyListeners();
    await _persistSeedColor(color);
  }

  /// Changes the desired theme mode, notifies listeners, and persists the
  /// selection.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _persistThemeMode(mode);
  }

  /// Loads the previously saved seed color and theme mode from persistent
  /// storage and notifies listeners if either changed.
  Future<void> loadSavedConfiguration() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    bool changed = false;

    final int? colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null && Color(colorValue) != _seedColor) {
      _seedColor = Color(colorValue);
      changed = true;
    }

    final String? modeName = prefs.getString(_themeModeKey);
    final ThemeMode? savedMode = modeName == null
        ? null
        : ThemeMode.values.asNameMap()[modeName];
    if (savedMode != null && savedMode != _themeMode) {
      _themeMode = savedMode;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _persistSeedColor(Color color) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}
