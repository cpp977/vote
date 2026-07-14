import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/submission_models.dart';
import '../services/submission_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/user_menu_button.dart';

/// Maximum number of answer options a submission may carry. Mirrors the
/// backend limit enforced for `POST /questions/submissions`.
const int kMaxAnswerOptions = 50;

/// The user's own question submissions.
///
/// Lists everything the current user has submitted (pending, approved or
/// rejected) via `GET /questions/mine`. Submissions start out `pending` and are
/// only visible to the public once an administrator approves them. A floating
/// action button opens a dialog to submit a new question together with its
/// answer options, which the backend stores as a `pending` submission through
/// `POST /questions/submissions`.
class MySubmissionsPage extends StatefulWidget {
  /// Called when the user picks a destination from the [AppDrawer]. Supplied by
  /// the composition root so this page never imports the questions page
  /// directly (avoiding a circular dependency).
  final void Function(BuildContext context, String route) onNavigate;

  const MySubmissionsPage({super.key, required this.onNavigate});

  @override
  State<MySubmissionsPage> createState() => _MySubmissionsPageState();
}

class _MySubmissionsPageState extends State<MySubmissionsPage> {
  final SubmissionService _submissionService = SubmissionService();
  List<Submission> _submissions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defer the initial fetch until after the first frame so `AppLocalizations`
    // and `AuthController` are available via the inherited widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSubmissions();
    });
  }

  /// Loads the current user's submissions from the backend.
  Future<void> _loadSubmissions() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final submissions = await _submissionService.getMySubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } on SubmissionException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Token refresh failed – the user has to log in again.
        setState(() => _isLoading = false);
        context.read<AuthController>().logout();
        return;
      }
      setState(() {
        _errorMessage = l10n.submissionLoadFailed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.submissionLoadFailed;
        _isLoading = false;
      });
    }
  }

  /// Opens the "submit a new question" dialog and, on success, refreshes the
  /// list.
  Future<void> _showCreateDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final authController = context.read<AuthController>();
    final categories = authController.categories;

    final sortedCategories = categories.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final textController = TextEditingController();
    final minAgeController = TextEditingController();
    // One text field per answer option. A submission must carry at least one
    // non-empty option, so we start with two empty fields (a typical poll
    // needs at least two choices).
    final List<TextEditingController> answerControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    final formKey = GlobalKey<FormState>();
    int? selectedCategoryId;
    String? errorText;
    bool isSubmitting = false;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.newQuestionTitle),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: textController,
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
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? l10n.requiredField
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: l10n.categoryLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: sortedCategories
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedCategoryId = value),
                        validator: (value) =>
                            value == null ? l10n.requiredField : null,
                      ),
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.noCategoriesAvailable,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: minAgeController,
                        decoration: InputDecoration(
                          labelText: l10n.minAgeLabel,
                          hintText: l10n.minAgeHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.answerOptionsLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...answerControllers.asMap().entries.map((entry) {
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
                                    labelText: l10n.answerOptionLabel(
                                      index + 1,
                                    ),
                                    hintText: l10n.answerOptionHint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              if (answerControllers.length > 1)
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      answerControllers.removeAt(index);
                                      controller.dispose();
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: l10n.removeAnswerOption,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: answerControllers.length >= kMaxAnswerOptions
                            ? null
                            : () => setDialogState(
                                () => answerControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addAnswerOption),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          // At least one non-empty answer option is required by
                          // the backend; surface a localized error instead of
                          // sending an empty submission.
                          final options = answerControllers
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();
                          if (options.isEmpty) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = l10n.atLeastOneAnswerOption;
                            });
                            return;
                          }
                          final parsedMinAge = int.tryParse(
                            minAgeController.text.trim(),
                          );
                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });
                          try {
                            await _submissionService.submitQuestion(
                              text: textController.text.trim(),
                              categoryId: selectedCategoryId!,
                              language: _currentLanguageCode(),
                              answerOptions: options,
                              minAge: parsedMinAge ?? 0,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.submissionCreated),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadSubmissions();
                          } on SubmissionException catch (e) {
                            if (e.statusCode == 401) {
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              context.read<AuthController>().logout();
                              return;
                            }
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = e.message;
                            });
                          } catch (_) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = l10n.submissionFailed;
                            });
                          }
                        },
                  child: isSubmitting
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
          },
        );
      },
    );
    // Free the controllers created for the dialog (question, min age and all
    // answer-option fields).
    textController.dispose();
    minAgeController.dispose();
    for (final controller in answerControllers) {
      controller.dispose();
    }
  }

  /// Returns the 2-character language code for the device locale, constrained to
  /// the languages the app actually supports.
  String _currentLanguageCode() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'de' ? 'de' : 'en';
  }

  /// Builds the status chip (pending / approved / rejected) for a submission.
  Widget _statusChip(BuildContext context, Submission submission) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    late final Color color;
    late final String label;
    if (submission.isApproved) {
      color = Colors.green;
      label = l10n.submissionApproved;
    } else if (submission.isRejected) {
      color = colorScheme.error;
      label = l10n.submissionRejected;
    } else {
      color = Colors.orange;
      label = l10n.submissionPending;
    }
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: color.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Formats the backend `created_at` timestamp for display, falling back to the
  /// raw value if it cannot be parsed.
  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      return DateFormat.yMMMd().format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authController = context.watch<AuthController>();

    return Scaffold(
      drawer: AppDrawer(
        selectedRoute: 'submissions',
        onSelect: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.mySubmissions),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSubmissions,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.reload,
          ),
          const UserMenuButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSubmissions,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : _submissions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.outbox_outlined,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.mySubmissionsEmpty,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _submissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final submission = _submissions[index];
                final categoryName =
                    authController.categories[submission.categoryId] ??
                    l10n.categoryFallback(submission.categoryId);
                final dateText = _formatDate(submission.createdAt);
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.text,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              label: Text(categoryName),
                              visualDensity: VisualDensity.compact,
                            ),
                            _statusChip(context, submission),
                            if (dateText.isNotEmpty)
                              Text(
                                l10n.submittedOn(dateText),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.createQuestion),
      ),
    );
  }
}
