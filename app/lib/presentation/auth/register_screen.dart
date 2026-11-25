import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/auth_service.dart';
import '../widgets/auth_components.dart';
import 'auth_form_controllers.dart';
import 'auth_routes.dart';

/// docs/design/register.jpg. Creates a mahasiswa account on the server
/// (`POST /auth/register`), then opens Login with the email prefilled.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => RegisterController(c.read<AuthService>()),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RegisterController>();

    Future<void> submit() async {
      final account = await c.submit();
      if (account != null && context.mounted) {
        await openLogin(context,
            replace: true, initialEmail: account.email, justRegistered: true);
      }
    }

    return AuthScaffold(
      title: 'Register',
      heading: 'Sign up',
      children: [
        if (c.errorMessage case final msg?) ErrorBanner(message: msg),
        const FieldLabel('Email'),
        EmailField(
          key: const Key('register-email'),
          enabled: !c.isSubmitting,
          onChanged: c.setEmail,
          errorText: c.errorFor(AuthField.email),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Password'),
        PasswordField(
          key: const Key('register-password'),
          enabled: !c.isSubmitting,
          onChanged: c.setPassword,
          errorText: c.errorFor(AuthField.password),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Confirm Password'),
        PasswordField(
          key: const Key('register-confirm'),
          enabled: !c.isSubmitting,
          onChanged: c.setConfirmPassword,
          errorText: c.errorFor(AuthField.confirmPassword),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const Key('register-submit'),
          label: 'Sign up',
          loading: c.isSubmitting,
          onPressed: submit,
        ),
        const SizedBox(height: 8),
        InlineLink(
          key: const Key('go-login'),
          prompt: 'Already have an account?',
          link: 'Sign in',
          onTap: () => openLogin(context, replace: true),
        ),
        const SizedBox(height: 8),
        SocialButton(
          key: const Key('apple-button'),
          provider: SocialProvider.apple,
          label: 'Sign up with Apple',
          onPressed: () => showNotAvailable(context),
        ),
        const SizedBox(height: 12),
        SocialButton(
          key: const Key('google-button'),
          provider: SocialProvider.google,
          label: 'Sign up with Google',
          onPressed: () => showNotAvailable(context),
        ),
        const SizedBox(height: 28),
        TermsFooter(
          onTermsTap: () => showNotAvailable(context),
          onPrivacyTap: () => showNotAvailable(context),
        ),
      ],
    );
  }
}
