import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/account.dart';
import '../../data/remote/api_client.dart';
import '../auth/auth_controller.dart';
import '../demo/demo_panel_screen.dart';
import '../demo/test_mode_screen.dart';
import '../home/home_screen.dart';
import '../lecturer/lecturer_profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/ruangin_widgets.dart';

/// Profil tab: who is signed in (role from the server), points, and the
/// account menu. Header follows image/ui-ux/profil.png.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final account = auth.account!;
    return RefreshIndicator(
      onRefresh: auth.refreshAccount,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 150,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD3E2FB), Color(0xFFE6EEFC)],
                  ),
                ),
                alignment: Alignment.topLeft,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Text(
                      'Profil',
                      style: AppFonts.sansStyle(20, 500, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -48,
                child: InitialsAvatar(name: account.name, size: 96, border: 4),
              ),
            ],
          ),
          const SizedBox(height: 58),
          Text(
            account.name,
            key: const Key('profile-name'),
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(24, 700, color: AppColors.ink),
          ),
          Text(
            '${account.role.label} · ${account.subtitle}',
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(16, 400, color: AppColors.muted),
          ),
          Text(
            account.email,
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (account.role == UserRole.mahasiswa)
            Center(
              child: Text.rich(
                key: const Key('profile-points'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${account.points}',
                      style: AppFonts.sansStyle(
                        24,
                        700,
                        color: AppColors.accent,
                      ),
                    ),
                    TextSpan(
                      text: ' poin laporan terkonfirmasi',
                      style: AppFonts.sansStyle(16, 400, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          if (account.role == UserRole.petugas && account.scopeProdi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Cakupan prodi: ${account.scopeProdi.join(', ')}',
                textAlign: TextAlign.center,
                style: AppFonts.sansStyle(15, 400, color: AppColors.ink),
              ),
            ),
          const SizedBox(height: 16),
          if (account.role == UserRole.dosen && account.lecturerId != null)
            _MenuTile(
              key: const Key('my-timeline'),
              icon: Icons.calendar_month_outlined,
              title: 'Jadwal mengajar saya',
              onTap: () => openLecturer(context, account.lecturerId!),
            ),
          _MenuTile(
            icon: Icons.notifications_none,
            title: 'Notifikasi',
            onTap: () => openNotifications(context),
          ),
          if (account.role == UserRole.petugas)
            _MenuTile(
              key: const Key('open-demo-panel'),
              icon: Icons.science_outlined,
              title: 'Panel demo',
              subtitle: 'Simulasi absensi, peringatan dini, reset data',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DemoPanelScreen(),
                ),
              ),
            ),
          _MenuTile(
            key: const Key('open-test-mode'),
            icon: Icons.timer_outlined,
            title: 'Mode uji',
            subtitle: 'Stopwatch tugas untuk uji pengguna',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TestModeScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.dns_outlined,
            title: 'Server',
            subtitle: context.read<ApiClient>().baseUrl,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: OutlinedButton.icon(
              key: const Key('logout-button'),
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.sansStyle(16, 500, color: AppColors.ink),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
