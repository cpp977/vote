import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/special_category.dart';
import '../models/submission_models.dart';
import '../services/admin_service.dart';
import '../services/auth_middleware.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../widgets/configuration_menu.dart';
import '../widgets/snack_bars.dart';

/// Administrator detail view for a single submission.
///
/// Shows the submitted question text together with its metadata (category,
/// language, minimum age, status and who submitted/reviewed it) and the
/// submitted answer options. Two actions let the administrator [approve] or
/// [reject] the submission; once decided the actions are disabled and a note is
/// shown. Returning to the queue after a decision triggers a reload so the new
/// status is reflected.
///
/// Submissions may be filed without a category and without answer options. The
/// approval settings therefore also let the administrator pick the category and
/// enter answer options; an approved question must have both, so [approve]
/// stays disabled until they are complete.
class AdminSubmissionDetailPage extends StatefulWidget {
  /// [adminService] and [authMiddleware] can be replaced in tests.
  const AdminSubmissionDetailPage({
    super.key,
    required this.submission,
    this.adminService,
    this.authMiddleware,
  });

  final Submission submission;

  final AdminService? adminService;

  final AuthMiddleware? authMiddleware;

  @override
  State<AdminSubmissionDetailPage> createState() =>
      _AdminSubmissionDetailPageState();
}

class _AdminSubmissionDetailPageState extends State<AdminSubmissionDetailPage> {
  late final AdminService _adminService;
  late final AuthMiddleware _authMiddleware;

  late Submission _submission;
  bool _reviewed = false;
  bool _isReviewing = false;

  // Approval settings applied when approving a pending submission. The
  // submitting user no longer chooses a minimum age; the reviewing admin sets
  // it together with the GDPR special category.
  final TextEditingController _minAgeController = TextEditingController(
    text: '0',
  );
  SpecialCategory _selectedSpecialCategory = SpecialCategory.none;

  /// Category assigned during approval. `null` means "not picked yet" and
  /// blocks the approval, which always needs a category.
  int? _selectedCategoryId;

  // Answer-options state.
  List<AnswerOption> _answers = [];
  bool _isLoadingAnswers = true;
  String? _answersErrorMessage;
  bool _answersNotVisible = false;

  /// Inputs of the answer-options editor, shown when the submission arrived
  /// without answers. Kept in sync with [_answers] so the editor disappears as
  /// soon as the question has answers.
  final List<TextEditingController> _answerControllers = [];

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? AdminService();
    _authMiddleware = widget.authMiddleware ?? AuthMiddleware();
    _submission = widget.submission;
    _selectedCategoryId = _submission.categoryId;
    // Start with one empty option so the admin can type straight away.
    _answerControllers.add(TextEditingController());
    // A submission that is already decided is treated as reviewed so returning
    // to the queue reloads it (harmlessly) and the actions stay disabled.
    _reviewed = _submission.isApproved || _submission.isRejected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchAnswers();
    });
  }

  @override
  void dispose() {
    _minAgeController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Categories sorted by name for a stable display order.
  List<int> get _sortedCategoryIds {
    final Map<int, String> categories = context
        .read<AuthController>()
        .categories;
    final List<int> ids = categories.keys.toList();
    ids.sort(
      (a, b) =>
          categories[a]!.toLowerCase().compareTo(categories[b]!.toLowerCase()),
    );
    return ids;
  }

  /// Categories available for the language the app currently uses, as
  /// id -> name.
  Map<int, String> get _categories => context.read<AuthController>().categories;

  /// Display name of a category id, falling back to the localized
  /// "Uncategorized" for submissions without one.
  String _categoryLabel(int? categoryId) {
    if (categoryId == null) return AppLocalizations.of(context).uncategorized;
    return _categories[categoryId] ??
        AppLocalizations.of(context).categoryFallback(categoryId);
  }

  /// Localized display label for a special category.
  String _specialCategoryLabel(SpecialCategory category) {
    final l10n = AppLocalizations.of(context);
    return switch (category) {
      SpecialCategory.none => l10n.specialCategoryNone,
      SpecialCategory.racialOrEthnicOrigin =>
        l10n.specialCategoryRacialOrEthnicOrigin,
      SpecialCategory.politicalOpinion => l10n.specialCategoryPoliticalOpinion,
      SpecialCategory.religiousOrPhilosophicalBelief =>
        l10n.specialCategoryReligiousOrPhilosophicalBelief,
      SpecialCategory.tradeUnionMembership =>
        l10n.specialCategoryTradeUnionMembership,
      SpecialCategory.geneticData => l10n.specialCategoryGeneticData,
      SpecialCategory.biometricData => l10n.specialCategoryBiometricData,
      SpecialCategory.health => l10n.specialCategoryHealth,
      SpecialCategory.sexLifeOrOrientation =>
        l10n.specialCategorySexLifeOrOrientation,
      SpecialCategory.criminalConvictions =>
        l10n.specialCategoryCriminalConvictions,
    };
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
        '${ApiConfig.baseUrl}/admin/questions/${_submission.id}/answers',
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
        if (!mounted) return;
        // Stop the loading indicator before the login screen replaces this
        // page, otherwise the answers section keeps spinning.
        setState(() => _isLoadingAnswers = false);
        context.read<AuthController>().logout(showLoginPage: true);
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
        _answersErrorMessage = localizedError(AppLocalizations.of(context), e);
        _isLoadingAnswers = false;
      });
    }
  }

  bool get _alreadyReviewed => _submission.isApproved || _submission.isRejected;

  /// An approved question is public and its answers cannot be edited
  /// afterwards, so it needs at least two options to be worth voting on.
  static const int _minAnswerOptions = 2;

  /// Answer options the question already carries, i.e. the ones the submitter
  /// provided. They are never replaced, only added to.
  int get _existingAnswerCount => _answers.length;

  /// Non-empty options currently entered in the answer-options editor.
  List<String> get _enteredAnswerOptions => _answerControllers
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();

  /// How many answer options the question would have after the approval.
  int get _resultingAnswerCount =>
      _existingAnswerCount + _enteredAnswerOptions.length;

  /// The question still needs answer options, so the editor is shown. Once it
  /// carries [ _minAnswerOptions ] options the submitter is done and the admin
  /// must not add more (the backend rejects that with 409).
  bool get _needsAnswerOptions => _existingAnswerCount < _minAnswerOptions;

  /// An approved question needs a category and at least
  /// [ _minAnswerOptions ] answer options.
  ///
  /// Options the submitter already provided count towards that; whatever is
  /// missing is entered in the editor.
  bool get _canApprove =>
      !_isReviewing &&
      _selectedCategoryId != null &&
      _resultingAnswerCount >= _minAnswerOptions;

  Future<void> _review(
    Future<Submission> Function(int) action,
    String message,
    String failureMessage, {
    bool surfaceBackendMessage = false,
  }) async {
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
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      setState(() => _isReviewing = false);
      // Validation errors (e.g. a missing category) are reported by the
      // backend with a precise message, which beats the generic one.
      showErrorSnackBar(
        context,
        surfaceBackendMessage && e.message.isNotEmpty
            ? e.message
            : failureMessage,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isReviewing = false);
      showErrorSnackBar(context, failureMessage);
    }
  }

  /// Appends an empty answer option to the approval editor.
  void _addAnswerOption() {
    setState(() => _answerControllers.add(TextEditingController()));
  }

  /// Removes the answer option at [index] from the approval editor.
  void _removeAnswerOption(int index) {
    setState(() {
      _answerControllers.removeAt(index).dispose();
    });
  }

  /// Approves the submission, completing whatever the submitter left out.
  Future<void> _approve() async {
    if (!_canApprove) return;
    final int? categoryId = _selectedCategoryId;
    // Answer options are only sent while the question has fewer than the
    // required minimum; the backend appends them to whatever the submitter
    // provided and rejects options for a question that is already complete.
    final List<String>? answerOptions = _needsAnswerOptions
        ? _enteredAnswerOptions
        : null;
    await _review(
      (id) => _adminService.approveQuestion(
        id,
        minAge: int.tryParse(_minAgeController.text.trim())?.clamp(0, 120) ?? 0,
        specialCategory: _selectedSpecialCategory,
        categoryId: categoryId,
        answerOptions: answerOptions,
      ),
      AppLocalizations.of(context).submissionApprovedMessage,
      AppLocalizations.of(context).approveFailed,
      surfaceBackendMessage: true,
    );
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
    // Watching the controller keeps the category list and the labels in sync
    // with the loaded categories and the app language.
    context.watch<AuthController>();
    final categoryName = _categoryLabel(_submission.categoryId);
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
        actions: [const ConfigurationMenu()],
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

            // Approval settings: only relevant while a decision is pending.
            if (!_alreadyReviewed) ...[
              Text(
                l10n.approvalSettingsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minAgeController,
                      decoration: InputDecoration(
                        labelText: l10n.approvalMinAgeLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<SpecialCategory>(
                      initialValue: _selectedSpecialCategory,
                      // Long category names would otherwise overflow the row
                      // on narrow screens.
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.specialCategoryLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: SpecialCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(
                                _specialCategoryLabel(category),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedSpecialCategory = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category: required for approval. Submissions filed without a
              // category start unassigned here.
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.categoryLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                hint: Text(l10n.selectCategory),
                items: _sortedCategoryIds
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(
                          _categories[id] ?? l10n.categoryFallback(id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _alreadyReviewed
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategoryId = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              // Answer options. An approved question needs at least
              // [_minAnswerOptions] of them and answers cannot be edited
              // afterwards, so the editor stays available while the submitter
              // provided too few: whatever the admin types is appended to the
              // existing options, never replacing them.
              if (_needsAnswerOptions) ...[
                Text(
                  l10n.answerOptionsRequired,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.answerOptionsNeedMore(
                    _minAnswerOptions - _existingAnswerCount,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: l10n.answerOptionLabel(index + 1),
                              hintText: l10n.answerOptionHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _answerControllers.length >= kMaxAnswerOptions
                        ? null
                        : _addAnswerOption,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAnswerOption),
                  ),
                ),
              ] else
                Text(
                  l10n.answersAlreadyProvided,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.approvalRequirementsHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                      onPressed: _canApprove ? _approve : null,
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
