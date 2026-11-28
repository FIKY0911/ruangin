<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SessionResource;
use App\Models\ClassSession;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class MeController extends Controller
{
    /**
     * "Hari ini" card: today's sessions the user follows directly or through a
     * followed lecturer (by start time), the next one that has not ended yet,
     * and the unread notification count.
     */
    public function today(Request $request)
    {
        $user = $request->user();
        $now = now();

        $sessions = ClassSession::query()
            ->with('lecturer')
            ->whereBetween('start_at', [$now->copy()->startOfDay(), $now->copy()->endOfDay()])
            ->where(fn ($q) => $q
                ->whereIn('id', DB::table('follows')->where('user_id', $user->id)->select('class_session_id'))
                ->orWhereIn('lecturer_id', DB::table('lecturer_follows')->where('user_id', $user->id)->select('lecturer_id')))
            ->orderBy('start_at')
            ->orderBy('id')
            ->get();

        $next = $sessions->first(fn ($s) => ! $s->is_cancelled && $s->end_at->gte($now));

        return SessionResource::collection($sessions)->additional([
            'date' => $now->toDateString(),
            'nextSessionId' => $next?->id,
            'unreadCount' => $user->appNotifications()->retained()->whereNull('read_at')->count(),
            'points' => $user->points,
            'serverTime' => $now->toIso8601String(),
        ]);
    }

    /** P07: register this device's FCM token (idempotent; moves the token to the current user). */
    public function storeDevice(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['nullable', Rule::in(['android', 'ios', 'web'])],
        ]);

        DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            ['user_id' => $request->user()->id, 'platform' => $data['platform'] ?? 'android', 'last_seen_at' => now()],
        );

        return response()->json(['registered' => true]);
    }

    /** P07: unregister on logout. */
    public function destroyDevice(Request $request): JsonResponse
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:512']]);
        DeviceToken::where('token', $data['token'])->where('user_id', $request->user()->id)->delete();

        return response()->json(['registered' => false]);
    }
}
