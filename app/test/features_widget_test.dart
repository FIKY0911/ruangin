import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/local/key_value_store.dart';

import 'app_harness.dart';
import 'fake_backend.dart';

void main() {
  late FakeBackend backend;
  late InMemoryStore store;

  setUp(() {
    backend = FakeBackend();
    store = InMemoryStore();
  });

  testWidgets('mahasiswa: search -> profile -> detail -> follow -> report -> '
      'message draft copied', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(find.text('Belum ada sesi diikuti hari ini'), findsOneWidget);
    expect(find.text('Mahasiswa Manajemen · 10 poin'), findsOneWidget);

    // P01 search (Hasil_Pencarian.png).
    await tapKey(tester, 'home-search');
    expect(find.text('Semua dosen'), findsOneWidget);
    await tester.enterText(field('search-field'), 'budi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Hasil cari'), findsOneWidget);
    expect(find.text('1 dosen ditemukan'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget, reason: 'initials avatar');

    await tester.enterText(field('search-field'), 'zaydan');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada hasil'), findsOneWidget);

    await tester.enterText(field('search-field'), 'budi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tapKey(tester, 'lecturer-l-budi');

    // P02 profile (Profil_Dosen.png).
    expect(find.text('Profil dosen'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Sesi Senin, 23 Nov'), findsOneWidget);
    expect(
      find.byKey(const Key('nav-home')),
      findsOneWidget,
      reason: 'profile opens inside the Beranda tab, nav stays visible',
    );
    await revealIn(tester, find.text('Basis Data'));
    expect(find.text('Basis Data'), findsOneWidget);
    expect(find.text('Belum terkonfirmasi'), findsOneWidget);

    // P03 detail, P04 follow.
    await tapKey(tester, 'session-s-basis-today');
    expect(find.text('Detail sesi'), findsOneWidget);
    expect(
      find.byKey(const Key('edit-session')),
      findsNothing,
      reason: 'students cannot edit',
    );
    await tapKey(tester, 'follow-button');
    expect(find.byKey(const Key('unfollow-button')), findsOneWidget);
    expect(backend.follows['u-nadia'], {'s-basis-today'});

    // P09 report.
    await tapKey(tester, 'report-empty');
    await tapKey(tester, 'confirm-report');
    expect(
      find.text('Sudah dilaporkan kosong (belum dikonfirmasi)'),
      findsOneWidget,
    );
    expect(backend.reports.single['reporterId'], 'u-nadia');
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('report-empty'))))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // P12 message draft.
    await tapKey(tester, 'message-draft');
    await tester.enterText(field('draft-purpose'), 'meminta arahan lomba');
    await tapKey(tester, 'draft-generate');
    expect(find.textContaining('meminta arahan lomba'), findsWidgets);
    await tapKey(tester, 'draft-copy');
    expect(clipboard, contains('meminta arahan lomba'));
    expect(find.byKey(const Key('draft-copied')), findsOneWidget);

    // Back to Beranda: the followed session shows up today.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-s-basis-today')), findsOneWidget);
  });

  testWidgets('petugas: Laporan tab confirms a report; session becomes Batal', (
    tester,
  ) async {
    backend.reports.add({
      'id': 'r-1',
      'sessionId': 's-basis-today',
      'reporterId': 'u-nadia',
      'createdAt': backend.now,
      'status': 'pending',
      'resolvedAt': null,
      'pointsAwarded': 0,
    });
    await backend.signInAs('u-hendra', store);
    await pumpApp(tester, backend, store);

    // Beranda for editors: today's editable sessions with a report badge.
    expect(find.text('Sesi yang bisa Anda kelola'), findsOneWidget);
    expect(find.text('1 laporan'), findsOneWidget);

    await tapKey(tester, 'nav-reports');
    expect(find.text('Laporan ruang kosong'), findsOneWidget);
    expect(find.textContaining('Dilaporkan Nadia Putri'), findsOneWidget);
    await tapKey(tester, 'confirm-r-1');
    await tapKey(tester, 'confirm-resolve');
    expect(find.text('Tidak ada laporan menunggu konfirmasi'), findsOneWidget);
    expect(backend.sessions['s-basis-today']!['isCancelled'], isTrue);
    expect(backend.users['u-nadia']!['points'], 20);

    await tapKey(tester, 'report-filter-confirmed');
    expect(find.text('Dikonfirmasi'), findsWidgets);

    // Profil: officer-only demo panel works against /demo/*.
    await tapKey(tester, 'nav-profile');
    expect(find.text('Cakupan prodi: Teknik Informatika'), findsOneWidget);
    await tapKey(tester, 'open-demo-panel');
    await tapKey(tester, 'demo-early-warnings');
    expect(find.text('2 peringatan dini dikirim.'), findsOneWidget);
    await tapKey(tester, 'demo-reset');
    await tapKey(tester, 'confirm-reset');
    expect(
      find.text('Class awaits'),
      findsOneWidget,
      reason: 'reset signs everyone out',
    );
  });

  testWidgets('dosen: Kelola tab, edit with 409 reload prompt', (tester) async {
    await backend.signInAs('u-rina', store);
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'nav-profile');
    expect(
      find.byKey(const Key('open-demo-panel')),
      findsNothing,
      reason: 'demo panel is petugas-only',
    );
    expect(find.byKey(const Key('profile-points')), findsNothing);

    await tapKey(tester, 'nav-schedule');
    expect(find.text('Kelola'), findsOneWidget);
    await tapKey(tester, 'session-s-pm-today');
    await tapKey(tester, 'edit-session');

    backend.sessions['s-pm-today']!['version'] = 9; // edited elsewhere
    await tester.enterText(field('room-field'), 'Ruang 306');
    await tapKey(tester, 'save-room');
    await tapKey(tester, 'confirm-save');
    expect(find.byKey(const Key('stale-dialog')), findsOneWidget);
    await tapKey(tester, 'stale-reload');
    expect(find.textContaining('Data sesi terbaru dimuat'), findsOneWidget);

    await tester.enterText(field('room-field'), 'Ruang 306');
    await tapKey(tester, 'save-room');
    await tapKey(tester, 'confirm-save');
    expect(find.textContaining('Perubahan disimpan'), findsOneWidget);
    expect(backend.sessions['s-pm-today']!['room'], 'Ruang 306');
  });

  testWidgets('notifications: kinds rendered, badge, read-all', (tester) async {
    backend
      ..notify(
        'u-nadia',
        's-pm-today',
        'earlyWarning',
        'Pemrograman Mobile: sesi sebelumnya belum terkonfirmasi',
      )
      ..notify(
        'u-nadia',
        's-pm-today',
        'reportResolved',
        'Laporan Anda dikonfirmasi · +10 poin',
      )
      ..notify(
        'u-nadia',
        's-pm-today',
        'emptyRoomReport',
        'Laporan ruang kosong (belum dikonfirmasi)',
      );
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-notifications')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tapKey(tester, 'nav-notifications');
    expect(
      find.byKey(const Key('notification-kind-earlyWarning')),
      findsOneWidget,
    );
    expect(
      find.text('Peringatan dini · cek lagi sebelum berangkat'),
      findsOneWidget,
    );
    expect(find.text('Laporan mahasiswa · belum dikonfirmasi'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(backend.seen, hasLength(3), reason: 'mode uji: seen reported');

    await tapKey(tester, 'read-all');
    expect(find.text('3 notifikasi ditandai dibaca.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-notifications')),
        matching: find.text('3'),
      ),
      findsNothing,
    );

    // Laporan tab for students: points + report results.
    await tapKey(tester, 'nav-reports');
    expect(find.byKey(const Key('points-card')), findsOneWidget);
    expect(find.text('10 poin'), findsOneWidget);
    expect(find.text('Laporan Anda dikonfirmasi · +10 poin'), findsOneWidget);
  });
}
