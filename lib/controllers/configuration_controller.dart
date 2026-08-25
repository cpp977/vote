import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// Available theme seed colors for the app's Material 3 color scheme.
class ColorOption {
  /// Human-readable name of the color.
  final String name;

  /// The seed [Color] used to generate the Material 3 [ColorScheme].
  final Color color;

  const ColorOption(this.name, this.color);
}

/// Controller for managing runtime configuration.
///
/// Holds the current theme seed color, the desired [ThemeMode] and the
/// selected app [Locale], and notifies listeners when any of them changes.
/// A `null` locale means the app language is inferred from the system
/// locale. All settings are persisted via [shared_preferences] so they
/// survive app restarts.
class ConfigurationController extends ChangeNotifier {
  static const String _seedColorKey = 'theme_seed_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';

  Color _seedColor;
  ThemeMode _themeMode;
  Locale? _locale;

  /// The app-wide configuration instance registered via
  /// [registerAsAppConfiguration], or `null` before registration.
  static ConfigurationController? _registered;

  /// The two-character language code that backend requests should use: the
  /// user-selected app language when set, otherwise the language of the
  /// system locale.
  ///
  /// Static so that classes outside the widget tree (e.g. services) can
  /// resolve it without access to the provider tree. Uses [PlatformDispatcher]
  /// directly instead of [WidgetsBinding] so it is also callable before the
  /// binding is initialized (early startup, plain unit tests).
  static String get currentLanguageCode {
    final Locale? selected = _registered?.locale;
    if (selected != null) {
      return selected.languageCode;
    }
    return PlatformDispatcher.instance.locale.languageCode;
  }

  /// Registers this instance as the app-wide configuration so that
  /// [currentLanguageCode] reflects the user's language choice everywhere.
  void registerAsAppConfiguration() => _registered = this;

  /// Removes the app-wide registration. Only intended for tests to keep
  /// them independent of each other.
  @visibleForTesting
  static void resetAppConfiguration() => _registered = null;

  /// The current seed color used to generate the Material 3 [ColorScheme].
  Color get seedColor => _seedColor;

  /// The desired theme mode (system, light or dark).
  ThemeMode get themeMode => _themeMode;

  /// The user-selected app language, or `null` when it should be inferred
  /// from the system locale.
  Locale? get locale => _locale;

  /// The languages the user can pick from, derived from the locales the
  /// app ships translations for.
  List<Locale> get availableLocales => AppLocalizations.supportedLocales;

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
    Locale? initialLocale,
  }) : _seedColor = initialSeedColor ?? Colors.deepPurple,
       _themeMode = initialThemeMode ?? ThemeMode.system,
       _locale = initialLocale;

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

  /// Changes the app language, notifies listeners, and persists the
  /// selection. Passing `null` resets the language to be inferred from the
  /// system locale.
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    await _persistLocale(locale);
  }

  /// Loads the previously saved seed color, theme mode and language from
  /// persistent storage and notifies listeners if any of them changed.
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

    final String? languageCode = prefs.getString(_localeKey);
    final Locale? savedLocale = languageCode == null
        ? null
        : availableLocales
              .where((Locale l) => l.languageCode == languageCode)
              .firstOrNull;
    if (savedLocale != null && savedLocale != _locale) {
      _locale = savedLocale;
      changed = true;
    } else if (languageCode != null && savedLocale == null) {
      // Remove stale entries, e.g. from languages that are no longer
      // supported by the app.
      await prefs.remove(_localeKey);
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

  Future<void> _persistLocale(Locale? locale) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }
}
