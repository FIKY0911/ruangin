<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Http\Resources\LecturerResource;
use App\Http\Resources\SessionResource;
use App\Models\ClassSession;
use App\Models\Lecturer;
use App\Models\Semester;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

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

    /**
     * riwayat_dosen.png / Profil_Dosen.png "Kehadiran semester ini": every
     * session of the lecturer in the active semester, as numbered meetings
     * ("Pertemuan 1–n") per course, plus totals.
     *
     * Marks follow the PRD: tercatat (attendance record), belumTerkonfirmasi
     * (finished without a record — never "tidak hadir"), batal (cancelled),
     * belumBerlangsung (no record and not ended yet). The rate is
     * tercatat / (tercatat + belumTerkonfirmasi); cancelled and upcoming
     * sessions are left out.
     */
    public function attendance(Request $request, Lecturer $lecturer): JsonResponse
    {
        $now = now();
        $semester = Semester::current($now);
        if ($semester === null) {
            throw new DomainError('Belum ada semester aktif.', 'notFound', 404);
        }

        $sessions = $lecturer->sessions()
            ->whereBetween('start_at', [$semester->starts_on->copy()->startOfDay(), $semester->ends_on->copy()->endOfDay()])
            ->orderBy('start_at')
            ->orderBy('id')
            ->get();

        $marks = $sessions->mapWithKeys(fn (ClassSession $s) => [$s->id => $s->attendanceMark($now)]);

        $courses = $sessions
            ->groupBy(fn (ClassSession $s) => $s->course_name."\n".$s->prodi)
            ->map(function (Collection $group) use ($marks) {
                $first = $group->first();

                return [
                    'courseName' => $first->course_name,
                    'prodi' => $first->prodi,
                    'summary' => $this->summary($group->map(fn ($s) => $marks[$s->id])),
                    'meetings' => $group->values()->map(fn (ClassSession $s, int $i) => [
                        'number' => $i + 1,
                        'sessionId' => $s->id,
                        'start' => $s->start_at->toIso8601String(),
                        'end' => $s->end_at->toIso8601String(),
                        'room' => $s->room,
                        'building' => $s->building,
                        'status' => $marks[$s->id],
                    ])->all(),
                ];
            })
            ->sortBy(fn (array $c) => mb_strtolower($c['courseName'])."\n".$c['prodi'])
            ->values();

        return response()->json(['data' => [
            'lecturer' => new LecturerResource($lecturer),
            'semester' => [
                'id' => $semester->id,
                'name' => $semester->name,
                'startsOn' => $semester->starts_on->toDateString(),
                'endsOn' => $semester->ends_on->toDateString(),
            ],
            'summary' => $this->summary($marks->values()),
            'courses' => $courses,
            'generatedAt' => $now->toIso8601String(),
        ]]);
    }

    /** @param Collection<int, string> $marks */
    private function summary(Collection $marks): array
    {
        $count = fn (string $mark) => $marks->filter(fn ($m) => $m === $mark)->count();
        $tercatat = $count(ClassSession::STATUS_TERCATAT);
        $belum = $count(ClassSession::STATUS_BELUM);
        $counted = $tercatat + $belum;

        return [
            'total' => $marks->count(),
            'tercatat' => $tercatat,
            'belumTerkonfirmasi' => $belum,
            'batal' => $count(ClassSession::STATUS_BATAL),
            'belumBerlangsung' => $count(ClassSession::MARK_UPCOMING),
            'counted' => $counted,
            'rate' => $counted === 0 ? null : round($tercatat / $counted, 4),
        ];
    }
}
