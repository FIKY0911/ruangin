<?php

namespace App\Http\Resources;

use App\Models\EmptyRoomReport;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Same keys as EmptyRoomReport.fromJson in app/lib/data/models/empty_room_report.dart (+ status). */
class ReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'sessionId' => $this->class_session_id,
            'reporterId' => $this->reporter_id,
            'createdAt' => $this->created_at->toIso8601String(),
            'status' => $this->status,
            'statusLabel' => match ($this->status) {
                EmptyRoomReport::CONFIRMED => 'Dikonfirmasi',
                EmptyRoomReport::REJECTED => 'Ditolak',
                default => 'Belum dikonfirmasi',
            },
            'resolvedAt' => $this->resolved_at?->toIso8601String(),
            'pointsAwarded' => $this->points_awarded,
            'session' => new SessionResource($this->whenLoaded('session')),
            'reporterName' => $this->whenLoaded('reporter', fn () => $this->reporter->name),
        ];
    }
}
