<?php

namespace App\Services;

use App\Exceptions\DomainError;
use App\Models\ClassSession;
use App\Models\Room;
use App\Models\User;
use App\Support\Fmt;
use Carbon\CarbonInterface;
use Closure;
use Illuminate\Support\Facades\DB;

/**
 * Use cases that change a session (P05) and fan the change out to followers
 * (P06). Mirrors app/lib/domain/session_service.dart, plus optimistic locking:
 * every edit carries the version the client last saw, and a stale version is
 * rejected with 409 (PRD §10 "Bentrok edit dua petugas").
 */
class SessionService
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function changeTime(User $actor, string $sessionId, int $version, CarbonInterface $start, CarbonInterface $end): ClassSession
    {
        return $this->edit($actor, $sessionId, $version, function (ClassSession $s) use ($start, $end) {
            $this->assertNotCancelled($s);
            if (! $end->greaterThan($start)) {
                throw DomainError::invalid('Jam selesai harus setelah jam mulai.');
            }
            if ($start->equalTo($s->start_at) && $end->equalTo($s->end_at)) {
                throw DomainError::invalid('Jam tidak berubah.');
            }
            $old = Fmt::timeRange($s->start_at, $s->end_at);
            $new = Fmt::timeRange($start, $end);
            $s->start_at = $start;
            $s->end_at = $end;

            return ["Jam diubah: {$old} → {$new}", "Jam berubah menjadi {$new}"];
        });
    }

    public function changeRoom(User $actor, string $sessionId, int $version, string $room): ClassSession
    {
        $newRoom = trim($room);

        return $this->edit($actor, $sessionId, $version, function (ClassSession $s) use ($newRoom) {
            $this->assertNotCancelled($s);
            if ($newRoom === '') {
                throw DomainError::invalid('Ruang tidak boleh kosong.');
            }
            if ($newRoom === $s->room) {
                throw DomainError::invalid('Ruang tidak berubah.');
            }
            $old = $s->room;
            $s->room = $newRoom;
            // The building follows the room (catalog); unknown room => null.
            $s->building = Room::buildingOf($newRoom);

            return ["Ruang dipindah: {$old} → {$newRoom}", "Pindah ruang: {$old} → {$newRoom}"];
        });
    }

    public function cancel(User $actor, string $sessionId, int $version, ?string $reason = null): ClassSession
    {
        return $this->edit($actor, $sessionId, $version, function (ClassSession $s) use ($reason) {
            $this->assertNotCancelled($s);
            $s->is_cancelled = true;
            $suffix = $reason ? " ({$reason})" : '';

            return ['Sesi dibatalkan'.$suffix, 'Sesi dibatalkan'];
        });
    }

    public function recordAttendance(User $actor, string $sessionId, int $version): ClassSession
    {
        return $this->edit($actor, $sessionId, $version, function (ClassSession $s) use ($actor) {
            $this->assertCanRecordAttendance($s);
            $now = now();
            $s->attendance_recorded_at = $now;
            $s->attendance_source = 'Dicatat '.mb_strtolower($actor->role->label());
            $time = Fmt::time($now);

            return ["Kehadiran kelas dicatat ({$time})", "Kelas tercatat berjalan · {$time}"];
        });
    }

    /**
     * Cancels a session as the result of a confirmed empty-room report.
     * Called inside ReportService's transaction; permission already checked.
     */
    public function cancelFromReport(User $actor, ClassSession $session): ClassSession
    {
        return $this->apply($actor->actorLabel(), $actor->id, $session, function (ClassSession $s) {
            $s->is_cancelled = true;

            return [
                'Sesi dibatalkan (laporan ruang kosong dikonfirmasi)',
                'Sesi dibatalkan (laporan ruang kosong dikonfirmasi)',
            ];
        });
    }

    /**
     * P08: attendance coming from the (simulated) campus attendance system.
     * Idempotent: returns null when nothing changed.
     */
    public function recordAttendanceFromSync(ClassSession $session, CarbonInterface $recordedAt): ?ClassSession
    {
        return DB::transaction(function () use ($session, $recordedAt) {
            $s = ClassSession::whereKey($session->id)->lockForUpdate()->firstOrFail();
            if ($s->is_cancelled || $s->attendance_recorded_at !== null) {
                return null;
            }

            return $this->apply('Sinkron absensi', null, $s, function (ClassSession $s) use ($recordedAt) {
                $s->attendance_recorded_at = $recordedAt;
                $s->attendance_source = config('ruangin.attendance_source');

                return [
                    'Kehadiran kelas tercatat di sistem absensi',
                    'Kelas tercatat berjalan · '.Fmt::time($recordedAt),
                ];
            }, source: config('ruangin.attendance_source'), at: $recordedAt);
        });
    }

    /**
     * @param  Closure(ClassSession): array{0: string, 1: string}  $mutate
     *                                                                      mutates the session and returns [history text, notification text]
     */
    private function edit(User $actor, string $sessionId, int $version, Closure $mutate): ClassSession
    {
        return DB::transaction(function () use ($actor, $sessionId, $version, $mutate) {
            $s = ClassSession::whereKey($sessionId)->lockForUpdate()->firstOrFail();

            if (! $actor->canEditSession($s)) {
                throw DomainError::forbidden('Anda tidak berhak mengubah sesi ini.');
            }
            if ($s->version !== $version) {
                throw DomainError::staleVersion();
            }

            return $this->apply($actor->actorLabel(), $actor->id, $s, $mutate);
        });
    }

    private function apply(
        string $actorLabel,
        ?string $actorId,
        ClassSession $s,
        Closure $mutate,
        ?string $source = null,
        ?CarbonInterface $at = null,
    ): ClassSession {
        [$historyText, $notificationText] = $mutate($s);

        $now = now();
        $s->source = $source ?? $actorLabel;
        $s->version = $s->version + 1;
        $s->updated_at = $at ?? $now;
        $s->save();

        $s->changes()->create([
            'at' => $at ?? $now,
            'actor' => $actorLabel,
            'description' => $historyText,
        ]);

        $this->notifications->notifyFollowers(
            $s,
            'sessionChanged',
            "{$s->course_name}: {$notificationText}",
            Fmt::date($s->start_at).' · '.Fmt::timeRange($s->start_at, $s->end_at).' · '
                .$s->place().' · status '.$s->statusLabel(),
            $actorId,
        );

        return $s->refresh();
    }

    private function assertNotCancelled(ClassSession $s): void
    {
        if ($s->is_cancelled) {
            throw DomainError::invalid('Sesi sudah dibatalkan.');
        }
    }

    private function assertCanRecordAttendance(ClassSession $s): void
    {
        if ($s->is_cancelled) {
            throw DomainError::invalid('Sesi batal tidak bisa dicatat hadir.');
        }
        if ($s->attendance_recorded_at !== null) {
            throw DomainError::invalid('Kehadiran sesi sudah tercatat.');
        }
    }
}
