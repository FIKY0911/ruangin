<?php

namespace App\Services;

use App\Models\ClassSession;
use App\Support\Fmt;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;

/**
 * P11 "peringatan dini berantai per dosen": if an earlier session of a
 * lecturer today is still unconfirmed after the grace period (or was reported
 * empty), followers of that lecturer's later sessions today are warned.
 * It only sends notifications; it never changes any session status.
 */
class EarlyWarningService
{
    public function __construct(private readonly NotificationService $notifications) {}

    /** Scans today's sessions. Safe to run every minute (each session warns once). */
    public function run(?CarbonInterface $now = null): int
    {
        $now ??= now();
        $cutoff = $now->copy()->subMinutes(config('ruangin.early_warning_grace_minutes'));

        $candidates = ClassSession::query()
            ->where('start_at', '>=', $now->copy()->startOfDay())
            ->where('start_at', '<=', $cutoff)
            ->where('is_cancelled', false)
            ->whereNull('attendance_recorded_at')
            ->whereNull('early_warning_sent_at')
            ->get();

        $sent = 0;
        foreach ($candidates as $session) {
            $sent += $this->warnLaterSessions($session, 'belum terkonfirmasi', $now);
        }

        return $sent;
    }

    /** @return int notifications created */
    public function warnLaterSessions(ClassSession $earlier, string $reason, ?CarbonInterface $now = null): int
    {
        $now ??= now();

        return DB::transaction(function () use ($earlier, $reason, $now) {
            $locked = ClassSession::whereKey($earlier->id)->lockForUpdate()->first();
            if (! $locked || $locked->early_warning_sent_at !== null) {
                return 0;
            }
            $locked->forceFill(['early_warning_sent_at' => $now])->saveQuietly();

            $later = ClassSession::query()
                ->where('lecturer_id', $locked->lecturer_id)
                ->whereDate('start_at', $locked->start_at->toDateString())
                ->where('start_at', '>', $locked->start_at)
                ->where('start_at', '>', $now)
                ->where('is_cancelled', false)
                ->get();

            $lecturerName = $locked->lecturer?->name ?? 'dosen ini';
            $sent = 0;
            foreach ($later as $session) {
                $sent += $this->notifications->notifyFollowers(
                    $session,
                    'earlyWarning',
                    "{$session->course_name}: peringatan dini",
                    "Sesi lebih awal {$lecturerName} hari ini ({$locked->course_name}, "
                        .Fmt::timeRange($locked->start_at, $locked->end_at).", {$locked->place()}) {$reason}. "
                        .'Status sesi Anda tidak berubah — cek lagi sebelum berangkat.',
                );
            }

            return $sent;
        });
    }
}
