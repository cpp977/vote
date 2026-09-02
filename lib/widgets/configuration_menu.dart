import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/configuration_controller.dart';
import '../l10n/app_localizations.dart';

/// A popup menu button displayed in the AppBar that provides access to
/// app configuration.
///
/// The menu shows an "Appearance" section header followed by nested
/// entries: one for picking the theme seed color, one for switching
/// between system, light and dark appearance, and one for choosing the
/// app language. Selecting an entry closes the top-level menu and
/// immediately opens the corresponding submenu anchored at the menu
/// button, emulating one additional level of menu nesting (which
/// [PopupMenuButton] does not support natively).
class ConfigurationMenu extends StatelessWidget {
  const ConfigurationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ConfigurationController config = context
        .watch<ConfigurationController>();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.configuration,
      onSelected: (String value) =>
          _handleTopLevelSelection(context, config, value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'appearance',
          enabled: false,
          child: Text(l10n.appearance),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'theme-color',
          child: Row(
            children: [
              const Icon(Icons.palette_outlined, size: 20),
              const SizedBox(width: 12),
              Text(l10n.themeColor),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'dark-view',
          child: Row(
            children: [
              const Icon(Icons.contrast, size: 20),
              const SizedBox(width: 12),
              Text(l10n.view),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'language',
          child: Row(
            children: [
              const Icon(Icons.language, size: 20),
              const SizedBox(width: 12),
              Text(l10n.language),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  /// Handles a selection in the top-level menu by opening the matching
  /// submenu and applying the option chosen inside of it.
  Future<void> _handleTopLevelSelection(
    BuildContext context,
    ConfigurationController config,
    String value,
  ) async {
    if (value == 'theme-color') {
      final String? selectedColorName = await _showSubMenu(
        context,
        _buildColorMenu(context, config),
      );
      if (selectedColorName == null) return;
      final ColorOption colorOption = config.availableColors.firstWhere(
        (ColorOption c) => c.name == selectedColorName,
      );
      await config.setSeedColor(colorOption.color);
    } else if (value == 'dark-view') {
      final String? selectedModeName = await _showSubMenu(
        context,
        _buildDarkViewMenu(context, config.themeMode),
      );
      if (selectedModeName == null) return;
      await config.setThemeMode(
        ThemeMode.values.asNameMap()[selectedModeName] ?? ThemeMode.system,
      );
    } else if (value == 'language') {
      final String? selectedLanguage = await _showSubMenu(
        context,
        _buildLanguageMenu(context, config),
      );
      if (selectedLanguage == null || selectedLanguage == _systemLanguage) {
        await config.setLocale(null);
        return;
      }
      final Locale? selectedLocale = config.availableLocales
          .where((Locale locale) => locale.languageCode == selectedLanguage)
          .firstOrNull;
      await config.setLocale(selectedLocale);
    }
  }

  /// Value used in the language submenu for the "follow the system
  /// language" option.
  static const String _systemLanguage = 'system';

  /// Builds the submenu entries for picking the theme seed color.
  List<PopupMenuEntry<String>> _buildColorMenu(
    BuildContext context,
    ConfigurationController config,
  ) {
    return <PopupMenuEntry<String>>[
      for (final ColorOption colorOption in config.availableColors)
        PopupMenuItem<String>(
          value: colorOption.name,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(backgroundColor: colorOption.color, radius: 12),
              const SizedBox(width: 12),
              Text(colorOption.name),
              if (config.seedColor == colorOption.color) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
    ];
  }

  /// Builds a single selectable submenu entry with a radio-style indicator
  /// reflecting [selected].
  PopupMenuItem<String> _radioEntry(
    BuildContext context, {
    required String value,
    required String label,
    required bool selected,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  /// Builds the submenu entries for switching between system, light and
  /// dark appearance.
  List<PopupMenuEntry<String>> _buildDarkViewMenu(
    BuildContext context,
    ThemeMode currentMode,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return <PopupMenuEntry<String>>[
      _radioEntry(
        context,
        value: 'system',
        label: l10n.themeModeSystem,
        selected: currentMode == ThemeMode.system,
      ),
      _radioEntry(
        context,
        value: 'light',
        label: l10n.themeModeLight,
        selected: currentMode == ThemeMode.light,
      ),
      _radioEntry(
        context,
        value: 'dark',
        label: l10n.themeModeDark,
        selected: currentMode == ThemeMode.dark,
      ),
    ];
  }

  /// Builds the submenu entries for choosing the app language: an option
  /// to follow the system language plus one entry per supported locale.
  List<PopupMenuEntry<String>> _buildLanguageMenu(
    BuildContext context,
    ConfigurationController config,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return <PopupMenuEntry<String>>[
      _radioEntry(
        context,
        value: _systemLanguage,
        label: l10n.languageSystem,
        selected: config.locale == null,
      ),
      for (final Locale locale in config.availableLocales)
        _radioEntry(
          context,
          value: locale.languageCode,
          label: _languageName(l10n, locale),
          selected: config.locale?.languageCode == locale.languageCode,
        ),
    ];
  }

  /// Returns the display name for [locale], preferring the localized
  /// language name when available.
  String _languageName(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'en' => l10n.languageEnglish,
      'de' => l10n.languageGerman,
      _ => locale.toLanguageTag(),
    };
  }

  /// Shows [menu] as a second-level popup anchored at the position of this
  /// widget and returns the selected value, or `null` when dismissed.
  Future<String?> _showSubMenu(
    BuildContext context,
    List<PopupMenuEntry<String>> menu,
  ) async {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final Offset topLeft = renderObject.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      topLeft.dx + renderObject.size.width,
      topLeft.dy + renderObject.size.height,
    );

    return showMenu<String>(context: context, position: position, items: menu);
  }
}
