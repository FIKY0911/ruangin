<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Exceptions\DomainError;
use App\Models\ClassSession;
use App\Models\EmptyRoomReport;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

/**
 * P09 empty-room reports + P10 points.
 *
 * - Only students report; one report per student per session.
 * - Reports are allowed only inside the session window
 *   (N minutes before start until end) and up to a daily limit.
 * - A report never changes the session status. Followers are told it is
 *   "belum dikonfirmasi"; followers of the lecturer's later sessions today get
 *   an early warning (P11).
 * - A lecturer/officer who may edit the session confirms (=> session
 *   cancelled, reporters get points) or rejects it.
 */
class ReportService
{
    public function __construct(
        private readonly NotificationService $notifications,
        private readonly SessionService $sessions,
        private readonly EarlyWarningService $earlyWarnings,
    ) {}

    /** @return array{0: EmptyRoomReport, 1: bool} the report and whether it was newly created */
    public function report(User $reporter, string $sessionId): array
    {
        if (! $reporter->canReportEmptyRoom()) {
            throw DomainError::forbidden('Hanya mahasiswa yang dapat melapor ruang kosong.');
        }

        $session = ClassSession::findOrFail($sessionId);

        $existing = EmptyRoomReport::where('class_session_id', $session->id)
            ->where('reporter_id', $reporter->id)
            ->first();
        if ($existing) {
            return [$existing, false];
        }

        if ($session->is_cancelled) {
            throw DomainError::invalid('Sesi sudah dibatalkan.');
        }

        $now = now();
        $opensAt = $session->start_at->copy()->subMinutes(config('ruangin.report_window_before_minutes'));
        if ($now->lt($opensAt) || $now->gt($session->end_at)) {
            throw DomainError::invalid(
                'Laporan hanya bisa dikirim mulai '.config('ruangin.report_window_before_minutes')
                .' menit sebelum sesi dimulai sampai sesi selesai.',
                'outsideWindow',
            );
        }

        $today = EmptyRoomReport::where('reporter_id', $reporter->id)
            ->where('created_at', '>=', $now->copy()->startOfDay())
            ->count();
        if ($today >= config('ruangin.report_daily_limit')) {
            throw DomainError::invalid(
                'Batas '.config('ruangin.report_daily_limit').' laporan per hari sudah tercapai.',
                'limitReached',
            );
        }

        $report = DB::transaction(function () use ($session, $reporter) {
            $report = EmptyRoomReport::create([
                'class_session_id' => $session->id,
                'reporter_id' => $reporter->id,
                'status' => EmptyRoomReport::PENDING,
            ]);

            $this->notifications->notifyFollowers(
                $session,
                'emptyRoomReport',
                "{$session->course_name}: laporan ruang kosong (".EmptyRoomReport::CONFIRMATION_LABEL.')',
                "Seorang mahasiswa melaporkan {$session->place()} kosong. "
                    .'Status sesi tidak berubah sampai dikonfirmasi dosen/petugas.',
                $reporter->id,
            );

            $this->earlyWarnings->warnLaterSessions($session, 'dilaporkan kosong (belum dikonfirmasi)');

            return $report;
        });

        return [$report, true];
    }

    /** Pending reports on sessions the actor may edit (officer/lecturer queue). */
    public function queue(User $actor, ?string $status = EmptyRoomReport::PENDING)
    {
        if ($actor->role === UserRole::Mahasiswa) {
            throw DomainError::forbidden();
        }

        return EmptyRoomReport::query()
            ->with(['session.lecturer', 'reporter'])
            ->when($status, fn ($q) => $q->where('status', $status))
            ->whereHas('session', fn (Builder $q) => $this->scopeEditable($q, $actor))
            ->orderByDesc('created_at')
            ->limit(200)
            ->get();
    }

    public function confirm(User $actor, string $reportId): EmptyRoomReport
    {
        return DB::transaction(function () use ($actor, $reportId) {
            $report = $this->lockPending($actor, $reportId);
            $session = ClassSession::whereKey($report->class_session_id)->lockForUpdate()->firstOrFail();

            if (! $session->is_cancelled) {
                $session = $this->sessions->cancelFromReport($actor, $session);
            }

            // Every pending report on this session was right: confirm all of them.
            $points = config('ruangin.report_points');
            $pending = EmptyRoomReport::where('class_session_id', $session->id)
                ->where('status', EmptyRoomReport::PENDING)
                ->lockForUpdate()
                ->get();

            foreach ($pending as $r) {
                $r->update([
                    'status' => EmptyRoomReport::CONFIRMED,
                    'resolved_by' => $actor->id,
                    'resolved_at' => now(),
                    'points_awarded' => $points,
                ]);
                User::whereKey($r->reporter_id)->increment('points', $points);
            }

            $this->notifications->notifyUsers(
                $pending->pluck('reporter_id')->all(),
                $session,
                'reportResolved',
                "{$session->course_name}: laporan Anda dikonfirmasi",
                "Terima kasih! Laporan ruang kosong di {$session->place()} dikonfirmasi "
                    ."{$actor->role->label()}. Anda mendapat +{$points} poin.",
            );

            return $report->refresh();
        });
    }

    public function reject(User $actor, string $reportId): EmptyRoomReport
    {
        return DB::transaction(function () use ($actor, $reportId) {
            $report = $this->lockPending($actor, $reportId);
            $report->update([
                'status' => EmptyRoomReport::REJECTED,
                'resolved_by' => $actor->id,
                'resolved_at' => now(),
            ]);

            $session = $report->session;
            $this->notifications->notifyUsers(
                [$report->reporter_id],
                $session,
                'reportResolved',
                "{$session->course_name}: laporan Anda ditolak",
                "Laporan ruang kosong di {$session->place()} ditolak {$actor->role->label()}. Jadwal sesi tidak berubah.",
            );

            return $report->refresh();
        });
    }

    private function lockPending(User $actor, string $reportId): EmptyRoomReport
    {
        $report = EmptyRoomReport::whereKey($reportId)->lockForUpdate()->firstOrFail();
        if (! $actor->canEditSession($report->session)) {
            throw DomainError::forbidden('Anda tidak berhak memproses laporan sesi ini.');
        }
        if ($report->status !== EmptyRoomReport::PENDING) {
            throw DomainError::invalid('Laporan sudah diproses.', 'alreadyResolved');
        }

        return $report;
    }

    /** Restricts a ClassSession query to sessions $actor may edit (same rule as User::canEditSession). */
    public function scopeEditable(Builder $q, User $actor): Builder
    {
        return match ($actor->role) {
            UserRole::Mahasiswa => $q->whereRaw('1 = 0'),
            UserRole::Dosen => $q->where('lecturer_id', $actor->lecturer_id ?? ''),
            UserRole::Petugas => $q->whereIn('prodi', $actor->scope_prodi ?: ['']),
        };
    }
}
