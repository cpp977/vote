import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/launcher_icon_service.dart';

/// Available theme seed colors for the app's Material 3 color scheme.
class ColorOption {
  /// Human-readable name of the color.
  final String name;

  /// The seed [Color] used to generate the Material 3 [ColorScheme].
  final Color color;

  /// The Android launcher icon alias that matches this color best.
  ///
  /// Only three launcher icon assets ship with the app, so several seed
  /// colors share the same alias.
  final String launcherIconAlias;

  const ColorOption(
    this.name,
    this.color, {
    this.launcherIconAlias = LauncherIconService.aliasDeepPurple,
  });
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
  ///
  /// The order also defines the order in which the colors are offered in the
  /// configuration menu, and which color represents each launcher icon in
  /// [availableLauncherIcons].
  List<ColorOption> get availableColors => const <ColorOption>[
    // One launcher icon asset per line: deep purple, blue and teal. They come
    // first so the icon submenu lists them in that order.
    ColorOption(
      'Deep Purple',
      Colors.deepPurple,
      launcherIconAlias: LauncherIconService.aliasDeepPurple,
    ),
    ColorOption(
      'Blue',
      Colors.blue,
      launcherIconAlias: LauncherIconService.aliasBlue,
    ),
    ColorOption(
      'Teal',
      Colors.teal,
      launcherIconAlias: LauncherIconService.aliasTeal,
    ),
    // Colors without a dedicated launcher icon asset reuse the closest match.
    ColorOption(
      'Green',
      Colors.green,
      launcherIconAlias: LauncherIconService.aliasTeal,
    ),
    ColorOption(
      'Orange',
      Colors.orange,
      launcherIconAlias: LauncherIconService.aliasDeepPurple,
    ),
    ColorOption(
      'Red',
      Colors.red,
      launcherIconAlias: LauncherIconService.aliasDeepPurple,
    ),
    ColorOption(
      'Pink',
      Colors.pink,
      launcherIconAlias: LauncherIconService.aliasBlue,
    ),
    ColorOption(
      'Cyan',
      Colors.cyan,
      launcherIconAlias: LauncherIconService.aliasTeal,
    ),
    ColorOption(
      'Indigo',
      Colors.indigo,
      launcherIconAlias: LauncherIconService.aliasBlue,
    ),
    ColorOption(
      'Amber',
      Colors.amber,
      launcherIconAlias: LauncherIconService.aliasDeepPurple,
    ),
  ];

  /// The seed colors that map to a distinct Android launcher icon.
  ///
  /// Derived from [availableColors] by keeping the first entry per alias, so
  /// the list always stays in sync with the color definitions.
  List<ColorOption> get availableLauncherIcons {
    final Map<String, ColorOption> firstPerAlias = <String, ColorOption>{};
    for (final ColorOption option in availableColors) {
      firstPerAlias.putIfAbsent(option.launcherIconAlias, () => option);
    }
    return firstPerAlias.values.toList(growable: false);
  }

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
    await _syncLauncherIcon();
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
    await _syncLauncherIcon();
  }

  /// Synchronizes the Android launcher icon with the current seed color.
  Future<void> _syncLauncherIcon() async {
    await LauncherIconService.setLauncherIcon(activeLauncherIconAlias);
  }

  /// The launcher icon alias that matches the current seed color.
  String get activeLauncherIconAlias =>
      _colorOptionFor(_seedColor).launcherIconAlias;

  /// Looks up the [ColorOption] matching [color], falling back to the first
  /// entry (the default icon) when the color is unknown, e.g. a legacy
  /// persisted value that is no longer offered.
  ColorOption _colorOptionFor(Color color) {
    for (final ColorOption option in availableColors) {
      if (option.color.toARGB32() == color.toARGB32()) return option;
    }
    return availableColors.first;
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
