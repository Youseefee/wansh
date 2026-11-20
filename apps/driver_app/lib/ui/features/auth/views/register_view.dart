import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/auth_view_model.dart';

/// Driver Registration screen (`role: 'driver'`, `full_name`, `phone`,
/// `national_id_number`, `license_number`).
class RegisterView extends StatefulWidget {
  const RegisterView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final AuthViewModel viewModel;
  final LocaleController localeController;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.viewModel.registerDriver(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      nationalIdNumber: _nationalIdController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.viewModel,
        widget.localeController,
      ]),
      builder: (context, _) {
        final locale = widget.localeController.localeCode;
        final theme = Theme.of(context);
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.registerTitle(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      DriverStrings.registerSubtitle(locale),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (vm.errorMessage != null) ...<Widget>[
                      _RegisterAlert(
                        message: vm.errorMessage!,
                        color: WenshyColors.red,
                        icon: Icons.error_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (vm.registrationNeedsEmailConfirm) ...<Widget>[
                      _RegisterAlert(
                        message: DriverStrings.t(
                          locale,
                          'تم إنشاء الحساب! يرجى تأكيد بريدك الإلكتروني ثم تسجيل الدخول.',
                          'Account created! Please confirm your email address, then sign in.',
                        ),
                        color: WenshyColors.emerald,
                        icon: Icons.mark_email_read_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: DriverStrings.fullName(locale),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? DriverStrings.t(
                              locale,
                              'الاسم الكامل مطلوب',
                              'Full name is required',
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: DriverStrings.phone(locale),
                        prefixIcon: const Icon(Icons.phone_outlined),
                        hintText: '+2010...',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 8
                          ? DriverStrings.t(
                              locale,
                              'أدخل رقم هاتف صحيح',
                              'Enter a valid phone number',
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nationalIdController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: DriverStrings.nationalId(locale),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 10
                          ? DriverStrings.t(
                              locale,
                              'أدخل الرقم القومي الصحيح',
                              'Enter a valid National ID number',
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _licenseController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: DriverStrings.driverLicense(locale),
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? DriverStrings.t(
                              locale,
                              'رقم رخصة القيادة مطلوب',
                              'Driver license number is required',
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: DriverStrings.email(locale),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty || !text.contains('@')) {
                          return DriverStrings.t(
                            locale,
                            'أدخل بريداً إلكترونياً صحيحاً',
                            'Enter a valid email address',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: DriverStrings.password(locale),
                        prefixIcon: const Icon(Icons.lock_outline),
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
                      validator: (v) => (v ?? '').length < 6
                          ? DriverStrings.t(
                              locale,
                              'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                              'Password must be at least 6 characters',
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    WenshyPrimaryButton(
                      label: DriverStrings.createAccount(locale),
                      icon: Icons.how_to_reg_rounded,
                      isLoading: vm.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: vm.isLoading
                          ? null
                          : () {
                              vm.clearError();
                              context.go('/login');
                            },
                      child: Text(DriverStrings.haveAccountLogin(locale)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RegisterAlert extends StatelessWidget {
  const _RegisterAlert({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
