import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';

/// Customer profile view & editor, language toggle, and support navigation.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _controllersSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authVm = AppDependenciesScope.of(context).authViewModel;
    if (authVm.profile == null) {
      authVm.loadProfile();
    } else if (!_controllersSynced) {
      _syncControllers(authVm.profile!);
    }
  }

  void _syncControllers(UserProfile profile) {
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';
    _controllersSynced = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final strings = AppStrings.of(context);
    final ok = await authVm.updateProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.profileUpdated)),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final strings = AppStrings.of(context);

    final result = await showDialog<({bool confirmed, String reason})>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );

    if (result != null && result.confirmed && mounted) {
      final deleted = await authVm.deleteMyAccount(
        reason: result.reason.isEmpty ? null : result.reason,
      );
      if (!mounted) return;
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.accountDeletedInfo)),
        );
      } else if (authVm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: WenshyColors.red,
            content: Text(authVm.errorMessage!),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final authVm = deps.authViewModel;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final localeCode = deps.localeController.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profileTitle),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: authVm,
        builder: (context, _) {
          final profile = authVm.profile;
          if (profile != null && !_controllersSynced) {
            _syncControllers(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (authVm.isNonCustomerAccount) ...<Widget>[
                  Container(
                    padding: const EdgeInsetsDirectional.all(12),
                    margin: const EdgeInsetsDirectional.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: WenshyColors.amberSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: WenshyColors.amber),
                    ),
                    child: Text(
                      strings.wrongRoleWarning,
                      style: const TextStyle(
                        color: WenshyColors.deepSlate,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: WenshyColors.amberSoft,
                          child: Text(
                            (profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName[0]
                                    : 'W')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: WenshyColors.deepSlate,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName
                                    : strings.appName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (profile?.email != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  profile!.email!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (profile != null) ...<Widget>[
                                const SizedBox(height: 6),
                                WenshyStatusBadge(
                                  label: WenshyLabels.appRole(
                                    profile.role,
                                    locale: localeCode,
                                  ),
                                  color: WenshyColors.info,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            strings.editProfile,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (authVm.errorMessage != null) ...<Widget>[
                            Text(
                              authVm.errorMessage!,
                              style: const TextStyle(color: WenshyColors.red),
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: strings.fullNameLabel,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? strings.requiredField
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: strings.phoneLabel,
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          WenshyPrimaryButton(
                            label: strings.save,
                            icon: Icons.save_outlined,
                            isLoading: authVm.isSavingProfile,
                            onPressed: _saveProfile,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.language_rounded),
                        title: Text(strings.languageSetting),
                        subtitle: Text(
                          deps.localeController.isArabic
                              ? strings.arabicName
                              : strings.englishName,
                        ),
                        trailing: const LanguageToggleButton(),
                      ),
                      const Divider(height: 1),
                      ListenableBuilder(
                        listenable: deps.notificationsViewModel,
                        builder: (context, _) {
                          final unread = deps.notificationsViewModel.unreadCount;
                          return ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: Text(strings.notificationsTitle),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (unread > 0)
                                  Badge(
                                    label: Text('$unread'),
                                    backgroundColor: WenshyColors.amberDark,
                                  ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: () => context.push('/notifications'),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent_rounded),
                        title: Text(strings.complaintsAndSupport),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/complaints'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: authVm.isLoading || authVm.isDeletingAccount
                      ? null
                      : () => authVm.signOut(),
                  icon: const Icon(Icons.logout_rounded, color: WenshyColors.red),
                  label: Text(
                    strings.signOut,
                    style: const TextStyle(color: WenshyColors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: WenshyColors.red.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const Key('delete_account_btn'),
                  onPressed: authVm.isLoading || authVm.isDeletingAccount
                      ? null
                      : _confirmDeleteAccount,
                  icon: authVm.isDeletingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_forever_outlined,
                          color: WenshyColors.red,
                        ),
                  label: Text(
                    strings.deleteAccountBtn,
                    style: const TextStyle(
                      color: WenshyColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.deleteAccountWarning),
            const SizedBox(height: 14),
            TextField(
              key: const Key('delete_account_reason_field'),
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: strings.deleteAccountReasonHint,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('confirm_delete_account_btn'),
          style: FilledButton.styleFrom(
            backgroundColor: WenshyColors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop((
            confirmed: true,
            reason: _reasonController.text.trim(),
          )),
          child: Text(strings.deleteAccountBtn),
        ),
      ],
    );
  }
}
