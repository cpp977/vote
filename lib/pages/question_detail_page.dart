import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart' show AppLocalizations;
import '../models/answer_option.dart';
import '../models/answer_stats.dart';
import '../models/question.dart';
import '../services/admin_service.dart';
import '../services/auth_middleware.dart';
import '../services/navigation_service.dart';
import '../widgets/configuration_menu.dart';
import '../widgets/question_stats_widget.dart';

/// Detail page for a single question.
///
/// Displays the question text, its answer options (which can be voted on),
/// and aggregated voting statistics including gender breakdowns.
class QuestionDetailsPage extends StatefulWidget {
  final Question question;

  const QuestionDetailsPage({super.key, required this.question});

  @override
  State<QuestionDetailsPage> createState() => _QuestionDetailsPageState();
}

class _QuestionDetailsPageState extends State<QuestionDetailsPage> {
  final AuthMiddleware _authMiddleware = AuthMiddleware();
  final AdminService _adminService = AdminService();
  List<AnswerOption> _answers = [];
  String? _errorMessage;
  bool _isLoading = true;
  final Set<int> _submittingAnswerIds = {};
  final Set<int> _votedAnswerIds = {};

  // Statistics state
  List<AnswerStats> _stats = [];
  bool _isLoadingStats = true;
  String? _statsErrorMessage;

  // Gender-resolved statistics state
  final List<String> _genders = ['m', 'w', 'd'];
  final Map<String, List<AnswerStats>> _genderStats = {};
  final Map<String, bool> _genderLoading = {};
  final Map<String, String?> _genderErrors = {};

  // Delete question state
  bool _isDeleting = false;

  // Change question state
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    // Defer the initial fetches until after the first frame is built so the
    // build context can depend on inherited widgets such as `AppLocalizations`.
    // Accessing `AppLocalizations.of(context)` from `initState` directly throws
    // because inherited widgets are not yet available at that point.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAnswers();
      _fetchStats();
      for (final gender in _genders) {
        _fetchStatsForGender(gender);
      }
    });
  }

  /// Deletes the current question (admin only).
  Future<void> _deleteQuestion() async {
    final l10n = AppLocalizations.of(context);
    final authController = context.read<AuthController>();

    if (!authController.isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQuestion),
        content: Text(l10n.deleteQuestionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.deleteQuestion),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await _adminService.deleteQuestion(widget.question.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteQuestionSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back to home page
      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate question was deleted
      }
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteQuestionFailed),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteQuestionFailed),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  /// Changes the current question text (admin only).
  Future<void> _changeQuestionText() async {
    final l10n = AppLocalizations.of(context);
    final authController = context.read<AuthController>();

    if (!authController.isAdmin) return;

    final TextEditingController textController = TextEditingController(
      text: widget.question.text,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeQuestionTitle),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.currentQuestionText,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.question.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.newQuestionText,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: l10n.newQuestionText,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _isChanging
                ? null
                : () {
                    if (textController.text.trim().isNotEmpty) {
                      Navigator.pop(context, textController.text.trim());
                    }
                  },
            child: _isChanging
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(l10n.changeQuestion),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    setState(() => _isChanging = true);

    try {
      await _adminService.changeQuestionText(widget.question.id, result);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.changeQuestionSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back to home page with updated question
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.changeQuestionFailed),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.changeQuestionFailed),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChanging = false);
      }
    }
  }

  Future<void> _fetchAnswers() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/answers',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _answers = data
              .map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        NavigationService.navigateToLogin();
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = l10n.questionNotFound;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = l10n.serverError;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.connectionError(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/stats',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _stats = data
              .map((e) => AnswerStats.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoadingStats = false;
        });
      } else if (response.statusCode == 401) {
        NavigationService.navigateToLogin();
      } else if (response.statusCode == 404) {
        setState(() {
          _statsErrorMessage = l10n.statsNotAvailable;
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _statsErrorMessage = l10n.statsLoadFailed;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      setState(() {
        _statsErrorMessage = l10n.connectionError(e.toString());
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchStatsForGender(String gender) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _genderLoading[gender] = true;
      _genderErrors[gender] = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/stats',
      ).replace(queryParameters: {'tagKey': 'gender', 'tagValue': gender});
      final response = await _authMiddleware.get(uri.toString());

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _genderStats[gender] = data
              .map((e) => AnswerStats.fromJson(e as Map<String, dynamic>))
              .toList();
          _genderLoading[gender] = false;
        });
      } else if (response.statusCode == 401) {
        NavigationService.navigateToLogin();
      } else if (response.statusCode == 404) {
        setState(() {
          _genderErrors[gender] = l10n.statsNotAvailable;
          _genderLoading[gender] = false;
        });
      } else {
        setState(() {
          _genderErrors[gender] = l10n.statsLoadFailed;
          _genderLoading[gender] = false;
        });
      }
    } catch (e) {
      setState(() {
        _genderErrors[gender] = l10n.connectionError(e.toString());
        _genderLoading[gender] = false;
      });
    }
  }

  Future<void> _submitAnswer(AnswerOption answer) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submittingAnswerIds.add(answer.id);
    });

    try {
      // Tags are derived by the backend from the user profile.
      final body = jsonEncode({'answer_id': answer.id});

      final response = await _authMiddleware.post(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/answer',
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _submittingAnswerIds.remove(answer.id);
          _votedAnswerIds.add(answer.id);
        });
        // Refresh statistics to reflect the new vote
        _fetchStats();
        for (final gender in _genders) {
          _fetchStatsForGender(gender);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.voteSubmitted(answer.text)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 409) {
        // The backend enforces "one answer per user" and returns 409 when the
        // question has already been answered. The clicked option must NOT be
        // highlighted as voted: the vote was not recorded and the chosen
        // option may not even be the one previously submitted. Just clear the
        // submitting state and inform the user.
        setState(() {
          _submittingAnswerIds.remove(answer.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.alreadyAnswered),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 401) {
        NavigationService.navigateToLogin();
      } else {
        setState(() {
          _submittingAnswerIds.remove(answer.id);
        });
        final errorMessage = response.body.isNotEmpty
            ? response.body.toString()
            : l10n.serverError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithMessage(errorMessage)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingAnswerIds.remove(answer.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.voteSubmitFailed(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final authController = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.questionDetailsTitle),
        actions: [
          if (authController.isAdmin) ...[
            IconButton(
              onPressed: _isDeleting ? null : _deleteQuestion,
              icon: _isDeleting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: l10n.deleteQuestion,
            ),
            IconButton(
              onPressed: _isChanging ? null : _changeQuestionText,
              icon: _isChanging
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : const Icon(Icons.edit_outlined),
              tooltip: l10n.changeQuestion,
            ),
          ],
          const ConfigurationMenu(),
        ],
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
                    widget.question.text,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
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

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
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
                        _errorMessage!,
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
                final isSubmitting = _submittingAnswerIds.contains(answer.id);
                final isVoted = _votedAnswerIds.contains(answer.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: isSubmitting || isVoted
                          ? null
                          : () => _submitAnswer(answer),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isVoted
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                )
                              : colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isVoted
                                    ? colorScheme.primary
                                    : colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    )
                                  : Icon(
                                      isVoted
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      color: isVoted
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSecondaryContainer,
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
                            Icon(
                              isVoted
                                  ? Icons.how_to_vote
                                  : Icons.how_to_vote_outlined,
                              color: isVoted
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Statistics section
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.statistics,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: QuestionStatsWidget(
                  stats: _stats,
                  isLoading: _isLoadingStats,
                  errorMessage: _statsErrorMessage,
                  genderStats: _genders.map((gender) {
                    return GenderStats(
                      gender: gender,
                      label: gender == 'm'
                          ? l10n.genderMale
                          : gender == 'w'
                          ? l10n.genderFemale
                          : l10n.genderDiverse,
                      stats: _genderStats[gender] ?? [],
                      isLoading: _genderLoading[gender] ?? true,
                      errorMessage: _genderErrors[gender],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
