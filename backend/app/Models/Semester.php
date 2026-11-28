<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Model;

/** An academic semester; [starts_on, ends_on] are inclusive campus dates. */
class Semester extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['id', 'name', 'starts_on', 'ends_on'];

    protected function casts(): array
    {
        return ['starts_on' => 'date', 'ends_on' => 'date'];
    }

    /** The semester containing $now's date (latest start wins), or null. */
    public static function current(?CarbonInterface $now = null): ?self
    {
        $today = ($now ?? now())->toDateString();

        return static::query()
            // whereDate: SQLite stores the date cast as "Y-m-d 00:00:00", so a
            // plain string comparison would miss the first day.
            ->whereDate('starts_on', '<=', $today)
            ->whereDate('ends_on', '>=', $today)
            ->orderByDesc('starts_on')
            ->first();
    }
}
