<?php

namespace App\Http\Resources;

use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Same keys as Session.fromJson in app/lib/data/models/session.dart, plus
 * server-derived fields (status, version, per-viewer flags).
 *
 * Dates are ISO-8601 with the campus offset (+07:00). Dart's
 * DateTime.parse() returns these as UTC, so call .toLocal() before
 * formatting hours.
 */
class SessionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $request->user();
        $viewer = Viewer::of($request);

        return [
            'id' => $this->id,
            'lecturerId' => $this->lecturer_id,
            'lecturer' => new LecturerResource($this->whenLoaded('lecturer')),
            'courseName' => $this->course_name,
            'prodi' => $this->prodi,
            'start' => $this->start_at->toIso8601String(),
            'end' => $this->end_at->toIso8601String(),
            'room' => $this->room,
            // From the room catalog when the room was set; null if unknown.
            'building' => $this->building,
            'source' => $this->source,
            'updatedAt' => $this->updated_at->toIso8601String(),
            'isCancelled' => $this->is_cancelled,
            'attendance' => $this->attendance_recorded_at ? [
                'recordedAt' => $this->attendance_recorded_at->toIso8601String(),
                'source' => $this->attendance_source,
            ] : null,
            'history' => $this->whenLoaded('changes', fn () => $this->changes->map(fn ($c) => [
                'at' => $c->at->toIso8601String(),
                'actor' => $c->actor,
                'description' => $c->description,
            ])->values()),
            'status' => $this->status(),
            'statusLabel' => $this->statusLabel(),
            'statusExplanation' => $this->statusExplanation(),
            'version' => $this->version,
            'canEdit' => $user ? $user->canEditSession($this->resource) : false,
            'isFollowed' => $viewer->follows($this->id),
            'pendingReportCount' => $this->whenCounted('pendingReports'),
            'myReport' => $this->when(
                $this->relationLoaded('reports') && $user,
                fn () => ($r = $this->reports->firstWhere('reporter_id', $user->id)) ? new ReportResource($r) : null,
            ),
        ];
    }
}
