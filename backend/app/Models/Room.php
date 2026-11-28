<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Room catalog: the building ("Gedung") a room is in. Keyed by room name. */
class Room extends Model
{
    protected $primaryKey = 'name';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['name', 'building'];

    /** Building of a room name (case-insensitive, trimmed), or null when unknown. */
    public static function buildingOf(string $room): ?string
    {
        $name = mb_strtolower(trim($room));
        if ($name === '') {
            return null;
        }

        return static::query()->whereRaw('LOWER(name) = ?', [$name])->value('building');
    }
}
