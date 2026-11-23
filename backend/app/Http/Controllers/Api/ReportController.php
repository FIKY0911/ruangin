<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ReportResource;
use App\Models\EmptyRoomReport;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** P09 empty-room reports + confirmation queue for lecturers/officers. */
class ReportController extends Controller
{
    public function __construct(private readonly ReportService $reports) {}

    /** Student reports the room of a session as empty. Repeating returns the existing report (200). */
    public function store(Request $request, string $id): JsonResponse
    {
        [$report, $created] = $this->reports->report($request->user(), $id);

        return (new ReportResource($report))->response()->setStatusCode($created ? 201 : 200);
    }

    /** Queue of reports on sessions the user may edit. ?status=pending|confirmed|rejected|all */
    public function index(Request $request)
    {
        $data = $request->validate([
            'status' => ['nullable', Rule::in([EmptyRoomReport::PENDING, EmptyRoomReport::CONFIRMED, EmptyRoomReport::REJECTED, 'all'])],
        ]);
        $status = $data['status'] ?? EmptyRoomReport::PENDING;

        return ReportResource::collection($this->reports->queue($request->user(), $status === 'all' ? null : $status));
    }

    public function confirm(Request $request, string $id): ReportResource
    {
        return new ReportResource($this->reports->confirm($request->user(), $id)->load('session'));
    }

    public function reject(Request $request, string $id): ReportResource
    {
        return new ReportResource($this->reports->reject($request->user(), $id)->load('session'));
    }
}
