import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/helpers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignIn = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignIn = !_isSignIn;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  // Map repository error codes (originally from Firebase) to user-friendly messages.
  String _friendlyAuthError(AppException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isSignIn) {
        await auth.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await auth.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AppException catch (e) {
      setState(() => _errorMessage = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AppException catch (e) {
      setState(() => _errorMessage = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    // Capture messenger before any async gap so we don't use BuildContext
    // across an await boundary.
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // Declared in the showDialog closure so it persists across rebuilds.
        bool sending = false;
        return StatefulBuilder(
          builder: (sbContext, setSbState) => AlertDialog(
            title: const Text('Reset Password'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.email,
                  border: OutlineInputBorder(),
                ),
                validator: AppValidators.validateEmail,
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setSbState(() => sending = true);
                        try {
                          await ref
                              .read(authRepositoryProvider)
                              .resetPassword(emailController.text.trim());
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (mounted) {
                            messenger.showSnackBar(const SnackBar(
                              content: Text(
                                'Password reset email sent. Check your inbox.',
                              ),
                            ));
                          }
                        } catch (_) {
                          setSbState(() => sending = false);
                          if (mounted) {
                            messenger.showSnackBar(const SnackBar(
                              content: Text(
                                'Failed to send reset email. Please try again.',
                              ),
                            ));
                          }
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Email'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.flash_on_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.welcome,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignIn ? 'Sign in to continue' : 'Create your account',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // AutofillGroup tells the browser (and mobile autofill) that
              // these fields belong to the same credential form, so it saves
              // both email and password together.
              AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: AppStrings.email,
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: AppValidators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: _isSignIn
                            ? TextInputAction.done
                            : TextInputAction.next,
                        autofillHints: _isSignIn
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
                        onFieldSubmitted: _isSignIn ? (_) => _submit() : null,
                        decoration: InputDecoration(
                          labelText: AppStrings.password,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: AppValidators.validatePassword,
                      ),
                      if (!_isSignIn) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: AppStrings.confirmPassword,
                            prefixIcon: const Icon(Icons.lock_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isSignIn) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(AppStrings.forgotPassword),
                  ),
                ),
              ] else
                const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignIn ? AppStrings.signIn : AppStrings.signUp),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: Text(
                  _isSignIn
                      ? AppStrings.signInWithGoogle
                      : AppStrings.signUpWithGoogle,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignIn
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  // TextButton enforces the 48dp minimum touch target.
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: theme.colorScheme.primary,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(_isSignIn ? AppStrings.signUp : AppStrings.signIn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
