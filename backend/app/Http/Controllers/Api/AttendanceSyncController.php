<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Models\ClassSession;
use App\Models\User;
use App\Services\SessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;

/**
 * P08 "RPC sinkron absensi": receives a batch of attendance records from the
 * (simulated) campus attendance system and marks matching sessions
 * "Tercatat".
 *
 * Callers authenticate either with the shared secret header
 * `X-Sync-Key: <RUANGIN_SYNC_KEY>` (a campus feed / script) or as a signed-in
 * petugas (the demo panel), who can only sync sessions in their prodi scope.
 */
class AttendanceSyncController extends Controller
{
    public function __construct(private readonly SessionService $sessions) {}

    public function __invoke(Request $request): JsonResponse
    {
        $officer = $this->authorizeCaller($request);

        $data = $request->validate([
            'records' => ['required', 'array', 'min:1', 'max:500'],
            'records.*.externalId' => ['required_without:records.*.sessionId', 'nullable', 'string', 'max:64'],
            'records.*.sessionId' => ['required_without:records.*.externalId', 'nullable', 'string', 'max:64'],
            'records.*.recordedAt' => ['nullable', 'date'],
        ]);

        $results = [];
        foreach ($data['records'] as $i => $record) {
            $key = $record['externalId'] ?? $record['sessionId'];
            $session = isset($record['externalId'])
                ? ClassSession::where('external_id', $record['externalId'])->first()
                : ClassSession::find($record['sessionId']);

            $status = match (true) {
                $session === null => 'notFound',
                $officer !== null && ! $officer->canEditSession($session) => 'forbidden',
                $session->is_cancelled => 'cancelled',
                $session->attendance_recorded_at !== null => 'alreadyRecorded',
                default => null,
            };

            if ($status === null) {
                $at = isset($record['recordedAt'])
                    ? Carbon::parse($record['recordedAt'])->setTimezone(config('app.timezone'))
                    : now();
                $status = $this->sessions->recordAttendanceFromSync($session, $at) ? 'recorded' : 'alreadyRecorded';
            }

            $results[] = ['index' => $i, 'key' => $key, 'sessionId' => $session?->id, 'status' => $status];
        }

        return response()->json([
            'recorded' => count(array_filter($results, fn ($r) => $r['status'] === 'recorded')),
            'results' => $results,
        ]);
    }

    /** @return User|null the officer, or null when authenticated by sync key */
    private function authorizeCaller(Request $request): ?User
    {
        $expected = (string) config('ruangin.sync_key');
        $given = (string) $request->header('X-Sync-Key', '');
        if ($expected !== '' && $given !== '' && hash_equals($expected, $given)) {
            return null;
        }

        $user = Auth::guard('sanctum')->user();
        if ($user instanceof User && $user->role === UserRole::Petugas) {
            return $user;
        }

        throw new DomainError('Kunci sinkron tidak valid atau Anda bukan petugas akademik.', 'unauthorized', 401);
    }
}
