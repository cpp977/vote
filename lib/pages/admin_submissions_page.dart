import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/submission_models.dart';
import '../services/admin_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/user_menu_button.dart';
import 'admin_submission_detail_page.dart';

/// The administrator review queue.
///
/// Lists every question submission that is not yet approved (the full queue
/// returned by `GET /admin/questions/submissions`), regardless of who submitted
/// it. This page is only reachable for users whose [AuthController.isAdmin] is
/// `true` — the entry point lives in the burger menu and is hidden for
/// everyone else. Tapping a submission opens [AdminSubmissionDetailPage] where
/// the administrator can inspect the submitted answers and approve or reject
/// the question.
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

  /// Loads the review queue from the backend.
  Future<void> _loadSubmissions() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final submissions = await _adminService.getSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        // Token refresh failed – the user has to log in again.
        setState(() => _isLoading = false);
        context.read<AuthController>().logout();
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
      drawer: AppDrawer(selectedRoute: 'admin', onSelect: widget.onNavigate),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.adminReviewQueue),
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
                      Icons.approval_outlined,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.adminSubmissionsEmpty,
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
                              if (submission.submittedBy != null)
                                Text(
                                  l10n.submittedBy(submission.submittedBy!),
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
                  ),
                );
              },
            ),
    );
  }
}
