import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/configuration_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/submission_service.dart';

/// Maximum number of answer options a submission may carry. Mirrors the
/// backend limit enforced for `POST /questions/submissions`.
const int kMaxAnswerOptions = 50;

/// Shows the dialog that submits a new question for review.
///
/// The dialog collects the question text, a category and at least one answer
/// option and posts them via [SubmissionService.submitQuestion], which stores
/// the question as a `pending` submission server-side. Guests cannot submit
/// (the category list is only available to authenticated users), so callers
/// should check [AuthController.isAuthenticated] first — see
/// `SubmitQuestionButton`, which does that for them.
///
/// On success a confirmation snackbar is shown and [onSubmitted] is invoked —
/// the submissions page uses it to reload its list. A `401` response logs the
/// user out and routes them to the login page.
///
/// [submissionService] can be replaced in tests; production callers use the
/// default [SubmissionService].
Future<void> showCreateQuestionDialog(
  BuildContext context, {
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
    builder: (dialogContext) => _CreateQuestionDialog(
      categories: authController.categories,
      authController: authController,
      submissionService: submissionService ?? SubmissionService(),
      scaffoldMessenger: scaffoldMessenger,
      onSubmitted: onSubmitted,
    ),
  );
}

/// Dialog that collects and submits a new question.
///
/// A [StatefulWidget] rather than a `StatefulBuilder` inside the route builder,
/// so the text controllers live as long as the dialog and are disposed with it.
/// Disposing them right after `Navigator.pop` would tear down controllers the
/// still-animating route continues to read from.
class _CreateQuestionDialog extends StatefulWidget {
  const _CreateQuestionDialog({
    required this.categories,
    required this.authController,
    required this.submissionService,
    required this.scaffoldMessenger,
    this.onSubmitted,
  });

  /// Category id -> name mapping of the submitting user.
  final Map<int, String> categories;

  final AuthController authController;

  final SubmissionService submissionService;

  /// Messenger of the page behind the dialog, used for the success snackbar.
  final ScaffoldMessengerState scaffoldMessenger;

  final VoidCallback? onSubmitted;

  @override
  State<_CreateQuestionDialog> createState() => _CreateQuestionDialogState();
}

class _CreateQuestionDialogState extends State<_CreateQuestionDialog> {
  final TextEditingController _questionController = TextEditingController();

  /// One controller per answer option. A submission must carry at least one
  /// non-empty option, so we start with two empty fields (a typical poll needs
  /// at least two choices).
  final List<TextEditingController> _answerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int? _selectedCategoryId;
  String? _errorText;
  bool _isSubmitting = false;

  /// Categories sorted by name for a stable display order.
  List<MapEntry<int, String>> get _sortedCategories {
    return widget.categories.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Posts the question and reports the outcome.
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    // At least one non-empty answer option is required by the backend;
    // surface a localized error instead of sending an empty submission.
    final options = _answerControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorText = l10n.atLeastOneAnswerOption;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.submissionService.submitQuestion(
        text: _questionController.text.trim(),
        categoryId: _selectedCategoryId!,
        language: _currentLanguageCode(),
        answerOptions: options,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.submissionCreated),
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
        _errorText = l10n.submissionFailed;
      });
    }
  }

  /// Removes the answer option at [index] and frees its controller.
  void _removeAnswerOption(int index) {
    setState(() {
      final removed = _answerControllers.removeAt(index);
      removed.dispose();
    });
  }

  /// Appends an empty answer option.
  void _addAnswerOption() {
    setState(() => _answerControllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.newQuestionTitle),
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
              TextFormField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: l10n.questionTextLabel,
                  hintText: l10n.questionTextHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.requiredField
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: l10n.categoryLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _sortedCategories
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategoryId = value),
                validator: (value) => value == null ? l10n.requiredField : null,
              ),
              if (widget.categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.noCategoriesAvailable,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                l10n.answerOptionsLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._answerControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: l10n.answerOptionLabel(index + 1),
                            hintText: l10n.answerOptionHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      if (_answerControllers.length > 1)
                        IconButton(
                          onPressed: () => _removeAnswerOption(index),
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: l10n.removeAnswerOption,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _answerControllers.length >= kMaxAnswerOptions
                    ? null
                    : _addAnswerOption,
                icon: const Icon(Icons.add),
                label: Text(l10n.addAnswerOption),
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

/// Returns the 2-character language code backend requests should use,
/// constrained to the languages the app actually supports.
String _currentLanguageCode() {
  final code = ConfigurationController.currentLanguageCode;
  return code == 'de' ? 'de' : 'en';
}
