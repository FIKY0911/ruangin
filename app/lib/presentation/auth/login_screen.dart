import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_components.dart';
import 'auth_controller.dart';
import 'auth_form_controllers.dart';
import 'auth_routes.dart';

/// docs/design/login.jpg.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.initialEmail = '',
    this.justRegistered = false,
  });

  final String initialEmail;
  final bool justRegistered;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => LoginController(
        c.read<AuthService>(),
        c.read<AuthController>(),
        initialEmail: initialEmail,
      ),
      child: _LoginView(justRegistered: justRegistered),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.justRegistered});

  final bool justRegistered;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final _email =
      TextEditingController(text: context.read<LoginController>().email);

  @override
  void initState() {
    super.initState();
    if (widget.justRegistered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          key: Key('register-success'),
          content: Text('Akun berhasil dibuat. Silakan masuk.'),
        ));
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LoginController>();

    Future<void> submit() async {
      if (await c.submit() && context.mounted) closeAuthFlow(context);
    }

    return AuthScaffold(
      title: 'Login',
      heading: 'Enter your account',
      topGap: 120,
      children: [
        if (c.errorMessage case final msg?) ErrorBanner(message: msg),
        const FieldLabel('Email'),
        EmailField(
          key: const Key('login-email'),
          controller: _email,
          enabled: !c.isSubmitting,
          onChanged: c.setEmail,
          errorText: c.errorFor(AuthField.email),
        ),
        const SizedBox(height: 16),
        FieldLabel(
          'Password',
          trailing: GestureDetector(
            key: const Key('forgot-password'),
            onTap: () => showNotAvailable(context),
            child: Text(
              'Forgot password?',
              style: AppFonts.sansStyle(16, 400, color: AppColors.muted)
                  .copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
        PasswordField(
          key: const Key('login-password'),
          enabled: !c.isSubmitting,
          onChanged: c.setPassword,
          errorText: c.errorFor(AuthField.password),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const Key('login-submit'),
          label: 'Continue',
          loading: c.isSubmitting,
          onPressed: submit,
        ),
        const SizedBox(height: 8),
        InlineLink(
          key: const Key('go-register'),
          prompt: "don't have an account yet?",
          link: 'Sign up',
          onTap: () => openRegister(context, replace: true),
        ),
        const SizedBox(height: 48),
        SocialButton(
          key: const Key('apple-button'),
          provider: SocialProvider.apple,
          label: 'Sign in with Apple',
          onPressed: () => showNotAvailable(context),
        ),
        const SizedBox(height: 12),
        SocialButton(
          key: const Key('google-button'),
          provider: SocialProvider.google,
          label: 'Sign in with Google',
          onPressed: () => showNotAvailable(context),
        ),
        const SizedBox(height: 20),
        TermsFooter(
          onTermsTap: () => showNotAvailable(context),
          onPrivacyTap: () => showNotAvailable(context),
        ),
      ],
    );
  }
}
