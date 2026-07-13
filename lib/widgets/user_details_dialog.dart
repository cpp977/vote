import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/auth_error_localization.dart';
import '../models/auth_models.dart';

/// Dialog that shows the currently logged-in user's profile and lets them edit
/// their email, gender and password via `PATCH /me`.
class UserDetailsDialog extends StatefulWidget {
  const UserDetailsDialog({super.key, required this.authController});

  final AuthController authController;

  @override
  State<UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> {
  // Created once so the `/me` request is not re-issued on every rebuild
  // (e.g. when the controller notifies listeners).
  late final Future<bool> _detailsFuture;

  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _gender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.authController.loadUserDetails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Switches the dialog into edit mode, pre-filling the fields with the
  /// currently stored values.
  void _startEditing() {
    final auth = widget.authController;
    _emailController.text = auth.email ?? '';
    _gender = const ['m', 'w', 'd'].contains(auth.gender) ? auth.gender : null;
    _passwordController.clear();
    _confirmPasswordController.clear();
    widget.authController.clearError();
    setState(() => _isEditing = true);
  }

  /// Validates the form and persists the changes through the auth controller.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final request = UpdateUserRequest(
      email: _emailController.text.trim(),
      gender: _gender,
      password: password.isEmpty ? null : password,
    );

    final success = await widget.authController.updateUser(request);
    if (success && mounted) {
      widget.authController.clearError();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileUpdateSuccess),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final auth = widget.authController;
        final notAvailable = l10n.notAvailable;

        final genderText = auth.gender == null
            ? notAvailable
            : switch (auth.gender!) {
                'm' => l10n.genderMale,
                'w' => l10n.genderFemale,
                'd' => l10n.genderDiverse,
                _ => auth.gender!,
              };

        Widget detailRow(IconData icon, String label, String value) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(value, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (_isEditing) {
          return AlertDialog(
            title: Text(l10n.editUserDetailsTitle),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Chip(
                          avatar: const Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                          ),
                          label: Text(l10n.isAdminLabel),
                        ),
                      ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.emailRequired;
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return l10n.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: l10n.genderLabel,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'm',
                          child: Text(l10n.genderMale),
                        ),
                        DropdownMenuItem(
                          value: 'w',
                          child: Text(l10n.genderFemale),
                        ),
                        DropdownMenuItem(
                          value: 'd',
                          child: Text(l10n.genderDiverse),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (value.length < 8) {
                          return l10n.passwordChangeMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordConfirmLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (value) {
                        if (_passwordController.text.isNotEmpty &&
                            value != _passwordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<AuthController>(
                      builder: (context, authCtl, _) {
                        if (authCtl.error == null) {
                          return const SizedBox.shrink();
                        }
                        final colorScheme = Theme.of(context).colorScheme;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localizedAuthError(l10n, authCtl.error),
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  widget.authController.clearError();
                  setState(() => _isEditing = false);
                },
                child: Text(l10n.cancel),
              ),
              Consumer<AuthController>(
                builder: (context, authCtl, _) => FilledButton(
                  onPressed: authCtl.isLoading ? null : _save,
                  child: authCtl.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(l10n.userDetailsTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detailRow(
                  Icons.person_outline,
                  l10n.usernameLabel,
                  auth.username ?? notAvailable,
                ),
                detailRow(
                  Icons.email_outlined,
                  l10n.emailLabel,
                  auth.email ?? notAvailable,
                ),
                detailRow(
                  Icons.cake_outlined,
                  l10n.birthYearLabel,
                  auth.birthYear?.toString() ?? notAvailable,
                ),
                detailRow(Icons.transgender, l10n.genderLabel, genderText),
                detailRow(
                  Icons.flag_outlined,
                  l10n.nationalityLabel,
                  auth.nationality ?? notAvailable,
                ),
                if (auth.isAdmin)
                  detailRow(
                    Icons.admin_panel_settings,
                    l10n.isAdminLabel,
                    l10n.yes,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
            FilledButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.edit),
            ),
          ],
        );
      },
    );
  }
}
