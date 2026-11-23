import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/submission_service.dart';

/// Shows the dialog that proposes a new answer option for an existing question.
///
/// The dialog collects a single answer text and posts it via
/// [SubmissionService.submitAnswerOption], which stores the proposal as a
/// `pending` submission server-side. An administrator has to approve it (the
/// option is then appended to the question and becomes votable) or reject it.
///
/// On success a confirmation snackbar is shown and [onSubmitted] is invoked —
/// the question detail page uses it to refresh. A `401` response logs the user
/// out and routes them to the login page.
///
/// [submissionService] can be replaced in tests; production callers use the
/// default [SubmissionService].
Future<void> showSuggestAnswerDialog(
  BuildContext context, {
  required int questionId,
  required String questionText,
  VoidCallback? onSubmitted,
  SubmissionService? submissionService,
}) async {
  if (!context.mounted) return;
  final authController = context.read<AuthController>();
  // Captured up front so the snackbar can be shown after the dialog closes
  // without touching this context across the async gap.
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _SuggestAnswerDialog(
      questionId: questionId,
      questionText: questionText,
      authController: authController,
      submissionService: submissionService ?? SubmissionService(),
      scaffoldMessenger: scaffoldMessenger,
      onSubmitted: onSubmitted,
    ),
  );
}

/// Dialog that collects and submits a new answer option for a question.
///
/// A [StatefulWidget] rather than a `StatefulBuilder` inside the route builder,
/// so the text controller lives as long as the dialog and is disposed with it.
class _SuggestAnswerDialog extends StatefulWidget {
  const _SuggestAnswerDialog({
    required this.questionId,
    required this.questionText,
    required this.authController,
    required this.submissionService,
    required this.scaffoldMessenger,
    this.onSubmitted,
  });

  final int questionId;

  /// Text of the question the option is proposed for, shown read-only at the
  /// top of the dialog so the user knows what they are answering.
  final String questionText;

  final AuthController authController;

  final SubmissionService submissionService;

  /// Messenger of the page behind the dialog, used for the success snackbar.
  final ScaffoldMessengerState scaffoldMessenger;

  final VoidCallback? onSubmitted;

  @override
  State<_SuggestAnswerDialog> createState() => _SuggestAnswerDialogState();
}

class _SuggestAnswerDialogState extends State<_SuggestAnswerDialog> {
  final TextEditingController _answerController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  /// Posts the suggestion and reports the outcome.
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.submissionService.submitAnswerOption(
        questionId: widget.questionId,
        text: _answerController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.answerSubmissionCreated),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSubmitted?.call();
    } on SubmissionException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Token refresh failed – the user has to log in again.
        Navigator.of(context).pop();
        await widget.authController.logout(showLoginPage: true);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = l10n.answerSubmissionFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.newAnswerSuggestionTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // The question the option is proposed for, read-only.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.questionLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.questionText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _answerController,
                decoration: InputDecoration(
                  labelText: l10n.suggestedAnswerLabel,
                  hintText: l10n.suggestedAnswerHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.requiredField
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.submit),
        ),
      ],
    );
  }
}
