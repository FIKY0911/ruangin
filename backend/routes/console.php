<?php

use App\Models\AppNotification;
use App\Services\EarlyWarningService;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

// P11: early warnings. Run the scheduler with `php artisan schedule:work`
// (dev) or a cron/Task Scheduler entry calling `php artisan schedule:run`.
Artisan::command('ruangin:early-warnings', function (EarlyWarningService $service) {
    $sent = $service->run();
    $this->info("Peringatan dini terkirim: {$sent} notifikasi.");
})->purpose('Kirim peringatan dini untuk sesi yang belum terkonfirmasi lewat masa tenggang');

Schedule::command('ruangin:early-warnings')->everyMinute()->withoutOverlapping();

// "Notifikasi otomatis dihapus setelah 30 hari" (RUANGIN_NOTIFICATION_RETENTION_DAYS, 0 = keep).
Artisan::command('ruangin:prune-notifications', function () {
    $cutoff = AppNotification::retentionCutoff();
    if ($cutoff === null) {
        $this->info('Masa simpan notifikasi tidak dibatasi; tidak ada yang dihapus.');

        return 0;
    }
    // Seen notifications from days with a mode-uji test run are kept for the
    // notification-latency report (see AppNotification::pruneExpired).
    $deleted = AppNotification::pruneExpired();
    $this->info("Notifikasi lebih lama dari {$cutoff->toDateTimeString()} dihapus: {$deleted} "
        .'(data uji jeda notifikasi tetap disimpan).');

    return 0;
})->purpose('Hapus notifikasi yang lebih lama dari masa simpan');

Schedule::command('ruangin:prune-notifications')->dailyAt('02:00')->withoutOverlapping();

// Exit code 0 = demo data is for today, 1 = stale/empty (used by start-backend.bat).
Artisan::command('ruangin:demo-status', function () {
    $today = \App\Models\ClassSession::whereDate('start_at', now()->toDateString())->count();
    // The demo scenario's anchor session must be dated today (seeded "dayOffset 0").
    $anchor = \App\Models\ClassSession::find('s-mobile-today');
    $anchorOk = $anchor === null || $anchor->start_at->isToday();
    if ($today > 0 && $anchorOk) {
        $this->info("Data demo OK: {$today} sesi hari ini (".now()->toDateString().').');

        return 0;
    }
    $this->warn('Data demo kedaluwarsa/kosong: tidak ada sesi untuk hari ini ('.now()->toDateString().').');

    return 1;
})->purpose('Cek apakah data demo sudah untuk tanggal hari ini');

// Demo data is relative to "today": reset it to keep the demo scenario fresh.
Artisan::command('ruangin:reset-demo {--force : Jalankan tanpa konfirmasi}', function () {
    if (! $this->option('force') && ! $this->confirm('Hapus SEMUA data Ruangin dan isi ulang data demo?')) {
        return 1;
    }
    $this->call('migrate:fresh', ['--seed' => true, '--force' => true]);
    $this->info('Data demo Ruangin sudah di-reset untuk hari ini.');

    return 0;
})->purpose('Reset database ke data demo sintetis (tanggal relatif hari ini)');
