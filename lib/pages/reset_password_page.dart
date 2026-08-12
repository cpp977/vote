import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/auth_error_localization.dart';
import '../widgets/configuration_menu.dart';

/// Page for setting a new password using a reset token received via a
/// deep-link URL (email link with `?token=<raw-token>`).
///
/// The [token] is typically extracted from the deep-link URI by
/// [DeepLinkService]. If the token is `null` or empty, the page shows an
/// informational message guiding the user to request a new reset link.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.token});

  /// The raw password-reset token extracted from the deep-link URL query
  /// parameter. May be `null` if the user navigated to this page directly
  /// (e.g. via a typed URL without a token).
  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _resetSuccessfully = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validates the form and submits the new password to the auth controller.
  /// On success the page switches to a confirmation message guiding the user
  /// back to the login screen.
  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    // Require an explicit token check in addition to form validation.
    if (widget.token == null || widget.token!.isEmpty) {
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.resetPassword(
      widget.token!,
      _passwordController.text,
    );

    if (success && mounted) {
      setState(() => _resetSuccessfully = true);
    }
  }

  /// Navigates back to the login page, clearing the entire stack.
  void _navigateToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    // No token available — show an informational message.
    if (widget.token == null || widget.token!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          title: Text(l10n.resetPasswordTitle),
          actions: [const ConfigurationMenu()],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.resetPasswordTokenMissing,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _navigateToLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.backToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(l10n.resetPasswordTitle),
        actions: [const ConfigurationMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    l10n.resetPasswordPrompt,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Success confirmation
                  if (_resetSuccessfully) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.resetPasswordSuccess,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _navigateToLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.backToLogin),
                    ),
                  ] else ...[
                    // Password form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: l10n.passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.passwordRequired;
                              }
                              if (value.length < 8) {
                                return l10n.passwordMinLengthReset;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: l10n.confirmNewPasswordLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleReset(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.confirmPasswordRequired;
                              }
                              if (value != _passwordController.text) {
                                return l10n.passwordsDoNotMatchReset;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Error message
                          Consumer<AuthController>(
                            builder: (context, auth, _) {
                              if (auth.error == null) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
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
                                        localizedAuthError(l10n, auth.error),
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

                          // Reset button
                          Consumer<AuthController>(
                            builder: (context, auth, _) {
                              return FilledButton(
                                onPressed: auth.isLoading ? null : _handleReset,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        l10n.submit,
                                        style: TextStyle(fontSize: 16),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
