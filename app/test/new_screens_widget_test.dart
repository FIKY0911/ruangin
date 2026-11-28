import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/core/brand.dart';
import 'package:ruangin/data/local/key_value_store.dart';

import 'app_harness.dart';
import 'fake_backend.dart';

/// Screens from the second batch of image/ui-ux designs.
void main() {
  late FakeBackend backend;
  late InMemoryStore store;

  setUp(() {
    backend = FakeBackend();
    store = InMemoryStore();
  });

  Finder image(String asset) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == asset,
  );

  /// Adds a session for l-budi today (testNow is Monday 23 Nov, 08:15).
  void budiSession(
    String id,
    int startHour,
    int endHour, {
    bool recorded = false,
    bool cancelled = false,
    String? course,
  }) {
    final base = Map<String, dynamic>.of(backend.sessions['s-basis-today']!);
    final day = backend.now;
    backend.sessions[id] = base
      ..['id'] = id
      ..['courseName'] = course ?? 'Kelas $id'
      ..['start'] = DateTime(day.year, day.month, day.day, startHour)
      ..['end'] = DateTime(day.year, day.month, day.day, endHour)
      ..['isCancelled'] = cancelled
      ..['attendance'] = recorded
          ? {
              'recordedAt': DateTime(
                day.year,
                day.month,
                day.day,
                startHour,
                5,
              ),
              'source': 'Sinkron absensi',
            }
          : null
      ..['history'] = <Map<String, dynamic>>[];
  }

  testWidgets('Beranda: logo, early-warning banner opens the session', (
    tester,
  ) async {
    backend.notify(
      'u-nadia',
      's-basis-today',
      'earlyWarning',
      'Basis Data: peringatan dini',
      'Sesi lebih awal dosen ini belum terkonfirmasi.',
    );
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);

    expect(image(BrandAssets.logoCropped), findsOneWidget);
    expect(find.byKey(const Key('home-warning')), findsOneWidget);
    expect(find.text('Basis Data: peringatan dini'), findsWidgets);

    await tapKey(tester, 'home-warning');
    expect(find.text('Detail sesi'), findsOneWidget);
    expect(
      find.byKey(const Key('nav-home')),
      findsNothing,
      reason: 'detail is full screen',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('home-warning')),
      findsNothing,
      reason: 'opening the warning marks it read',
    );
  });

  testWidgets('search: results show the illustration; empty state image', (
    tester,
  ) async {
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'home-search');
    await tester.enterText(field('search-field'), 'budi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Hasil cari'), findsOneWidget);
    expect(image(BrandAssets.lecturerSitting), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);

    await tester.enterText(field('search-field'), 'zaydan');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada hasil'), findsOneWidget);
    expect(image(BrandAssets.noResults), findsOneWidget);

    // Tapping Beranda again returns to the Beranda root.
    await tapKey(tester, 'nav-home');
    expect(find.byKey(const Key('home-search')), findsOneWidget);
  });

  testWidgets('session detail: info grid, Ikuti -> Diikuti, report sheet', (
    tester,
  ) async {
    backend.sessions['s-basis-today']!['history'] = <Map<String, dynamic>>[
      {
        'at': backend.now,
        'actor': 'Petugas akademik',
        'description': 'Pindah: R306 → Lab 2',
      },
    ];
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'home-search');
    await tester.enterText(field('search-field'), 'budi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tapKey(tester, 'lecturer-l-budi');
    await tapKey(tester, 'session-s-basis-today');

    expect(find.text('Belum terkonfirmasi'), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('10.00–11.40'), findsOneWidget);
    expect(find.text('Program studi'), findsOneWidget);
    await revealIn(tester, find.text('Pindah: R306 → Lab 2'));
    expect(find.text('Pindah: R306 → Lab 2'), findsOneWidget);

    await tapKey(tester, 'follow-button');
    expect(find.text('Diikuti'), findsOneWidget);

    await tapKey(tester, 'report-empty');
    expect(
      find.text('Sebagai mahasiswa, kamu melaporkan Lab 2 kosong.'),
      findsOneWidget,
    );
    expect(
      find.text('Belum dikonfirmasi hingga dicek petugas.'),
      findsOneWidget,
    );
    await tapKey(tester, 'cancel-report');
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(backend.reports, isEmpty);
  });

  Future<void> openBudi(WidgetTester tester) async {
    await tapKey(tester, 'home-search');
    await tester.enterText(field('search-field'), 'budi');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tapKey(tester, 'lecturer-l-budi');
  }

  testWidgets('lecturer profile: semester attendance and Riwayat kehadiran', (
    tester,
  ) async {
    // Same course as s-basis-today (10.00–11.40, upcoming at 08.15).
    budiSession('s-budi-1', 6, 7, recorded: true, course: 'Basis Data');
    budiSession('s-budi-2', 7, 8, course: 'Basis Data');
    budiSession('s-budi-3', 5, 6, cancelled: true, course: 'Basis Data');
    // Before the semester: not counted.
    budiSession('s-budi-old', 9, 10, course: 'Basis Data');
    backend.sessions['s-budi-old']!
      ..['start'] = DateTime(2026, 9, 1, 9)
      ..['end'] = DateTime(2026, 9, 1, 10);
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await openBudi(tester);

    expect(find.text('Kehadiran semester ini'), findsOneWidget);
    expect(
      find.textContaining('1 dari 2 sesi', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Semester Ganjil 2026/2027 · Data simulasi'),
      findsOneWidget,
    );
    expect(find.text('BS'), findsOneWidget);
    expect(backend.calls('GET', '/lecturers/l-budi/attendance'), isNotEmpty);

    // Week strip: next week has no sessions, previous comes back.
    await tapKey(tester, 'week-next');
    expect(find.text('Sesi Senin, 30 Nov'), findsOneWidget);
    expect(
      find.text('Tidak ada jadwal mengajar di tanggal ini'),
      findsOneWidget,
    );
    await tapKey(tester, 'week-prev');
    expect(find.text('Sesi Senin, 23 Nov'), findsOneWidget);

    await tapKey(tester, 'open-attendance');
    expect(find.text('Riwayat kehadiran'), findsOneWidget);
    expect(find.text('Semester ini · Data simulasi'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 sesi tercatat'), findsOneWidget);
    expect(find.text('1 sesi belum terkonfirmasi'), findsOneWidget);
    expect(find.text('Teknik Informatika · Pertemuan 1–4'), findsOneWidget);
    expect(find.byKey(const Key('attendance-s-budi-3')), findsOneWidget);
    expect(find.byKey(const Key('attendance-s-budi-old')), findsNothing);
    expect(find.text('Tidak hadir'), findsNothing);

    await tapKey(tester, 'attendance-s-budi-2');
    expect(find.text('Detail sesi'), findsOneWidget);
  });

  testWidgets('lecturer profile: no active semester shows the reason', (
    tester,
  ) async {
    backend.hasActiveSemester = false;
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await openBudi(tester);
    expect(find.text('Belum ada semester aktif.'), findsOneWidget);
    expect(find.byKey(const Key('lecturer-name')), findsOneWidget);
  });

  testWidgets('lecturer profile: Ikuti follows all sessions of the lecturer', (
    tester,
  ) async {
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(find.byKey(const Key('session-s-basis-today')), findsNothing);
    await openBudi(tester);

    expect(find.text('Ikuti'), findsOneWidget);
    await tapKey(tester, 'follow-lecturer');
    expect(find.text('Diikuti'), findsOneWidget);
    expect(backend.lecturerFollows['u-nadia'], {'l-budi'});
    expect(backend.calls('PUT', '/lecturers/l-budi/follow'), hasLength(1));

    // Beranda "Sesi hari ini" includes the followed lecturer's session.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-s-basis-today')), findsOneWidget);
    expect(find.text('10.00–11.40 · Gedung C · Lab 2'), findsOneWidget);

    // Unfollow again from the profile.
    await openBudi(tester);
    await tapKey(tester, 'follow-lecturer');
    expect(find.text('Ikuti'), findsOneWidget);
    expect(backend.lecturerFollows['u-nadia'], isEmpty);
  });

  testWidgets('search: course name finds sessions; tap opens the detail', (
    tester,
  ) async {
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'home-search');
    await tester.enterText(field('search-field'), 'mobile');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('0 dosen · 2 sesi ditemukan'), findsOneWidget);
    expect(find.byKey(const Key('search-sessions')), findsOneWidget);
    expect(find.byKey(const Key('session-s-pm-today')), findsOneWidget);
    expect(find.byKey(const Key('session-s-pm-tomorrow')), findsOneWidget);
    expect(
      find.text('23 Nov · Gedung D · Ruang 402 · Prodi Teknik Informatika'),
      findsOneWidget,
    );

    await tapKey(tester, 'session-s-pm-today');
    expect(find.text('Detail sesi'), findsOneWidget);
    expect(find.text('Gedung'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-building'))).data,
      'Gedung D',
    );
    expect(find.text('Senin, 23 Nov 2026'), findsOneWidget);
    expect(find.text('Tanggal'), findsNothing);
  });

  testWidgets('Simulasi label follows the server flag', (tester) async {
    await backend.signInAs('u-nadia', store);
    backend.follows['u-nadia'] = {'s-pm-today'};
    await pumpApp(tester, backend, store);
    expect(find.byKey(const Key('simulated-chip')), findsOneWidget);
    expect(find.text('Simulasi'), findsOneWidget);
    await tapKey(tester, 'session-s-pm-today');
    expect(find.byKey(const Key('simulated-chip')), findsOneWidget);
  });

  testWidgets('no Simulasi label when the data is not simulated', (
    tester,
  ) async {
    backend
      ..simulatedData = false
      ..retentionDays = null;
    backend.notify('u-nadia', 's-pm-today', 'sessionChanged', 'Ruang berubah');
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(find.byKey(const Key('simulated-chip')), findsNothing);
    await tapKey(tester, 'nav-notifications');
    expect(find.text('Ruang berubah'), findsOneWidget);
    expect(find.byKey(const Key('retention-note')), findsNothing);
  });

  testWidgets(
    'Simulasi stays visible when /app-config fails; refresh retries',
    (tester) async {
      backend.failAppConfig = true;
      await backend.signInAs('u-nadia', store);
      await pumpApp(tester, backend, store);
      expect(find.byKey(const Key('simulated-chip')), findsOneWidget);
      final calls = backend.calls('GET', '/app-config').length;
      expect(calls, greaterThanOrEqualTo(1));

      // Server recovers and reports real (non-simulated) data: pull to refresh.
      backend
        ..failAppConfig = false
        ..simulatedData = false;
      await tester.fling(
        find.byKey(const Key('home-greeting')),
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(backend.calls('GET', '/app-config').length, greaterThan(calls));
      expect(find.byKey(const Key('simulated-chip')), findsNothing);
    },
  );

  testWidgets('app resume fetches /app-config again', (tester) async {
    backend.failAppConfig = true;
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    expect(find.byKey(const Key('simulated-chip')), findsOneWidget);

    backend
      ..failAppConfig = false
      ..simulatedData = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulated-chip')), findsNothing);
  });

  testWidgets('notifications: Semua / Belum dibaca filters and groups', (
    tester,
  ) async {
    backend
      ..notify(
        'u-nadia',
        's-basis-today',
        'sessionChanged',
        'Ruang sesi berubah',
        'Basis Data · R306 → Lab 2',
      )
      ..notify(
        'u-nadia',
        's-basis-today',
        'sessionChanged',
        'Sesi dibatalkan',
        'Statistika',
      );
    backend.notifications.last
      ..['read'] = true
      ..['createdAt'] = backend.now.subtract(const Duration(days: 3));
    await backend.signInAs('u-nadia', store);
    await pumpApp(tester, backend, store);
    await tapKey(tester, 'nav-notifications');

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(find.text('Sesi dibatalkan'), findsOneWidget);
    expect(find.text('20 Nov'), findsOneWidget);

    // notifikasi_revisi.png footer.
    expect(
      find.text('Notifikasi otomatis dihapus setelah 30 hari.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('retention-note')),
        matching: find.text('Simulasi'),
      ),
      findsOneWidget,
    );

    await tapKey(tester, 'filter-unread');
    expect(find.text('Sesi dibatalkan'), findsNothing);
    expect(find.text('Ruang sesi berubah'), findsOneWidget);
    await tapKey(tester, 'filter-all');
    expect(find.text('Sesi dibatalkan'), findsOneWidget);
  });
}
