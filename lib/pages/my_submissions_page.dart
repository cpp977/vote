import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/submission_models.dart';
import '../services/submission_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/configuration_menu.dart';
import '../widgets/submit_question_button.dart';
import '../widgets/user_menu_button.dart';

/// The user's own submissions.
///
/// Lists everything the current user has submitted (pending, approved or
/// rejected): question submissions via `GET /questions/mine` and answer-option
/// suggestions via `GET /answer-submissions/mine`. Question submissions start
/// out `pending` and are only visible to the public once an administrator
/// approves them; answer suggestions become votable answer options of their
/// question after approval. A floating action button (see
/// [SubmitQuestionButton]) opens the shared submit-question dialog, which the
/// backend stores as a `pending` submission through `POST /questions/submissions`.
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
  List<AnswerSubmission> _answerSubmissions = [];
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

  /// Loads the current user's question submissions and answer suggestions from
  /// the backend.
  Future<void> _loadSubmissions() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final submissions = await _submissionService.getMySubmissions();
      final answerSubmissions = await _submissionService
          .getMyAnswerSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _answerSubmissions = answerSubmissions;
        _isLoading = false;
      });
    } on SubmissionException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Token refresh failed – the user has to log in again.
        setState(() => _isLoading = false);
        context.read<AuthController>().logout(showLoginPage: true);
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

  /// One question submission card.
  Widget _questionCard(BuildContext context, Submission submission) {
    final l10n = AppLocalizations.of(context);
    final authController = context.watch<AuthController>();
    // Submissions may be filed without a category; an admin assigns one before
    // the question is approved.
    final int? categoryId = submission.categoryId;
    final String categoryName = categoryId == null
        ? l10n.uncategorized
        : authController.categories[categoryId] ??
              l10n.categoryFallback(categoryId);
    final dateText = _formatDate(submission.createdAt);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              submission.text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
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
                _statusChip(context, submission.submissionStatus),
                if (dateText.isNotEmpty)
                  Text(
                    l10n.submittedOn(dateText),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One answer-option suggestion card: the question it is proposed for as
  /// context, the proposed option, and its review status.
  Widget _answerSubmissionCard(
    BuildContext context,
    AnswerSubmission submission,
  ) {
    final l10n = AppLocalizations.of(context);
    final dateText = _formatDate(submission.createdAt);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (submission.questionText.isNotEmpty) ...[
              Text(
                submission.questionText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              submission.text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusChip(context, submission.submissionStatus),
                if (dateText.isNotEmpty)
                  Text(
                    l10n.submittedOn(dateText),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
          const ConfigurationMenu(),
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
          : _submissions.isEmpty && _answerSubmissions.isEmpty
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_submissions.isNotEmpty) ...[
                  Text(
                    l10n.questions,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._submissions.map(
                    (submission) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _questionCard(context, submission),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_answerSubmissions.isNotEmpty) ...[
                  Text(
                    l10n.answerSubmissions,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._answerSubmissions.map(
                    (submission) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _answerSubmissionCard(context, submission),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: SubmitQuestionButton(onSubmitted: _loadSubmissions),
    );
  }
}
