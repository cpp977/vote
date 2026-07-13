import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import 'user_details_dialog.dart';

/// Avatar button that opens a popup menu with the account-details dialog and
/// the logout action. Shared by the top-level pages (questions list and the
/// user's own submissions) so the menu behaviour stays identical everywhere.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authController = context.watch<AuthController>();

    return PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          authController.username?.substring(0, 1).toUpperCase() ??
              l10n.userInitialFallback,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onSelected: (value) async {
        if (value == 'logout') {
          await context.read<AuthController>().logout();
        } else if (value == 'details') {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => UserDetailsDialog(
              authController: context.read<AuthController>(),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            authController.username ?? l10n.userMenuName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Text(l10n.userDetails),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout),
              const SizedBox(width: 8),
              Text(l10n.logout),
            ],
          ),
        ),
      ],
    );
  }
}
