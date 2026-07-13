import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Navigation drawer shared by the top-level pages.
///
/// Contains exactly the two primary destinations required by the app:
///  - `questions`   – the public list of (approved) questions.
///  - `submissions` – the current user's own question submissions.
///
/// [selectedRoute] highlights the destination the user is currently viewing and
/// [onSelect] is invoked (with the destination key) when a tile is tapped.
class AppDrawer extends StatelessWidget {
  final String selectedRoute;
  final void Function(BuildContext context, String route) onSelect;

  const AppDrawer({
    super.key,
    required this.selectedRoute,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.question_answer_outlined),
            title: Text(l10n.questions),
            selected: selectedRoute == 'questions',
            onTap: () {
              // Always close the drawer first; only navigate when the tapped
              // destination differs from the current one.
              Navigator.pop(context);
              if (selectedRoute != 'questions') {
                onSelect(context, 'questions');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.outbox_outlined),
            title: Text(l10n.mySubmissions),
            selected: selectedRoute == 'submissions',
            onTap: () {
              Navigator.pop(context);
              if (selectedRoute != 'submissions') {
                onSelect(context, 'submissions');
              }
            },
          ),
        ],
      ),
    );
  }
}
