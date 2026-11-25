import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'edit/manage_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'reports/reports_tab.dart';
import 'session/followed_screen.dart';
import 'widgets/ruangin_widgets.dart';

/// Bottom navigation from image/ui-ux: Beranda · Jadwal · Laporan · Profil.
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        key: ValueKey(account.id),
        index: _index,
        children: [
          HomeScreen(onOpenMenu: () => setState(() => _index = 3)),
          const ScheduleTab(),
          const ReportsTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            key: Key('nav-home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            key: Key('nav-schedule'),
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Jadwal',
          ),
          NavigationDestination(
            key: Key('nav-reports'),
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
          NavigationDestination(
            key: Key('nav-profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Jadwal tab: followed sessions; lecturers/officers also get "Kelola".
class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account!;
    if (!account.isEditor) {
      return const SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Sesi diikuti',
              subtitle: 'Anda dapat kabar saat ruang, jam, atau status berubah',
            ),
            Expanded(child: FollowedScreen()),
          ],
        ),
      );
    }
    return const SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Jadwal'),
            TabBar(
              tabs: [
                Tab(key: Key('tab-manage'), text: 'Kelola'),
                Tab(key: Key('tab-followed'), text: 'Diikuti'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [ManageScreen(), FollowedScreen()]),
            ),
          ],
        ),
      ),
    );
  }
}
