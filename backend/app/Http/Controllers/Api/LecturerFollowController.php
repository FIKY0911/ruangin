<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\LecturerResource;
use App\Models\Lecturer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Follow a lecturer ("Ikuti" on Profil_Dosen.png): the user is notified about
 * every session of that lecturer (changes, empty-room reports, early warnings)
 * and those sessions appear in "Hari ini". Both actions are idempotent.
 */
class LecturerFollowController extends Controller
{
    public function index(Request $request)
    {
        $lecturers = $request->user()->followedLecturers()->orderBy('name')->get();

        return LecturerResource::collection($lecturers)->additional([
            'lecturerIds' => $lecturers->pluck('id')->values(),
        ]);
    }

    public function store(Request $request, string $id): JsonResponse
    {
        $lecturer = Lecturer::findOrFail($id);
        DB::table('lecturer_follows')->insertOrIgnore([
            'user_id' => $request->user()->id,
            'lecturer_id' => $lecturer->id,
            'created_at' => now(),
        ]);

        return response()->json(['lecturerId' => $lecturer->id, 'isFollowed' => true]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::table('lecturer_follows')
            ->where('user_id', $request->user()->id)
            ->where('lecturer_id', $id)
            ->delete();

        return response()->json(['lecturerId' => $id, 'isFollowed' => false]);
    }
}
