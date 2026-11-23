<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A student's "ruangan kosong" report (P09). Informational only: it never
 * changes the session status until a lecturer/officer confirms it.
 */
class EmptyRoomReport extends Model
{
    use HasPrefixedStringId;

    public const ID_PREFIX = 'r';

    public const PENDING = 'pending';
    public const CONFIRMED = 'confirmed';
    public const REJECTED = 'rejected';

    public const CONFIRMATION_LABEL = 'belum dikonfirmasi';

    protected $fillable = ['id', 'class_session_id', 'reporter_id', 'status', 'resolved_by', 'resolved_at', 'points_awarded'];

    protected function casts(): array
    {
        return ['resolved_at' => 'datetime', 'points_awarded' => 'integer'];
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(ClassSession::class, 'class_session_id');
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function resolver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }
}
