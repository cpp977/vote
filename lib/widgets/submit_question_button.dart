import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import 'create_question_dialog.dart';

/// Floating action button that opens the submit-question dialog.
///
/// Used by the question list and by `My Submissions` so both offer the same
/// entry point. Submitting requires an authenticated user – the category
/// choices come from the user's session and the backend rejects anonymous
/// submissions – so guests are asked to sign in first.
class SubmitQuestionButton extends StatelessWidget {
  /// Called after a question was submitted successfully; the submissions page
  /// uses it to reload its list.
  final VoidCallback? onSubmitted;

  const SubmitQuestionButton({super.key, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FloatingActionButton.extended(
      onPressed: () => _open(context),
      icon: const Icon(Icons.add),
      label: Text(l10n.createQuestion),
    );
  }

  /// Opens the dialog for signed-in users and the sign-in prompt for guests.
  Future<void> _open(BuildContext context) async {
    final authController = context.read<AuthController>();
    if (!authController.isAuthenticated) {
      await _promptSignIn(context, authController);
      return;
    }
    await showCreateQuestionDialog(context, onSubmitted: onSubmitted);
  }

  /// Asks a guest to sign in before submitting a question. Confirming routes
  /// them to the login page via [AuthController.logout], the app's established
  /// way of making `AuthGate` show the login screen.
  Future<void> _promptSignIn(
    BuildContext context,
    AuthController authController,
  ) async {
    final l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signInToSubmitQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signIn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await authController.logout(showLoginPage: true);
  }
}
