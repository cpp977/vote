import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/auth_models.dart';
import '../services/admin_service.dart';
import '../utils/countries.dart';
import '../widgets/configuration_menu.dart';

/// Administrator detail view for a single user.
///
/// Fetches the full user details from `GET /admin/users/{id}` when the
/// page opens and displays them (id, username, email, birth year, gender,
/// nationality, admin status, and active status). This page is only
/// reachable for users whose [AuthController.isAdmin] is `true` — it is
/// opened by tapping a user entry on the [AdminUsersPage].
///
/// The page also provides [activate] and [deactivate] buttons so an
/// admin can toggle the user's account status via the backend endpoints
/// `POST /admin/users/{id}/active` and `POST /admin/users/{id}/inactive`.
class AdminUserDetailPage extends StatefulWidget {
  final User user;

  const AdminUserDetailPage({super.key, required this.user});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final AdminService _adminService = AdminService();
  late User _user;
  bool _isLoading = true;
  bool _isToggling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start with the partial data from the list so the username/ID are
    // visible immediately while the detail fetch is in progress.
    _user = widget.user;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUserDetails();
    });
  }

  /// Fetches the full user details from the backend.
  Future<void> _loadUserDetails() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await _adminService.getUser(_user.id);
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() => _isLoading = false);
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      setState(() {
        _errorMessage = l10n.adminUserDetailsLoadFailed;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.adminUserDetailsLoadFailed;
        _isLoading = false;
      });
    }
  }

  /// Activates the user via `POST /admin/users/{id}/active`.
  Future<void> _activateUser() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted || _isToggling) return;
    setState(() => _isToggling = true);
    try {
      final user = await _adminService.activateUser(_user.id);
      if (!mounted) return;
      setState(() => _user = user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.activateUserSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.activateUserFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.activateUserFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  /// Deactivates the user via `POST /admin/users/{id}/inactive`.
  Future<void> _deactivateUser() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted || _isToggling) return;
    setState(() => _isToggling = true);
    try {
      final user = await _adminService.deactivateUser(_user.id);
      if (!mounted) return;
      setState(() => _user = user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deactivateUserSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        context.read<AuthController>().logout(showLoginPage: true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deactivateUserFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deactivateUserFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.adminUserDetailsTitle),
        actions: [const ConfigurationMenu()],
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
                    onPressed: _loadUserDetails,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar and name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          child: Text(
                            _user.username.isNotEmpty
                                ? _user.username[0].toUpperCase()
                                : '?',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _user.username,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if (_user.isAdmin)
                          Chip(
                            label: Text(l10n.isAdminLabel),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            backgroundColor: colorScheme.primaryContainer,
                            visualDensity: VisualDensity.compact,
                          ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            _user.isActive
                                ? l10n.adminUserActiveStatus
                                : l10n.adminUserInactiveStatus,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: _user.isActive
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Activate / Deactivate buttons
                  if (!_user.isActive || !_user.isAdmin) ...[
                    Row(
                      children: [
                        if (_user.isActive)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isToggling ? null : _deactivateUser,
                              icon: const Icon(Icons.block_outlined),
                              label: Text(l10n.deactivateUser),
                            ),
                          ),
                        if (!_user.isActive)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isToggling ? null : _activateUser,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(l10n.activateUser),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Details card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            context,
                            Icons.badge_outlined,
                            l10n.adminUserId(_user.id),
                            '#${_user.id}',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            Icons.alternate_email_outlined,
                            l10n.emailLabel,
                            _user.email.isNotEmpty
                                ? _user.email
                                : l10n.notAvailable,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            Icons.cake_outlined,
                            l10n.birthYearLabel,
                            _user.birthYear != null
                                ? _user.birthYear.toString()
                                : l10n.notAvailable,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            Icons.wc_outlined,
                            l10n.genderLabel,
                            _user.gender != null
                                ? _genderLabel(_user.gender!, l10n)
                                : l10n.notAvailable,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            Icons.public_outlined,
                            l10n.nationalityLabel,
                            _user.nationality != null
                                ? countryDisplayName(l10n, _user.nationality!)
                                : l10n.notAvailable,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            Icons.map_outlined,
                            l10n.regionLabel,
                            _user.region != null
                                ? (() {
                                    final auth = context.read<AuthController>();
                                    for (final r in auth.regions) {
                                      if (r.code == _user.region) return r.name;
                                    }
                                    return _user.region!;
                                  })()
                                : l10n.notAvailable,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Converts a gender code from the backend to a human-readable label.
String _genderLabel(String gender, AppLocalizations l10n) {
  switch (gender) {
    case 'm':
      return l10n.genderMale;
    case 'w':
      return l10n.genderFemale;
    case 'd':
      return l10n.genderDiverse;
    default:
      return gender;
  }
}
