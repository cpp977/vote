import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/submission_models.dart';
import '../services/admin_service.dart';
import '../services/auth_middleware.dart';

/// Administrator detail view for a single submission.
///
/// Shows the submitted question text together with its metadata (category,
/// language, minimum age, status and who submitted/reviewed it) and the
/// submitted answer options. Two actions let the administrator [approve] or
/// [reject] the submission; once decided the actions are disabled and a note is
/// shown. Returning to the queue after a decision triggers a reload so the new
/// status is reflected.
class AdminSubmissionDetailPage extends StatefulWidget {
  final Submission submission;

  const AdminSubmissionDetailPage({super.key, required this.submission});

  @override
  State<AdminSubmissionDetailPage> createState() =>
      _AdminSubmissionDetailPageState();
}

class _AdminSubmissionDetailPageState extends State<AdminSubmissionDetailPage> {
  final AdminService _adminService = AdminService();
  final AuthMiddleware _authMiddleware = AuthMiddleware();

  late Submission _submission;
  bool _reviewed = false;
  bool _isReviewing = false;

  // Answer-options state.
  List<AnswerOption> _answers = [];
  bool _isLoadingAnswers = true;
  String? _answersErrorMessage;
  bool _answersNotVisible = false;

  @override
  void initState() {
    super.initState();
    _submission = widget.submission;
    // A submission that is already decided is treated as reviewed so returning
    // to the queue reloads it (harmlessly) and the actions stay disabled.
    _reviewed = _submission.isApproved || _submission.isRejected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchAnswers();
    });
  }

  /// Loads the submitted answer options via `GET /questions/{id}/answers`.
  ///
  /// The backend only exposes answers for `approved` questions or to their
  /// submitter, so an administrator reviewing a still-`pending` submission
  /// receives `404`. That case is rendered as an informational note rather than
  /// an error.
  Future<void> _fetchAnswers() async {
    setState(() {
      _isLoadingAnswers = true;
      _answersErrorMessage = null;
      _answersNotVisible = false;
    });
    try {
      final response = await _authMiddleware.get(
        '${ApiConfig.baseUrl}/questions/${_submission.id}/answers',
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _answers = data
              .map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoadingAnswers = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) context.read<AuthController>().logout();
      } else if (response.statusCode == 404) {
        // Not visible to the reviewer (e.g. still pending) – inform, don't err.
        setState(() {
          _answersNotVisible = true;
          _isLoadingAnswers = false;
        });
      } else {
        setState(() {
          _answersErrorMessage = AppLocalizations.of(context).serverError;
          _isLoadingAnswers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _answersErrorMessage = AppLocalizations.of(
          context,
        ).connectionError(e.toString());
        _isLoadingAnswers = false;
      });
    }
  }

  bool get _alreadyReviewed => _submission.isApproved || _submission.isRejected;

  Future<void> _review(
    Future<Submission> Function(int) action,
    String message,
    String failureMessage,
  ) async {
    setState(() => _isReviewing = true);
    try {
      final updated = await action(_submission.id);
      if (!mounted) return;
      setState(() {
        _submission = updated;
        _reviewed = true;
        _isReviewing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        context.read<AuthController>().logout();
        return;
      }
      setState(() => _isReviewing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isReviewing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _statusChip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    late final Color color;
    late final String label;
    if (_submission.isApproved) {
      color = Colors.green;
      label = l10n.submissionApproved;
    } else if (_submission.isRejected) {
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
    final colorScheme = Theme.of(context).colorScheme;
    final authController = context.watch<AuthController>();
    final categoryName =
        authController.categories[_submission.categoryId] ??
        l10n.categoryFallback(_submission.categoryId);
    final dateText = _formatDate(_submission.createdAt);
    final actionsDisabled = _alreadyReviewed || _isReviewing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _reviewed),
        ),
        title: Text(l10n.submissionDetailsTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.questionLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _submission.text,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(categoryName),
                      visualDensity: VisualDensity.compact,
                    ),
                    _statusChip(context),
                    Chip(
                      label: Text(
                        '${l10n.languageLabel}: ${_submission.language}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('${l10n.minAgeLabel}: ${_submission.minAge}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (dateText.isNotEmpty)
                      Text(
                        l10n.submittedOn(dateText),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (_submission.submittedBy != null)
                      Text(
                        l10n.submittedBy(_submission.submittedBy!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (_submission.reviewedBy != null)
                      Text(
                        l10n.reviewedBy(_submission.reviewedBy!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Answers section
            Text(
              l10n.possibleAnswers,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_isLoadingAnswers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_answersNotVisible)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.answersNotVisible,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_answersErrorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _answersErrorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              )
            else if (_answers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.noAnswersAvailable,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._answers.map((answer) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: colorScheme.onSecondaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              answer.text,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Review actions
            if (_alreadyReviewed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _submission.isApproved
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: _submission.isApproved
                          ? Colors.green
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.submissionAlreadyReviewed,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: actionsDisabled
                          ? null
                          : () => _review(
                              _adminService.approveQuestion,
                              l10n.submissionApprovedMessage,
                              l10n.approveFailed,
                            ),
                      icon: _isReviewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(l10n.approve),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: actionsDisabled
                          ? null
                          : () => _review(
                              _adminService.rejectQuestion,
                              l10n.submissionRejectedMessage,
                              l10n.rejectFailed,
                            ),
                      icon: const Icon(Icons.cancel),
                      label: Text(l10n.reject),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
