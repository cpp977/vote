import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/launcher_icon_service.dart';

/// A theme seed color the user can pick, paired with its display name.
@immutable
class ColorOption {
  /// Creates a seed color option.
  const ColorOption(this.name, this.color);

  /// Localized display name of the color.
  final String name;

  /// The seed [Color] used to generate the Material 3 [ColorScheme].
  final Color color;
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
  static const String _launcherIconKey = 'launcher_icon';

  Color _seedColor;
  ThemeMode _themeMode;
  Locale? _locale;
  LauncherIcon _launcherIcon;

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

  /// Predefined seed colors the user can pick from, in menu order.
  ///
  /// [l10n] supplies the localized display names; the color themselves are
  /// fixed so a persisted selection keeps working across languages.
  List<ColorOption> colorOptions(AppLocalizations l10n) => <ColorOption>[
    ColorOption(l10n.colorDeepPurple, Colors.deepPurple),
    ColorOption(l10n.colorBlue, Colors.blue),
    ColorOption(l10n.colorTeal, Colors.teal),
    ColorOption(l10n.colorGreen, Colors.green),
    ColorOption(l10n.colorOrange, Colors.orange),
    ColorOption(l10n.colorRed, Colors.red),
    ColorOption(l10n.colorPink, Colors.pink),
    ColorOption(l10n.colorCyan, Colors.cyan),
    ColorOption(l10n.colorIndigo, Colors.indigo),
    ColorOption(l10n.colorAmber, Colors.amber),
  ];

  /// Predefined seed colors the user can pick from.
  List<Color> get availableColors => const <Color>[
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.cyan,
    Colors.indigo,
    Colors.amber,
  ];

  /// The launcher icons the app ships, in the order they are offered.
  ///
  /// Independent of [availableColors]: the home screen icon is its own
  /// setting, so it can stay put while the in-app theme changes.
  List<LauncherIcon> get availableLauncherIcons => LauncherIconService.icons;

  /// Returns the localized display name of the launcher icon with [id].
  ///
  /// The icons share their wording with the theme colors, so the label comes
  /// from the same ARB entries; an unknown id falls back to the id itself,
  /// which is what the icon's resources are named after.
  String iconLabel(AppLocalizations l10n, String id) {
    return switch (id) {
      'deep_purple' => l10n.colorDeepPurple,
      'blue' => l10n.colorBlue,
      'teal' => l10n.colorTeal,
      'green' => l10n.colorGreen,
      'orange' => l10n.colorOrange,
      'red' => l10n.colorRed,
      'pink' => l10n.colorPink,
      'cyan' => l10n.colorCyan,
      'indigo' => l10n.colorIndigo,
      'amber' => l10n.colorAmber,
      _ => id,
    };
  }

  /// The launcher icon currently shown on the home screen.
  LauncherIcon get launcherIcon => _launcherIcon;

  ConfigurationController({
    Color? initialSeedColor,
    ThemeMode? initialThemeMode,
    Locale? initialLocale,
    LauncherIcon? initialLauncherIcon,
  }) : _seedColor = initialSeedColor ?? Colors.deepPurple,
       _themeMode = initialThemeMode ?? ThemeMode.system,
       _locale = initialLocale,
       _launcherIcon = initialLauncherIcon ?? LauncherIconService.defaultIcon;

  /// Changes the theme seed color, notifies listeners, and persists the
  /// selection.
  ///
  /// This only affects the in-app theme: the home screen icon is a separate
  /// setting.
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

  /// Changes the home screen launcher icon, notifies listeners, persists the
  /// selection and hands it to the platform so the icon is swapped.
  ///
  /// This is independent of the theme: picking an icon leaves the seed color
  /// untouched.
  Future<void> setLauncherIcon(LauncherIcon icon) async {
    if (_launcherIcon.id == icon.id) return;
    _launcherIcon = icon;
    notifyListeners();
    await _persistLauncherIcon(icon);
    await LauncherIconService.setLauncherIcon(icon.alias);
  }

  /// Loads the previously saved seed color, theme mode, language and launcher
  /// icon from persistent storage and notifies listeners if any of them
  /// changed.
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

    final String? iconId = prefs.getString(_launcherIconKey);
    final LauncherIcon? savedIcon = iconId == null
        ? null
        : LauncherIconService.iconForId(iconId);
    if (savedIcon != null && savedIcon.id != _launcherIcon.id) {
      _launcherIcon = savedIcon;
      changed = true;
    } else if (iconId != null && savedIcon == null) {
      // An icon that is no longer shipped would otherwise stay selected in
      // the menu while a different one is enabled on the home screen.
      await prefs.remove(_launcherIconKey);
    }

    if (changed) {
      notifyListeners();
    }
    await LauncherIconService.setLauncherIcon(_launcherIcon.alias);
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

  Future<void> _persistLauncherIcon(LauncherIcon icon) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_launcherIconKey, icon.id);
  }
}
