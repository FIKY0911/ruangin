<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SessionResource;
use App\Models\ClassSession;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** P04: follow / unfollow a session. Both are idempotent. */
class FollowController extends Controller
{
    public function index(Request $request)
    {
        $sessions = $request->user()->followedSessions()
            ->with('lecturer')
            ->orderBy('start_at')
            ->get();

        return SessionResource::collection($sessions)->additional([
            'sessionIds' => $sessions->pluck('id')->values(),
        ]);
    }

    public function store(Request $request, string $id): JsonResponse
    {
        $session = ClassSession::findOrFail($id);
        DB::table('follows')->insertOrIgnore([
            'user_id' => $request->user()->id,
            'class_session_id' => $session->id,
            'created_at' => now(),
        ]);

        return response()->json(['sessionId' => $session->id, 'isFollowed' => true]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::table('follows')
            ->where('user_id', $request->user()->id)
            ->where('class_session_id', $id)
            ->delete();

        return response()->json(['sessionId' => $id, 'isFollowed' => false]);
    }
}
