<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Models\ClassSession;
use App\Services\EarlyWarningService;
use App\Services\ReportService;
use App\Services\SessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

/**
 * Demo panel (PRD §8 steps 6–7), petugas only, enabled by RUANGIN_DEMO_MODE.
 * Not a product feature: it simulates the campus attendance feed and the
 * scheduler so the demo can be driven from the app.
 */
class DemoController extends Controller
{
    public function __construct(
        private readonly SessionService $sessions,
        private readonly ReportService $reports,
        private readonly EarlyWarningService $earlyWarnings,
    ) {}

    /**
     * Simulated attendance batch. Without sessionIds: every session in the
     * officer's scope that started today and has no record yet. Each record is
     * timestamped a few minutes after the start (never in the future).
     */
    public function attendanceBatch(Request $request): JsonResponse
    {
        $officer = $this->officer($request);
        $data = $request->validate([
            'sessionIds' => ['nullable', 'array', 'max:200'],
            'sessionIds.*' => ['string', 'max:64'],
        ]);
        $now = now();

        $query = ClassSession::query()->where(fn ($q) => $this->reports->scopeEditable($q, $officer));
        if (! empty($data['sessionIds'])) {
            $query->whereIn('id', $data['sessionIds']);
        } else {
            $query->whereBetween('start_at', [$now->copy()->startOfDay(), $now])
                ->where('is_cancelled', false)
                ->whereNull('attendance_recorded_at');
        }

        $results = $query->orderBy('start_at')->get()->map(function (ClassSession $s) use ($now) {
            if ($s->is_cancelled) {
                return ['sessionId' => $s->id, 'status' => 'cancelled'];
            }
            $at = $s->start_at->copy()->addMinutes(4);
            $recorded = $this->sessions->recordAttendanceFromSync($s, $at->gt($now) ? $now->copy() : $at);

            return ['sessionId' => $s->id, 'status' => $recorded ? 'recorded' : 'alreadyRecorded'];
        });

        return response()->json([
            'recorded' => $results->where('status', 'recorded')->count(),
            'results' => $results->values(),
        ]);
    }

    /** Runs the P11 early-warning scan now instead of waiting for the scheduler. */
    public function earlyWarnings(Request $request): JsonResponse
    {
        $this->officer($request);

        return response()->json(['sent' => $this->earlyWarnings->run()]);
    }

    /** Wipes everything and re-seeds today's demo data. Signs everyone out. */
    public function reset(Request $request): JsonResponse
    {
        $this->officer($request);
        Artisan::call('migrate:fresh', ['--seed' => true, '--force' => true]);

        return response()->json(['message' => 'Data demo di-reset. Silakan masuk lagi.']);
    }

    private function officer(Request $request)
    {
        if (! config('ruangin.demo_mode')) {
            throw new DomainError('Mode demo tidak aktif.', 'notFound', 404);
        }
        $user = $request->user();
        if ($user->role !== UserRole::Petugas) {
            throw DomainError::forbidden('Panel demo hanya untuk petugas akademik.');
        }

        return $user;
    }
}
