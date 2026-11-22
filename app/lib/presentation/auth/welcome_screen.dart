import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../theme/app_theme.dart';
import 'auth_routes.dart';

/// First screen when signed out (docs/design/welcome.jpg).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 150),
                    Image.asset(BrandAssets.logoCropped, width: 205),
                    const SizedBox(height: 14),
                    Image.asset(BrandAssets.lecturer, height: 200),
                    const SizedBox(height: 6),
                    Text(
                      'Class awaits',
                      textAlign: TextAlign.center,
                      style: AppFonts.serifStyle(46, 600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Responsible, honest, trustworthy, and dedicated',
                      textAlign: TextAlign.center,
                      style: AppFonts.sansStyle(16, 400, color: AppColors.ink),
                    ),
                    const SizedBox(height: 64),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          FilledButton(
                            key: const Key('welcome-signup'),
                            style: FilledButton.styleFrom(
                              textStyle: AppFonts.sansStyle(19, 600),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => openRegister(context),
                            child: const Text('Sign up'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            key: const Key('welcome-login'),
                            style: OutlinedButton.styleFrom(
                              textStyle: AppFonts.sansStyle(19, 700),
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => openLogin(context),
                            child: const Text('Log in'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
