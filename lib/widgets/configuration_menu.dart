import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/configuration_controller.dart';
import '../l10n/app_localizations.dart';

/// A popup menu button displayed in the AppBar that provides access to
/// app configuration.
///
/// The menu shows an "Appearance" section header followed by theme
/// color options with a color swatch and checkmark for the currently
/// selected color.
class ConfigurationMenu extends StatelessWidget {
  const ConfigurationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = context.watch<ConfigurationController>();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.configuration,
      onSelected: (value) {
        final colorOption = config.availableColors.firstWhere(
          (c) => c.name == value,
        );
        config.setSeedColor(colorOption.color);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'appearance',
          enabled: false,
          child: Text(l10n.appearance),
        ),
        for (final colorOption in config.availableColors)
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
      ],
    );
  }
}
