import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../../../core/widgets/driver_widgets.dart';
import '../view_models/auth_view_model.dart';

enum _LoginMethod {
  email,
  phoneOtp,
}

/// Driver Sign-In screen supporting Email & Password (with Forgot Password)
/// as well as Phone SMS OTP login.
class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    required this.viewModel,
    required this.localeController,
  });

  final AuthViewModel viewModel;
  final LocaleController localeController;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _LoginMethod _method = _LoginMethod.email;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    await widget.viewModel.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _submitSendOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    await widget.viewModel.sendPhoneOtp(_phoneController.text.trim());
  }

  Future<void> _submitVerifyOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final phone =
        widget.viewModel.pendingOtpPhone ?? _phoneController.text.trim();
    await widget.viewModel.verifyPhoneOtp(
      phone: phone,
      token: _otpController.text.trim(),
    );
  }

  Future<void> _showForgotPasswordDialog(String locale) async {
    final submittedEmail = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        locale: locale,
      ),
    );

    if (submittedEmail != null && submittedEmail.isNotEmpty && mounted) {
      await widget.viewModel.sendPasswordResetEmail(submittedEmail);
    }
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
            title: Text(DriverStrings.appTitle(locale)),
            actions: <Widget>[
              LocaleToggleButton(localeController: widget.localeController),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsetsDirectional.all(20),
                    decoration: BoxDecoration(
                      color: WenshyColors.deepSlate,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsetsDirectional.all(14),
                          decoration: BoxDecoration(
                            color: WenshyColors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: WenshyColors.amber,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                DriverStrings.loginTitle(locale),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DriverStrings.loginSubtitle(locale),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<_LoginMethod>(
                    key: const Key('login_method_toggle'),
                    segments: <ButtonSegment<_LoginMethod>>[
                      ButtonSegment<_LoginMethod>(
                        value: _LoginMethod.email,
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: Text(DriverStrings.emailLoginTab(locale)),
                      ),
                      ButtonSegment<_LoginMethod>(
                        value: _LoginMethod.phoneOtp,
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: Text(DriverStrings.phoneOtpLoginTab(locale)),
                      ),
                    ],
                    selected: <_LoginMethod>{_method},
                    onSelectionChanged: vm.isLoading
                        ? null
                        : (selected) {
                            vm.clearError();
                            setState(() {
                              _method = selected.first;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  if (vm.errorMessage != null) ...<Widget>[
                    _AuthFeedbackBanner(
                      message: vm.errorMessage!,
                      isError: true,
                    ),
                    const SizedBox(height: 16),
                  ] else if (vm.infoMessage != null) ...<Widget>[
                    _AuthFeedbackBanner(
                      message: vm.infoMessage!,
                      isError: false,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_method == _LoginMethod.email)
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: DriverStrings.email(locale),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty || !v.contains('@')) {
                                return DriverStrings.t(
                                  locale,
                                  'أدخل بريداً إلكترونياً صحيحاً',
                                  'Enter a valid email address',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitEmailLogin(),
                            decoration: InputDecoration(
                              labelText: DriverStrings.password(locale),
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
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return DriverStrings.t(
                                  locale,
                                  'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                                  'Password must be at least 6 characters',
                                );
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key('forgot_password_btn'),
                              onPressed: vm.isLoading
                                  ? null
                                  : () => _showForgotPasswordDialog(locale),
                              child: Text(DriverStrings.forgotPassword(locale)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          WenshyPrimaryButton(
                            label: DriverStrings.signIn(locale),
                            icon: Icons.login_rounded,
                            isLoading: vm.isLoading,
                            onPressed: _submitEmailLogin,
                          ),
                        ],
                      ),
                    )
                  else
                    Form(
                      key: _phoneFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            key: const Key('otp_phone_field'),
                            controller: _phoneController,
                            enabled: !vm.otpSent && !vm.isLoading,
                            keyboardType: TextInputType.phone,
                            textInputAction: vm.otpSent
                                ? TextInputAction.next
                                : TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: DriverStrings.phone(locale),
                              hintText: '+201001234567',
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.length < 8) {
                                return DriverStrings.t(
                                  locale,
                                  'أدخل رقم هاتف صحيحاً',
                                  'Enter a valid phone number',
                                );
                              }
                              return null;
                            },
                          ),
                          if (vm.otpSent) ...<Widget>[
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('otp_code_field'),
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitVerifyOtp(),
                              decoration: InputDecoration(
                                labelText: DriverStrings.otpCodeLabel(locale),
                                prefixIcon: const Icon(Icons.pin_outlined),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.length < 4) {
                                  return DriverStrings.t(
                                    locale,
                                    'أدخل رمز التحقق المرسل لهاتفك',
                                    'Enter the OTP code sent to your phone',
                                  );
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            WenshyPrimaryButton(
                              key: const Key('verify_otp_btn'),
                              label: DriverStrings.verifyAndSignIn(locale),
                              icon: Icons.verified_user_outlined,
                              isLoading: vm.isLoading,
                              onPressed: _submitVerifyOtp,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: vm.isLoading
                                  ? null
                                  : () {
                                      _otpController.clear();
                                      vm.resetOtpFlow();
                                    },
                              child: Text(
                                DriverStrings.changePhoneNumber(locale),
                              ),
                            ),
                          ] else ...<Widget>[
                            const SizedBox(height: 20),
                            WenshyPrimaryButton(
                              key: const Key('send_otp_btn'),
                              label: DriverStrings.sendOtpCode(locale),
                              icon: Icons.sms_outlined,
                              isLoading: vm.isLoading,
                              onPressed: _submitSendOtp,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearError();
                            context.go('/register');
                          },
                    child: Text(DriverStrings.noAccountRegister(locale)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.locale,
  });

  final String initialEmail;
  final String locale;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return AlertDialog(
      title: Text(DriverStrings.resetPasswordTitle(locale)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(DriverStrings.resetPasswordHint(locale)),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('forgot_password_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: DriverStrings.email(locale),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty || !v.contains('@')) {
                  return DriverStrings.t(
                    locale,
                    'أدخل بريداً إلكترونياً صحيحاً',
                    'Enter a valid email address',
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
          key: const Key('send_reset_link_btn'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_emailController.text.trim());
            }
          },
          child: Text(DriverStrings.sendResetLink(locale)),
        ),
      ],
    );
  }
}

class _AuthFeedbackBanner extends StatelessWidget {
  const _AuthFeedbackBanner({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? WenshyColors.red : WenshyColors.emerald;
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.mark_email_read_outlined,
            color: color,
          ),
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
