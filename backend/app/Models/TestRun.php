<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Mode uji: one timed task of a user-test participant (PRD §3). */
class TestRun extends Model
{
    use HasPrefixedStringId;

    public const ID_PREFIX = 't';

    protected $fillable = [
        'id', 'user_id', 'participant_code', 'task', 'method', 'target_session_id', 'started_at',
        'finished_at', 'duration_ms', 'answer_room', 'answer_end_time', 'expected_room',
        'expected_end_time', 'is_correct', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'duration_ms' => 'integer',
            'is_correct' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function targetSession(): BelongsTo
    {
        return $this->belongsTo(ClassSession::class, 'target_session_id');
    }
}
