import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';

enum _LoginMode { email, phoneOtp }

/// Customer login screen backed by Supabase Auth (Email/Password + Forgot
/// Password + Phone SMS OTP).
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _LoginMode _mode = _LoginMode.email;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final ok = await authVm.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (ok && mounted) {
      context.go('/');
    }
  }

  Future<void> _submitSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final authVm = AppDependenciesScope.of(context).authViewModel;
    await authVm.sendPhoneOtp(_phoneController.text);
  }

  Future<void> _submitVerifyOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final phone = authVm.otpSentPhone ?? _phoneController.text;
    final ok = await authVm.verifyPhoneOtp(
      phone: phone,
      token: _otpController.text,
    );
    if (ok && mounted) {
      context.go('/');
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final submittedEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (submittedEmail != null && mounted) {
      await authVm.sendPasswordResetEmail(submittedEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final authVm = deps.authViewModel;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: authVm,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsetsDirectional.all(10),
                            decoration: BoxDecoration(
                              color: WenshyColors.amber,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: WenshyColors.deepSlate,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.appName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                strings.appSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const LanguageToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    strings.loginTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.loginSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<_LoginMode>(
                    key: const Key('login_mode_switcher'),
                    segments: <ButtonSegment<_LoginMode>>[
                      ButtonSegment<_LoginMode>(
                        value: _LoginMode.email,
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: Text(strings.emailLoginTab),
                      ),
                      ButtonSegment<_LoginMode>(
                        value: _LoginMode.phoneOtp,
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: Text(strings.phoneOtpLoginTab),
                      ),
                    ],
                    selected: <_LoginMode>{_mode},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      if (next == _mode) return;
                      authVm.clearMessages();
                      setState(() {
                        _mode = next;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (authVm.errorMessage != null) ...<Widget>[
                    _AuthFeedbackBanner(
                      message: authVm.errorMessage!,
                      isError: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (authVm.infoMessage != null) ...<Widget>[
                    _AuthFeedbackBanner(
                      message: authVm.infoMessage!,
                      isError: false,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_mode == _LoginMode.email)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: strings.emailLabel,
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty || !val.contains('@')) {
                                return strings.invalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: strings.passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').length < 6) {
                                return strings.weakPassword;
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key('forgot_password_btn'),
                              onPressed: authVm.isLoading
                                  ? null
                                  : _openForgotPasswordDialog,
                              child: Text(strings.forgotPasswordBtn),
                            ),
                          ),
                          const SizedBox(height: 12),
                          WenshyPrimaryButton(
                            label: strings.loginTitle,
                            icon: Icons.login_rounded,
                            isLoading: authVm.isLoading,
                            onPressed: _submitEmail,
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
                            enabled: !authVm.isAwaitingOtpVerification &&
                                !authVm.isLoading,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: strings.phoneLabel,
                              hintText: strings.phoneHint,
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.length < 8) {
                                return strings.invalidPhone;
                              }
                              return null;
                            },
                          ),
                          if (authVm.isAwaitingOtpVerification) ...<Widget>[
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('otp_code_field'),
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textDirection: TextDirection.ltr,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: strings.otpCodeLabel,
                                prefixIcon: const Icon(Icons.pin_outlined),
                                counterText: '',
                              ),
                              validator: (v) {
                                final val = v?.trim() ?? '';
                                if (val.length < 4) {
                                  return strings.invalidOtpCode;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            WenshyPrimaryButton(
                              key: const Key('verify_otp_btn'),
                              label: strings.verifyOtpBtn,
                              icon: Icons.verified_user_outlined,
                              isLoading: authVm.isLoading,
                              onPressed: _submitVerifyOtp,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                TextButton(
                                  onPressed: authVm.isLoading
                                      ? null
                                      : () {
                                          _otpController.clear();
                                          authVm.resetPhoneOtpFlow();
                                        },
                                  child: Text(strings.changePhoneBtn),
                                ),
                                TextButton(
                                  onPressed: authVm.isLoading
                                      ? null
                                      : () => authVm.sendPhoneOtp(
                                            authVm.otpSentPhone ??
                                                _phoneController.text,
                                          ),
                                  child: Text(strings.resendOtpBtn),
                                ),
                              ],
                            ),
                          ] else ...<Widget>[
                            const SizedBox(height: 20),
                            WenshyPrimaryButton(
                              key: const Key('send_otp_btn'),
                              label: strings.sendOtpBtn,
                              icon: Icons.sms_rounded,
                              isLoading: authVm.isLoading,
                              onPressed: _submitSendOtp,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(strings.noAccountPrompt),
                      TextButton(
                        onPressed: authVm.isLoading
                            ? null
                            : () {
                                authVm.clearMessages();
                                context.go('/signup');
                              },
                        child: Text(
                          strings.createAccountBtn,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

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
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.forgotPasswordTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.forgotPasswordSubtitle),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('forgot_password_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: strings.emailLabel,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty || !val.contains('@')) {
                  return strings.invalidEmail;
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
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('forgot_password_submit_btn'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_emailController.text.trim());
          },
          child: Text(strings.sendResetLinkBtn),
        ),
      ],
    );
  }
}

class _AuthFeedbackBanner extends StatelessWidget {
  const _AuthFeedbackBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? WenshyColors.red : WenshyColors.emerald;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 20,
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
