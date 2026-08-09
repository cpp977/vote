import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/navigation_service.dart';
import 'user_details_dialog.dart';

/// Avatar button that opens a popup menu with the account-details dialog,
/// the logout action, or a login navigation when no user is authenticated.
/// Shared by the top-level pages (questions list and the user's own
/// submissions) so the menu behaviour stays identical everywhere.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authController = context.watch<AuthController>();
    final isAuthenticated = authController.isAuthenticated;

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
        } else if (value == 'changeUser') {
          final confirmed = await _showChangeUserDialog(context);
          if (confirmed == true && context.mounted) {
            await context.read<AuthController>().logout();
            NavigationService.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/login', (r) => false);
          }
        } else if (value == 'deleteAccount') {
          final confirmed = await _showDeleteAccountDialog(context);
          if (confirmed == true && context.mounted) {
            debugPrint(
              'User confirmed delete account, calling deleteAccount()',
            );
            final success = await context
                .read<AuthController>()
                .deleteAccount();
            debugPrint('deleteAccount returned: $success');
            if (success && context.mounted) {
              await NavigationService.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/login', (r) => false);
            }
          }
        } else if (value == 'details') {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => UserDetailsDialog(
              authController: context.read<AuthController>(),
            ),
          );
        } else if (value == 'login') {
          Navigator.pushNamed(context, '/login');
        }
      },
      itemBuilder: (context) {
        if (!isAuthenticated) {
          return [
            PopupMenuItem(
              value: 'login',
              child: Row(
                children: [
                  const Icon(Icons.login),
                  const SizedBox(width: 8),
                  Text(l10n.login),
                ],
              ),
            ),
          ];
        }
        return [
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
            value: 'changeUser',
            child: Row(
              children: [
                const Icon(Icons.swap_horiz),
                const SizedBox(width: 8),
                Text(l10n.changeUser),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'deleteAccount',
            child: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  l10n.deleteAccount,
                  style: const TextStyle(color: Colors.red),
                ),
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
        ];
      },
    );
  }

  /// Shows a confirmation dialog asking the user whether they want to
  /// switch to a different account. Returns `true` if confirmed,
  /// `false` if dismissed, and `null` if the widget is unmounted.
  Future<bool?> _showChangeUserDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.changeUser),
        content: Text(l10n.changeUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog asking the user whether they want to
  /// delete their account. Returns `true` if confirmed,
  /// `false` if dismissed, and `null` if the widget is unmounted.
  Future<bool?> _showDeleteAccountDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.deleteAccountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAccountPositive),
          ),
        ],
      ),
    );
  }
}
