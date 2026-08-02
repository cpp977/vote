import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/auth_models.dart';
import '../services/admin_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/user_menu_button.dart';
import 'admin_user_detail_page.dart';

/// The administrator user management page.
///
/// Lists every registered user via `GET /admin/users`. This page is
/// only reachable for users whose [AuthController.isAdmin] is `true` —
/// the entry point lives in the burger menu and is hidden for everyone
/// else. Tapping a user opens [AdminUserDetailPage] with the full
/// details for that user.
class AdminUsersPage extends StatefulWidget {
  /// Called when the user picks a destination from the [AppDrawer].
  /// Supplied by the composition root so this page never imports the
  /// questions page directly (avoiding a circular dependency).
  final void Function(BuildContext context, String route) onNavigate;

  const AdminUsersPage({super.key, required this.onNavigate});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminService _adminService = AdminService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUsers();
    });
  }

  /// Loads the user list from the backend.
  Future<void> _loadUsers() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await _adminService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() => _isLoading = false);
        context.read<AuthController>().logout();
        return;
      }
      setState(() {
        _errorMessage = l10n.adminUsersLoadFailed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.adminUsersLoadFailed;
        _isLoading = false;
      });
    }
  }

  /// Opens the detail screen for [user].
  void _openDetails(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUserDetailPage(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      drawer: AppDrawer(selectedRoute: 'users', onSelect: widget.onNavigate),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.adminUsers),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadUsers,
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
                    onPressed: _loadUsers,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : _users.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.adminUsersEmpty,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _openDetails(user),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.adminUserId(user.id),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (user.isAdmin)
                            Icon(
                              Icons.shield_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
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
