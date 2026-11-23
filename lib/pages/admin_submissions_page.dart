import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/submission_models.dart';
import '../services/admin_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/configuration_menu.dart';
import '../widgets/snack_bars.dart';
import '../widgets/user_menu_button.dart';
import 'admin_submission_detail_page.dart';

/// The administrator review queue.
///
/// Two tabs:
///  - the question review queue (every question submission that is not yet
///    approved, from `GET /admin/questions/submissions`); tapping a submission
///    opens [AdminSubmissionDetailPage] where the administrator inspects the
///    submitted answers and approves or rejects the question;
///  - the answer-suggestion queue (every answer-option submission that is not
///    yet approved, from `GET /admin/answer-submissions`); approving appends
///    the proposed option to its question and makes it votable.
///
/// This page is only reachable for users whose [AuthController.isAdmin] is
/// `true` — the entry point lives in the burger menu and is hidden for everyone
/// else.
class AdminSubmissionsPage extends StatefulWidget {
  /// Called when the user picks a destination from the [AppDrawer]. Supplied by
  /// the composition root so this page never imports the questions page
  /// directly (avoiding a circular dependency).
  final void Function(BuildContext context, String route) onNavigate;

  const AdminSubmissionsPage({super.key, required this.onNavigate});

  @override
  State<AdminSubmissionsPage> createState() => _AdminSubmissionsPageState();
}

class _AdminSubmissionsPageState extends State<AdminSubmissionsPage> {
  final AdminService _adminService = AdminService();
  List<Submission> _submissions = [];
  List<AnswerSubmission> _answerSubmissions = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// Ids of the answer suggestions currently being reviewed, so their buttons
  /// can show a progress indicator.
  final Set<int> _reviewingAnswerIds = {};

  @override
  void initState() {
    super.initState();
    // Defer the initial fetch until after the first frame so `AppLocalizations`
    // and `AuthController` are available via the inherited widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSubmissions();
    });
  }

  /// Loads both review queues from the backend.
  Future<void> _loadSubmissions() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final submissions = await _adminService.getSubmissions();
      final answerSubmissions = await _adminService.getAnswerSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _answerSubmissions = answerSubmissions;
        _isLoading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Token refresh failed – the user has to log in again.
        setState(() => _isLoading = false);
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      setState(() {
        _errorMessage = l10n.adminSubmissionsLoadFailed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.adminSubmissionsLoadFailed;
        _isLoading = false;
      });
    }
  }

  /// Opens the detail screen for [submission]. When the detail screen pops with
  /// a `true` result the submission was approved/rejected, so the queue is
  /// reloaded to reflect the new status.
  Future<void> _openDetails(Submission submission) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSubmissionDetailPage(submission: submission),
      ),
    );
    if (refreshed == true && mounted) {
      _loadSubmissions();
    }
  }

  /// Approves the answer suggestion with the given [id], which appends the
  /// proposed option to its question and makes it votable.
  Future<void> _approveAnswer(AnswerSubmission submission) async {
    setState(() => _reviewingAnswerIds.add(submission.id));
    try {
      await _adminService.approveAnswerSubmission(submission.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).answerSuggestionApproved),
          backgroundColor: Colors.green,
        ),
      );
      await _loadSubmissions();
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      // A 409 (already reviewed) carries the precise backend message.
      showErrorSnackBar(
        context,
        e.message.isNotEmpty
            ? e.message
            : AppLocalizations.of(context).answerSuggestionReviewFailed,
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        AppLocalizations.of(context).answerSuggestionReviewFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _reviewingAnswerIds.remove(submission.id));
      }
    }
  }

  /// Rejects the answer suggestion with the given [id] after a confirmation.
  Future<void> _rejectAnswer(AnswerSubmission submission) async {
    final l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rejectAnswerSuggestion),
        content: Text(l10n.rejectAnswerSuggestionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _reviewingAnswerIds.add(submission.id));
    try {
      await _adminService.rejectAnswerSubmission(submission.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).answerSuggestionRejected),
          backgroundColor: Colors.green,
        ),
      );
      await _loadSubmissions();
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      showErrorSnackBar(
        context,
        e.message.isNotEmpty
            ? e.message
            : AppLocalizations.of(context).answerSuggestionReviewFailed,
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        AppLocalizations.of(context).answerSuggestionReviewFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _reviewingAnswerIds.remove(submission.id));
      }
    }
  }

  /// Builds the status chip (pending / approved / rejected) for a submission
  /// status string, shared by question and answer submissions.
  Widget _statusChip(BuildContext context, String submissionStatus) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    late final Color color;
    late final String label;
    if (submissionStatus == 'approved') {
      color = Colors.green;
      label = l10n.submissionApproved;
    } else if (submissionStatus == 'rejected') {
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

  /// Centered placeholder for a loading, failed or empty tab.
  Widget _placeholder({
    required bool isLoading,
    required String? errorMessage,
    required IconData icon,
    required String emptyMessage,
    required VoidCallback onRetry,
  }) {
    final l10n = AppLocalizations.of(context);
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: AppDrawer(selectedRoute: 'admin', onSelect: widget.onNavigate),
        appBar: AppBar(
          backgroundColor: colorScheme.inversePrimary,
          title: Text(l10n.adminReviewQueue),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadSubmissions,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.reload,
            ),
            const ConfigurationMenu(),
            const UserMenuButton(),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.adminReviewQueue),
              Tab(text: l10n.adminAnswerSubmissions),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Question review queue.
            _isLoading || _errorMessage != null || _submissions.isEmpty
                ? _placeholder(
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    icon: Icons.approval_outlined,
                    emptyMessage: l10n.adminSubmissionsEmpty,
                    onRetry: _loadSubmissions,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final submission = _submissions[index];
                      // Submissions may be filed without a category; an admin
                      // assigns one before the question is approved.
                      final int? categoryId = submission.categoryId;
                      final String categoryName = categoryId == null
                          ? l10n.uncategorized
                          : context
                                    .watch<AuthController>()
                                    .categories[categoryId] ??
                                l10n.categoryFallback(categoryId);
                      final dateText = _formatDate(submission.createdAt);
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => _openDetails(submission),
                          borderRadius: BorderRadius.circular(16),
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
                                    _statusChip(
                                      context,
                                      submission.submissionStatus,
                                    ),
                                    if (dateText.isNotEmpty)
                                      Text(
                                        l10n.submittedOn(dateText),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    if (submission.submittedBy != null)
                                      Text(
                                        l10n.submittedBy(
                                          submission.submittedBy!,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            // Answer-suggestion review queue.
            _isLoading || _errorMessage != null || _answerSubmissions.isEmpty
                ? _placeholder(
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    icon: Icons.rate_review_outlined,
                    emptyMessage: l10n.adminAnswerSubmissionsEmpty,
                    onRetry: _loadSubmissions,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _answerSubmissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final submission = _answerSubmissions[index];
                      final dateText = _formatDate(submission.createdAt);
                      final isReviewing = _reviewingAnswerIds.contains(
                        submission.id,
                      );
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
                              if (submission.questionText.isNotEmpty) ...[
                                Text(
                                  submission.questionText,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 4),
                              ],
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
                                  _statusChip(
                                    context,
                                    submission.submissionStatus,
                                  ),
                                  if (dateText.isNotEmpty)
                                    Text(
                                      l10n.submittedOn(dateText),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  if (submission.submittedBy != null)
                                    Text(
                                      l10n.submittedBy(submission.submittedBy!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: isReviewing
                                          ? null
                                          : () => _approveAnswer(submission),
                                      icon: isReviewing
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
                                      onPressed: isReviewing
                                          ? null
                                          : () => _rejectAnswer(submission),
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
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
