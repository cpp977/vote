import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/configuration_controller.dart';
import '../l10n/app_localizations.dart';

/// A popup menu button displayed in the AppBar that provides access to
/// app configuration.
///
/// The menu shows an "Appearance" section header followed by two nested
/// entries: one for picking the theme seed color and one for switching
/// between system, light and dark appearance. Selecting an entry closes
/// the top-level menu and immediately opens the corresponding submenu
/// anchored at the menu button, emulating one additional level of menu
/// nesting (which [PopupMenuButton] does not support natively).
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
              Text(l10n.darkView),
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
    }
  }

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

  /// Builds the submenu entries for switching between system, light and
  /// dark appearance.
  List<PopupMenuEntry<String>> _buildDarkViewMenu(
    BuildContext context,
    ThemeMode currentMode,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    PopupMenuItem<String> entry(String value, String label) {
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentMode.name == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: currentMode.name == value
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );
    }

    return <PopupMenuEntry<String>>[
      entry('system', l10n.themeModeSystem),
      entry('light', l10n.themeModeLight),
      entry('dark', l10n.themeModeDark),
    ];
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
