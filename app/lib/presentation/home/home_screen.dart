import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../domain/greeting.dart';
import '../auth/auth_controller.dart';

/// Placeholder home page after login (current scope: auth only).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final account = auth.account!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(BrandAssets.logoCropped, height: 32),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('logout-icon'),
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(greetingFor(account),
                key: const Key('home-greeting'),
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${account.role.label} · ${account.email}',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Image.asset(BrandAssets.lecturer, height: 260),
            const SizedBox(height: 16),
            Text(
              'Halaman utama masih dummy. Fitur jadwal dosen sedang dikembangkan.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('logout-button'),
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
