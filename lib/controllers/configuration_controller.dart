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
/// Holds the current theme seed color and notifies listeners when it
/// changes. The selected color is persisted via [shared_preferences] so
/// it survives app restarts.
class ConfigurationController extends ChangeNotifier {
  static const _seedColorKey = 'theme_seed_color';

  Color _seedColor;

  /// The current seed color used to generate the Material 3 [ColorScheme].
  Color get seedColor => _seedColor;

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

  ConfigurationController({Color? initialSeedColor})
    : _seedColor = initialSeedColor ?? Colors.deepPurple;

  /// Changes the theme seed color, notifies listeners, and persists the
  /// selection.
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    await _persistColor(color);
  }

  /// Loads the previously saved seed color from persistent storage.
  Future<void> loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
      notifyListeners();
    }
  }

  Future<void> _persistColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }
}
