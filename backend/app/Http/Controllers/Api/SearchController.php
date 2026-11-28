<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\LecturerResource;
use App\Http\Resources\SessionResource;
use App\Models\ClassSession;
use App\Models\Lecturer;
use App\Support\Like;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * "Cari sesi, dosen, atau mata kuliah" (Beranda search, Hasil_cari1.png,
 * Tidak_ada_Hasil.png). Case-insensitive partial match on:
 * - lecturer name  -> lecturers
 * - course name or room -> sessions from today through the next 6 days
 *   (one week ahead), by start time, with the lecturer included.
 */
class SearchController extends Controller
{
    public const DAYS_AHEAD = 6;

    public const SESSION_LIMIT = 50;

    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate(
            ['q' => ['required', 'string', 'max:100']],
            ['q.required' => 'Kata kunci wajib diisi.', 'q.max' => 'Kata kunci maksimal 100 karakter.'],
        );
        $q = trim($data['q']);
        $like = Like::contains($q);

        $lecturers = Lecturer::query()
            ->whereRaw(Like::sql('name'), [$like])
            ->orderBy('name')
            ->limit(100)
            ->get();

        $from = now()->startOfDay();
        $to = $from->copy()->addDays(self::DAYS_AHEAD)->endOfDay();
        $sessions = ClassSession::query()
            ->with('lecturer')
            ->whereBetween('start_at', [$from, $to])
            ->where(fn ($w) => $w
                ->whereRaw(Like::sql('course_name'), [$like])
                ->orWhereRaw(Like::sql('room'), [$like]))
            ->orderBy('start_at')
            ->orderBy('id')
            ->limit(self::SESSION_LIMIT)
            ->get();

        return response()->json([
            'query' => $q,
            'lecturers' => LecturerResource::collection($lecturers)->resolve($request),
            'sessions' => SessionResource::collection($sessions)->resolve($request),
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
        ]);
    }
}
