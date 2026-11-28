<?php

namespace App\Http\Resources;

use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Same shape as Lecturer.fromJson in app/lib/data/models/lecturer.dart.
 * isFollowed: the signed-in user follows this lecturer (all their sessions).
 */
class LecturerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'prodi' => $this->prodi,
            'faculty' => $this->faculty,
            'isFollowed' => Viewer::of($request)->followsLecturer($this->id),
        ];
    }
}
