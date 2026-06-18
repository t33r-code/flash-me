import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/providers/theme_provider.dart';
import 'package:flash_me/screens/data/data_screen.dart';
import 'package:flash_me/utils/helpers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  bool _isLinking = false; // true while any link/unlink operation is in flight

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
        displayName: _displayNameController.text.trim(),
      );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageProfileUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageFailedUpdateProfile)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageSignOutFailed)),
        );
      }
    }
    // On success, authStateProvider fires and main.dart replaces this screen —
    // no need to reset _isSigningOut since the widget will be unmounted.
  }

  // Shows a two-step confirmation dialog before deleting the account.
  Future<void> _confirmAndDeleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 36),
        title: Text(l10n.titleDeleteAccount),
        content: Text(l10n.messageDeleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.actionDeleteMyAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final uid = ref.read(authStateProvider).asData?.value;
    if (uid == null) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount(uid);
      // Auth account deleted — authStateProvider fires and navigates away automatically.
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      final message = e.code == 'requires-recent-login'
          ? context.l10n.messageRecentLoginRequired
          : context.l10n.messageFailedDeleteAccountError(e.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.messageFailedDeleteAccountGeneric)),
      );
    }
  }

  // --- Account linking -------------------------------------------------------

  // Google Sign-In is only available on mobile and web — not desktop.
  bool get _canLinkGoogle =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _linkGoogle() async {
    setState(() => _isLinking = true);
    try {
      final linked = await ref.read(authRepositoryProvider).linkWithGoogle();
      if (mounted && linked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageAccountLinked)),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'provider-already-linked' => context.l10n.errorProviderAlreadyLinked,
        'credential-already-in-use' => context.l10n.errorCredentialAlreadyInUse,
        'requires-recent-login' =>
          context.l10n.messageRecentLoginRequiredForLinking,
        _ => context.l10n.errorLinkFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _showLinkEmailPasswordDialog(String prefillEmail) async {
    final emailController = TextEditingController(text: prefillEmail);
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.titleAddEmailPassword),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ctx.l10n.messageAddEmailPasswordInfo,
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: ctx.l10n.labelEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: AppValidators.validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: ctx.l10n.labelPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: AppValidators.validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: ctx.l10n.labelConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) => v != passwordController.text
                        ? ctx.l10n.validatorPasswordsDoNotMatch
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.labelCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(ctx.l10n.actionLink),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLinking = true);
    try {
      await ref.read(authRepositoryProvider).linkWithEmailPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageAccountLinked)),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'provider-already-linked' => context.l10n.errorProviderAlreadyLinked,
        'requires-recent-login' =>
          context.l10n.messageRecentLoginRequiredForLinking,
        _ => context.l10n.errorLinkFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      emailController.dispose();
      passwordController.dispose();
      confirmController.dispose();
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _confirmUnlink(String providerId, String providerName) async {
    // Guard: never leave the account with zero sign-in methods.
    final providers =
        ref.read(authRepositoryProvider).getLinkedProviderIds();
    if (providers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.errorCannotUnlinkOnlyMethod),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.titleConfirmUnlink),
        content: Text(ctx.l10n.messageConfirmUnlink(providerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(ctx.l10n.actionUnlink),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLinking = true);
    try {
      await ref.read(authRepositoryProvider).unlinkProvider(providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageAccountUnlinked)),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? context.l10n.messageRecentLoginRequiredForLinking
          : context.l10n.errorUnlinkFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No pop-back listener needed here — main.dart watches authStateProvider
    // and replaces MainScreen with AuthScreen on sign-out automatically.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titleProfile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.l10n.tooltipEditProfile,
              onPressed: () {
                _displayNameController.text =
                    appUser.asData?.value?.displayName ?? '';
                setState(() => _isEditing = true);
              },
            ),
          const HelpMenuButton(HelpContext.account),
        ],
      ),
      body: appUser.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.errorFailedLoadProfile)),
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          (user?.displayName?.isNotEmpty == true
                                  ? user!.displayName![0]
                                  : user?.email[0] ?? '?')
                              .toUpperCase(),
                          style: theme.textTheme.headlineLarge,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              if (_isEditing) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _displayNameController,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveProfile(),
                    decoration: InputDecoration(
                      labelText: context.l10n.labelDisplayName,
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: AppValidators.validateName,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _isEditing = false),
                        child: Text(context.l10n.labelCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.l10n.labelSave),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.person_outlined),
                  title: Text(context.l10n.labelDisplayName),
                  subtitle: Text(user?.displayName ?? context.l10n.labelNotSet),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(context.l10n.labelEmail),
                  subtitle: Text(user?.email ?? ''),
                ),
                const Divider(),
                // ── Linked accounts ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    context.l10n.titleLinkedAccounts,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
                Builder(builder: (_) {
                  final providers = ref
                      .read(authRepositoryProvider)
                      .getLinkedProviderIds();
                  return Column(
                    children: [
                      _ProviderTile(
                        icon: Icons.g_mobiledata_rounded,
                        label: context.l10n.labelGoogle,
                        isLinked: providers.contains('google.com'),
                        // Link/unlink only possible on mobile and web.
                        canAct: _canLinkGoogle,
                        isBusy: _isLinking,
                        onLink: _linkGoogle,
                        onUnlink: () => _confirmUnlink(
                            'google.com', context.l10n.labelGoogle),
                      ),
                      _ProviderTile(
                        icon: Icons.email_outlined,
                        label: context.l10n.labelEmailPassword,
                        isLinked: providers.contains('password'),
                        canAct: true,
                        isBusy: _isLinking,
                        onLink: () => _showLinkEmailPasswordDialog(
                            user?.email ?? ''),
                        onUnlink: () => _confirmUnlink(
                            'password', context.l10n.labelEmailPassword),
                      ),
                    ],
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.import_export_outlined),
                  title: Text(context.l10n.labelImportExport),
                  subtitle: Text(context.l10n.messageImportExportSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DataScreen()),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.brightness_6_outlined),
                          const SizedBox(width: 16),
                          Text(context.l10n.labelTheme,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto_outlined),
                            label: Text(context.l10n.labelThemeSystem),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode_outlined),
                            label: Text(context.l10n.labelThemeLight),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode_outlined),
                            label: Text(context.l10n.labelThemeDark),
                          ),
                        ],
                        selected: {ref.watch(themeModeProvider)},
                        onSelectionChanged: (modes) => ref
                            .read(themeModeProvider.notifier)
                            .setMode(modes.first),
                      ),
                    ],
                  ),
                ),
                const Divider(),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _isSigningOut || _isDeletingAccount ? null : _signOut,
                icon: _isSigningOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(context.l10n.actionSignOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              // Danger zone — separate visually from Sign Out
              OutlinedButton.icon(
                onPressed: _isDeletingAccount || _isSigningOut
                    ? null
                    : _confirmAndDeleteAccount,
                icon: _isDeletingAccount
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(context.l10n.actionDeleteAccount),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One row in the Linked accounts section.
class _ProviderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLinked;
  final bool canAct;   // false on desktop for Google (no GSI support)
  final bool isBusy;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  const _ProviderTile({
    required this.icon,
    required this.label,
    required this.isLinked,
    required this.canAct,
    required this.isBusy,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        isLinked ? l10n.labelLinked : l10n.labelNotLinked,
        style: TextStyle(
          color: isLinked ? scheme.primary : scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: canAct
          ? isLinked
              ? TextButton(
                  onPressed: isBusy ? null : onUnlink,
                  child: Text(l10n.actionUnlink,
                      style: TextStyle(color: scheme.error)),
                )
              : FilledButton.tonal(
                  onPressed: isBusy ? null : onLink,
                  child: Text(l10n.actionLink),
                )
          : null,
    );
  }
}
