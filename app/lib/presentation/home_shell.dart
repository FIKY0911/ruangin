import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'edit/manage_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'reports/reports_tab.dart';
import 'session/followed_screen.dart';
import 'widgets/ruangin_chrome.dart';
import 'widgets/ruangin_widgets.dart';

/// Navigator of the Beranda tab. Search and lecturer profiles open inside it
/// so the floating nav bar stays visible (Hasil_cari1.png, Profil_Dosen.png);
/// session detail and notifications open full screen on the root navigator.
final berandaNavigatorKey = GlobalKey<NavigatorState>();

const _navItems = [
  NavItem(Key('nav-home'), Icons.home_outlined, Icons.home_rounded, 'Beranda'),
  NavItem(
    Key('nav-schedule'),
    Icons.calendar_today_outlined,
    Icons.calendar_today,
    'Jadwal',
  ),
  NavItem(
    Key('nav-reports'),
    Icons.description_outlined,
    Icons.description,
    'Laporan',
  ),
  NavItem(Key('nav-profile'), Icons.person_outline, Icons.person, 'Profil'),
];

/// Floating nav from image/ui-ux: Beranda · Jadwal · Laporan · Profil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) {
    if (i == 0 && _index == 0) {
      berandaNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account!;
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: IndexedStack(
        key: ValueKey(account.id),
        index: _index,
        children: [
          NavigatorPopHandler(
            enabled: _index == 0,
            onPopWithResult: (_) =>
                berandaNavigatorKey.currentState?.maybePop(),
            child: Navigator(
              key: berandaNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    HomeScreen(onOpenMenu: () => setState(() => _index = 3)),
              ),
            ),
          ),
          const _ClearNav(child: ScheduleTab()),
          const _ClearNav(child: ReportsTab()),
          const _ClearNav(child: ProfileScreen()),
        ],
      ),
      bottomNavigationBar: RuanginNavBar(
        items: _navItems,
        selectedIndex: _index,
        onSelected: _select,
      ),
    );
  }
}

/// Keeps tabs without the blue wave clear of the floating nav bar.
class _ClearNav extends StatelessWidget {
  const _ClearNav({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
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
