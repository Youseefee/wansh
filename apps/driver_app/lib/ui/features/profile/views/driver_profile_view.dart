import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../../notifications/view_models/notifications_view_model.dart';

/// Driver Profile & Account Settings screen with editable driver details
/// (full name + phone) and safe account deletion with active-trip protection.
class DriverProfileView extends StatefulWidget {
  const DriverProfileView({
    super.key,
    required this.sessionController,
    required this.localeController,
    this.notificationsController,
  });

  final DriverSessionController sessionController;
  final LocaleController localeController;
  final DriverNotificationsController? notificationsController;

  @override
  State<DriverProfileView> createState() => _DriverProfileViewState();
}

class _DriverProfileViewState extends State<DriverProfileView> {
  bool _isSavingProfile = false;
  bool _isDeletingAccount = false;

  Future<void> _showEditProfileDialog(String locale) async {
    final user = widget.sessionController.userProfile;
    final result = await showDialog<({String fullName, String phone})>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialFullName: user?.fullName ?? '',
        initialPhone: user?.phone ?? '',
        locale: locale,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSavingProfile = true);
    try {
      await widget.sessionController.updateUserProfile(
        fullName: result.fullName,
        phone: result.phone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DriverStrings.profileUpdated(locale)),
            backgroundColor: WenshyColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: WenshyColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount(String locale) async {
    final confirmation = await showDialog<({bool confirmed, String reason})>(
      context: context,
      builder: (_) => _DeleteAccountDialog(locale: locale),
    );

    if (confirmation == null || !confirmation.confirmed || !mounted) return;
    final reason = confirmation.reason.trim();

    setState(() => _isDeletingAccount = true);
    try {
      await widget.sessionController.deleteAccount(
        reason: reason.isEmpty ? null : reason,
      );
    } catch (e) {
      if (mounted) {
        final message = _localizeDeleteError(e, locale);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: WenshyColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  String _localizeDeleteError(Object error, String locale) {
    final raw = error is PostgrestException
        ? '${error.code ?? ''} ${error.message}'.toLowerCase()
        : error.toString().toLowerCase();
    if (raw.contains('p0001') ||
        raw.contains('active') ||
        raw.contains('in-progress') ||
        raw.contains('trip')) {
      return DriverStrings.deleteAccountActiveTripError(locale);
    }
    return DriverStrings.t(
      locale,
      'تعذر حذف الحساب حالياً. حاول مرة أخرى لاحقاً.',
      'Could not delete your account right now. Please try again later.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.sessionController,
        widget.localeController,
      ]),
      builder: (context, _) {
        final locale = widget.localeController.localeCode;
        final theme = Theme.of(context);
        final user = widget.sessionController.userProfile;
        final driver = widget.sessionController.driverProfile;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.navProfile(locale)),
            actions: <Widget>[
              if (widget.notificationsController != null)
                NotificationsBellButton(
                  notificationsController: widget.notificationsController!,
                  localeController: widget.localeController,
                ),
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: ListView(
            padding: const EdgeInsetsDirectional.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: WenshyColors.amberSoft,
                            child: const Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: WenshyColors.amberDark,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  user?.fullName ?? '',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (user?.phone != null) Text(user!.phone!),
                                if (user?.email != null)
                                  Text(
                                    user!.email!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          if (driver != null)
                            WenshyStatusBadge.driverApproval(
                              driver.approvalStatus,
                              locale: locale,
                              compact: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: OutlinedButton.icon(
                          key: const Key('edit_profile_btn'),
                          onPressed: _isSavingProfile
                              ? null
                              : () => _showEditProfileDialog(locale),
                          icon: _isSavingProfile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.edit_outlined, size: 18),
                          label: Text(DriverStrings.editProfile(locale)),
                        ),
                      ),
                      if (driver != null) ...<Widget>[
                        const Divider(height: 24),
                        _ProfileRow(
                          label: DriverStrings.nationalId(locale),
                          value: driver.nationalIdNumber ?? '-',
                        ),
                        const SizedBox(height: 6),
                        _ProfileRow(
                          label: DriverStrings.driverLicense(locale),
                          value: driver.licenseNumber ?? '-',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(DriverStrings.notificationsTitle(locale)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(DriverStrings.setupWinchStep(locale)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/onboarding/winch'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(DriverStrings.uploadKycStep(locale)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/onboarding/kyc'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(
                        DriverStrings.t(locale, 'تغيير اللغة', 'Language'),
                      ),
                      trailing: Text(
                        widget.localeController.isArabic
                            ? 'العربية'
                            : 'English',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: widget.localeController.toggleLocale,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isDeletingAccount
                    ? null
                    : widget.sessionController.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(DriverStrings.signOut(locale)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WenshyColors.deepSlate,
                  side: const BorderSide(color: WenshyColors.slateMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const Key('delete_account_btn'),
                onPressed: _isDeletingAccount
                    ? null
                    : () => _confirmDeleteAccount(locale),
                icon: _isDeletingAccount
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WenshyColors.red,
                        ),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(DriverStrings.deleteAccount(locale)),
                style: TextButton.styleFrom(
                  foregroundColor: WenshyColors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialFullName,
    required this.initialPhone,
    required this.locale,
  });

  final String initialFullName;
  final String initialPhone;
  final String locale;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return AlertDialog(
      title: Text(DriverStrings.editProfile(locale)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('edit_profile_name_field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: DriverStrings.fullName(locale),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 2) {
                  return DriverStrings.t(
                    locale,
                    'أدخل الاسم الكامل',
                    'Enter your full name',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('edit_profile_phone_field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: DriverStrings.phone(locale),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 8) {
                  return DriverStrings.t(
                    locale,
                    'أدخل رقم هاتف صحيحاً',
                    'Enter a valid phone number',
                  );
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DriverStrings.t(locale, 'إلغاء', 'Cancel')),
        ),
        FilledButton(
          key: const Key('save_profile_btn'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop((
                fullName: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
              ));
            }
          },
          child: Text(DriverStrings.saveChanges(locale)),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.locale});

  final String locale;

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
    final locale = widget.locale;
    return AlertDialog(
      title: Text(DriverStrings.deleteAccountTitle(locale)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(DriverStrings.deleteAccountWarning(locale)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('delete_account_reason_field'),
            controller: _reasonController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: DriverStrings.deleteReasonOptional(locale),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DriverStrings.t(locale, 'إلغاء', 'Cancel')),
        ),
        FilledButton(
          key: const Key('confirm_delete_account_btn'),
          style: FilledButton.styleFrom(backgroundColor: WenshyColors.red),
          onPressed: () => Navigator.of(context).pop((
            confirmed: true,
            reason: _reasonController.text.trim(),
          )),
          child: Text(DriverStrings.deleteAccount(locale)),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
