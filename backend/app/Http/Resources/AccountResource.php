<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Same shape as Account.fromJson in app/lib/data/models/account.dart (+ points). */
class AccountResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role->value,
            'roleLabel' => $this->role->label(),
            'subtitle' => $this->subtitle,
            'lecturerId' => $this->lecturer_id,
            'scopeProdi' => $this->scope_prodi ?? [],
            'points' => $this->points,
        ];
    }
}
