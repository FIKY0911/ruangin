<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SessionResource;
use App\Models\ClassSession;
use App\Services\ReportService;
use App\Services\SessionService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class SessionController extends Controller
{
    public function __construct(
        private readonly SessionService $sessions,
        private readonly ReportService $reports,
    ) {}

    /**
     * All sessions on a date (the "Kelola" list). ?editable=1 limits the list
     * to sessions the signed-in user may edit.
     */
    public function index(Request $request)
    {
        $data = $request->validate([
            'date' => ['nullable', 'date_format:Y-m-d'],
            'editable' => ['nullable', 'boolean'],
        ]);
        $date = isset($data['date']) ? Carbon::createFromFormat('Y-m-d', $data['date']) : now();

        $sessions = ClassSession::query()
            ->with('lecturer')
            ->withCount('pendingReports')
            ->whereBetween('start_at', [$date->copy()->startOfDay(), $date->copy()->endOfDay()])
            ->when($request->boolean('editable'), fn ($q) => $this->reports->scopeEditable($q, $request->user()))
            ->orderBy('start_at')
            ->get();

        return SessionResource::collection($sessions)->additional(['date' => $date->toDateString()]);
    }

    /** P03: detail with history, viewer's follow state and own report. */
    public function show(Request $request, string $id): SessionResource
    {
        $session = ClassSession::with([
            'lecturer',
            'changes',
            'reports' => fn ($q) => $q->where('reporter_id', $request->user()->id),
        ])->withCount('pendingReports')->findOrFail($id);

        return new SessionResource($session);
    }

    public function changeTime(Request $request, string $id): SessionResource
    {
        $data = $request->validate([
            'version' => ['required', 'integer'],
            'start' => ['required', 'date'],
            'end' => ['required', 'date'],
        ], $this->messages());

        $session = $this->sessions->changeTime(
            $request->user(),
            $id,
            (int) $data['version'],
            Carbon::parse($data['start'])->setTimezone(config('app.timezone')),
            Carbon::parse($data['end'])->setTimezone(config('app.timezone')),
        );

        return $this->detail($session);
    }

    public function changeRoom(Request $request, string $id): SessionResource
    {
        $data = $request->validate([
            'version' => ['required', 'integer'],
            'room' => ['required', 'string', 'max:100'],
        ], $this->messages() + ['room.required' => 'Ruang tidak boleh kosong.']);

        return $this->detail($this->sessions->changeRoom($request->user(), $id, (int) $data['version'], $data['room']));
    }

    public function cancel(Request $request, string $id): SessionResource
    {
        $data = $request->validate([
            'version' => ['required', 'integer'],
            'reason' => ['nullable', 'string', 'max:200'],
        ], $this->messages());

        return $this->detail($this->sessions->cancel($request->user(), $id, (int) $data['version'], $data['reason'] ?? null));
    }

    public function recordAttendance(Request $request, string $id): SessionResource
    {
        $data = $request->validate(['version' => ['required', 'integer']], $this->messages());

        return $this->detail($this->sessions->recordAttendance($request->user(), $id, (int) $data['version']));
    }

    private function detail(ClassSession $session): SessionResource
    {
        return new SessionResource($session->load(['lecturer', 'changes'])->loadCount('pendingReports'));
    }

    private function messages(): array
    {
        return [
            'version.required' => 'Versi sesi wajib dikirim. Muat ulang sesi lalu coba lagi.',
            'start.required' => 'Jam mulai wajib diisi.',
            'end.required' => 'Jam selesai wajib diisi.',
        ];
    }
}
