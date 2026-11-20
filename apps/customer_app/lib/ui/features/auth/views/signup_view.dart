import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';
import '../../../core/language_toggle_button.dart';

/// Customer registration screen creating `auth.users` + `public.profiles`
/// (`role = 'customer'`) via `AuthService.signUpCustomer`.
class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final ok = await authVm.signUpCustomer(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
    );
    if (!ok || !mounted) return;
    if (authVm.isAuthenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = AppDependenciesScope.of(context).authViewModel;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.signupTitle),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: authVm,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      strings.signupSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (authVm.errorMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsetsDirectional.all(12),
                        decoration: BoxDecoration(
                          color: WenshyColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: WenshyColors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          authVm.errorMessage!,
                          style: const TextStyle(
                            color: WenshyColors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: strings.fullNameLabel,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? strings.requiredField
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: strings.phoneLabel,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? strings.requiredField
                          : null,
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 24),
                    WenshyPrimaryButton(
                      label: strings.createAccountBtn,
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading: authVm.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(strings.haveAccountPrompt),
                        TextButton(
                          onPressed: authVm.isLoading
                              ? null
                              : () {
                                  authVm.clearMessages();
                                  context.go('/login');
                                },
                          child: Text(
                            strings.loginTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
