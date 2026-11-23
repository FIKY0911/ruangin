<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Same shape as Lecturer.fromJson in app/lib/data/models/lecturer.dart. */
class LecturerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'prodi' => $this->prodi,
            'faculty' => $this->faculty,
        ];
    }
}
