<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\LecturerResource;
use App\Http\Resources\SessionResource;
use App\Models\Lecturer;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class LecturerController extends Controller
{
    /** P01: case-insensitive partial-name search; empty query returns all. */
    public function index(Request $request)
    {
        $data = $request->validate(['q' => ['nullable', 'string', 'max:100']]);
        $q = trim($data['q'] ?? '');

        $lecturers = Lecturer::query()
            ->when($q !== '', function ($query) use ($q) {
                $like = '%'.addcslashes(mb_strtolower($q), '%_\\').'%';
                $query->whereRaw('LOWER(name) LIKE ?', [$like]);
            })
            ->orderBy('name')
            ->limit(100)
            ->get();

        return LecturerResource::collection($lecturers);
    }

    public function show(Lecturer $lecturer): LecturerResource
    {
        return new LecturerResource($lecturer);
    }

    /** P02: sessions of the lecturer on a date, across all prodi, by start time. */
    public function timeline(Request $request, Lecturer $lecturer)
    {
        $data = $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);
        $date = isset($data['date']) ? Carbon::createFromFormat('Y-m-d', $data['date']) : now();

        $sessions = $lecturer->sessions()
            ->whereBetween('start_at', [$date->copy()->startOfDay(), $date->copy()->endOfDay()])
            ->orderBy('start_at')
            ->get();

        return SessionResource::collection($sessions)->additional([
            'lecturer' => new LecturerResource($lecturer),
            'date' => $date->toDateString(),
        ]);
    }
}
