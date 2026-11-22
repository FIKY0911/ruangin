import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../data/models/account.dart';
import 'auth/auth_controller.dart';
import 'demo/demo_panel_screen.dart';
import 'edit/manage_screen.dart';
import 'notifications/notification_center.dart';
import 'notifications/notifications_screen.dart';
import 'search/search_screen.dart';
import 'session/followed_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account!;
    final unread = context.watch<NotificationCenter>().unread;
    final isEditor = account.role != UserRole.mahasiswa;

    final tabs = <(String, Widget, NavigationDestination)>[
      ('Cari dosen', const SearchScreen(),
          const NavigationDestination(icon: Icon(Icons.search), label: 'Cari')),
      ('Sesi diikuti', const FollowedScreen(),
          const NavigationDestination(
              icon: Icon(Icons.bookmark_outline), label: 'Diikuti')),
      if (isEditor)
        ('Kelola sesi', const ManageScreen(),
            const NavigationDestination(
                icon: Icon(Icons.edit_calendar_outlined), label: 'Kelola')),
      ('Notifikasi', const NotificationsScreen(),
          NavigationDestination(
            key: const Key('nav-notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Notifikasi',
          )),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(BrandAssets.icon, height: 28),
            const SizedBox(width: 10),
            Text(tabs[index].$1),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('account-menu'),
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'demo') {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const DemoPanelScreen()));
              } else if (v == 'logout') {
                await context.read<AuthController>().logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${account.name}\n${account.role.label} · ${account.subtitle}'),
              ),
              const PopupMenuItem(value: 'demo', child: Text('Panel demo')),
              const PopupMenuItem(
                  value: 'logout', key: Key('logout'), child: Text('Keluar')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.$2],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final t in tabs) t.$3],
      ),
    );
  }
}
