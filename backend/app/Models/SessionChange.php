<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One entry of a session's change history ("riwayat perubahan"). */
class SessionChange extends Model
{
    public $timestamps = false;

    protected $fillable = ['class_session_id', 'at', 'actor', 'description'];

    protected function casts(): array
    {
        return ['at' => 'datetime'];
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(ClassSession::class, 'class_session_id');
    }
}
