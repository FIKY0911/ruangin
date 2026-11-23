<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\TestRun;
use App\Models\User;
use App\Support\Fmt;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * "Mode uji" (PRD §3, §6): task-based user tests comparing "cara biasa" with
 * Ruangin, plus the delay from a saved change to the notification being seen.
 * Results are reported as measured, never as claims.
 */
class TestModeController extends Controller
{
    /** Start timing a task. */
    public function start(Request $request): JsonResponse
    {
        $data = $request->validate([
            'participantCode' => ['required', 'string', 'max:50'],
            'task' => ['required', 'string', 'max:200'],
            'method' => ['required', Rule::in(['biasa', 'ruangin'])],
            'targetSessionId' => ['nullable', 'string', 'exists:class_sessions,id'],
        ], [
            'participantCode.required' => 'Kode peserta wajib diisi.',
            'task.required' => 'Nama tugas wajib diisi.',
            'method.in' => 'Metode harus "biasa" atau "ruangin".',
            'targetSessionId.exists' => 'Sesi target tidak ditemukan.',
        ]);

        $run = TestRun::create([
            'user_id' => $request->user()->id,
            'participant_code' => $data['participantCode'],
            'task' => $data['task'],
            'method' => $data['method'],
            'target_session_id' => $data['targetSessionId'] ?? null,
            'started_at' => now(),
        ]);

        return response()->json(['data' => $this->present($run)], 201);
    }

    /**
     * Stop timing. With a target session, the answer (room + end time) is
     * checked against the session's latest data at this moment; an explicit
     * isCorrect from the facilitator overrides the automatic check.
     */
    public function finish(Request $request, string $id): JsonResponse
    {
        $data = $request->validate([
            'answerRoom' => ['nullable', 'string', 'max:100'],
            'answerEndTime' => ['nullable', 'string', 'max:10'],
            'isCorrect' => ['nullable', 'boolean'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $run = TestRun::where('user_id', $request->user()->id)->findOrFail($id);
        if ($run->finished_at !== null) {
            throw DomainError::invalid('Tugas ini sudah selesai dicatat.', 'alreadyFinished');
        }

        $now = now();
        $run->fill([
            'finished_at' => $now,
            'duration_ms' => (int) round($run->started_at->diffInMilliseconds($now, true)),
            'answer_room' => $data['answerRoom'] ?? null,
            'answer_end_time' => $data['answerEndTime'] ?? null,
            'notes' => $data['notes'] ?? null,
        ]);

        if ($run->target_session_id && ($target = ClassSession::find($run->target_session_id))) {
            $run->expected_room = $target->room;
            $run->expected_end_time = Fmt::time($target->end_at);
            if ($run->answer_room !== null || $run->answer_end_time !== null) {
                $run->is_correct = $this->normRoom($run->answer_room) === $this->normRoom($target->room)
                    && $this->normTime($run->answer_end_time) === $run->expected_end_time;
            }
        }
        if (array_key_exists('isCorrect', $data) && $data['isCorrect'] !== null) {
            $run->is_correct = (bool) $data['isCorrect'];
        }
        $run->save();

        return response()->json(['data' => $this->present($run)]);
    }

    /** Petugas see all runs, others only their own; with a per-method summary. */
    public function index(Request $request): JsonResponse
    {
        $runs = $this->visibleRuns($request->user())->get();

        return response()->json([
            'data' => $runs->map(fn ($r) => $this->present($r))->values(),
            'summary' => $this->summary($runs),
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        $this->assertPetugas($request->user());
        $runs = $this->visibleRuns($request->user())->get();

        return response()->streamDownload(function () use ($runs) {
            $out = fopen('php://output', 'w');
            fputcsv($out, ['id', 'participant_code', 'task', 'method', 'started_at', 'finished_at', 'duration_s',
                'answer_room', 'answer_end_time', 'expected_room', 'expected_end_time', 'is_correct', 'notes']);
            foreach ($runs as $r) {
                fputcsv($out, [$r->id, $r->participant_code, $r->task, $r->method,
                    $r->started_at?->toIso8601String(), $r->finished_at?->toIso8601String(),
                    $r->duration_ms !== null ? round($r->duration_ms / 1000, 2) : '',
                    $r->answer_room, $r->answer_end_time, $r->expected_room, $r->expected_end_time,
                    $r->is_correct === null ? '' : ($r->is_correct ? '1' : '0'), $r->notes]);
            }
            fclose($out);
        }, 'ruangin-uji-pengguna-'.now()->format('Ymd-His').'.csv', ['Content-Type' => 'text/csv']);
    }

    /** Delay between a notification being created (= change saved) and first seen in the app. */
    public function notificationLatency(Request $request): JsonResponse
    {
        $this->assertPetugas($request->user());
        $data = $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);

        $rows = AppNotification::query()
            ->whereNotNull('seen_at')
            ->when($data['date'] ?? null, fn ($q, $d) => $q->whereDate('created_at', $d))
            ->orderByDesc('created_at')
            ->limit(1000)
            ->get()
            ->map(fn ($n) => [
                'notificationId' => $n->id,
                'recipientId' => $n->recipient_id,
                'sessionId' => $n->class_session_id,
                'kind' => $n->kind,
                'createdAt' => $n->created_at->toIso8601String(),
                'seenAt' => $n->seen_at->toIso8601String(),
                'latencySeconds' => max(0, $n->created_at->diffInSeconds($n->seen_at, true)),
            ]);

        $byKind = $rows->groupBy('kind')->map(fn (Collection $g) => $this->stats($g->pluck('latencySeconds')));

        return response()->json([
            'data' => $rows->values(),
            'summary' => ['all' => $this->stats($rows->pluck('latencySeconds')), 'byKind' => $byKind],
        ]);
    }

    private function visibleRuns(User $user)
    {
        return TestRun::query()
            ->when($user->role !== UserRole::Petugas, fn ($q) => $q->where('user_id', $user->id))
            ->orderByDesc('started_at')
            ->limit(2000);
    }

    private function summary(Collection $runs): array
    {
        return collect(['biasa', 'ruangin'])->mapWithKeys(function ($m) use ($runs) {
            $done = $runs->where('method', $m)->whereNotNull('finished_at');
            $judged = $done->whereNotNull('is_correct');

            return [$m => [
                'finished' => $done->count(),
                'durationSeconds' => $this->stats($done->pluck('duration_ms')->map(fn ($ms) => $ms / 1000)),
                'correctRate' => $judged->count() ? round($judged->where('is_correct', true)->count() / $judged->count(), 3) : null,
            ]];
        })->all();
    }

    /** @param Collection<int, float|int> $values */
    private function stats(Collection $values): array
    {
        $v = $values->filter(fn ($x) => $x !== null)->sort()->values();
        $n = $v->count();
        if ($n === 0) {
            return ['n' => 0, 'mean' => null, 'median' => null, 'max' => null];
        }
        $median = $n % 2 ? $v[intdiv($n, 2)] : ($v[$n / 2 - 1] + $v[$n / 2]) / 2;

        return ['n' => $n, 'mean' => round($v->avg(), 2), 'median' => round($median, 2), 'max' => round($v->last(), 2)];
    }

    private function present(TestRun $r): array
    {
        return [
            'id' => $r->id,
            'userId' => $r->user_id,
            'participantCode' => $r->participant_code,
            'task' => $r->task,
            'method' => $r->method,
            'targetSessionId' => $r->target_session_id,
            'startedAt' => $r->started_at->toIso8601String(),
            'finishedAt' => $r->finished_at?->toIso8601String(),
            'durationSeconds' => $r->duration_ms !== null ? round($r->duration_ms / 1000, 2) : null,
            'answerRoom' => $r->answer_room,
            'answerEndTime' => $r->answer_end_time,
            'expectedRoom' => $r->expected_room,
            'expectedEndTime' => $r->expected_end_time,
            'isCorrect' => $r->is_correct,
            'notes' => $r->notes,
        ];
    }

    private function normRoom(?string $room): string
    {
        $r = mb_strtolower(trim((string) $room));

        return preg_replace('/\s+/', ' ', preg_replace('/^ruang(an)?\s*/', '', $r));
    }

    /** "10:00", "10.00", "10" -> "10.00" */
    private function normTime(?string $t): ?string
    {
        if ($t === null || ! preg_match('/^\s*(\d{1,2})(?:[.:](\d{2}))?\s*$/', $t, $m)) {
            return null;
        }

        return str_pad($m[1], 2, '0', STR_PAD_LEFT).'.'.($m[2] ?? '00');
    }

    private function assertPetugas(User $user): void
    {
        if ($user->role !== UserRole::Petugas) {
            throw DomainError::forbidden('Hasil uji hanya bisa dilihat petugas akademik.');
        }
    }
}
