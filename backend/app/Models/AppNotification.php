<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * In-app notification (P06). Stored in the database so every P0 flow can be
 * demoed without push (FCM).
 *
 * kind: sessionChanged | emptyRoomReport | earlyWarning | reportResolved
 */
class AppNotification extends Model
{
    use HasPrefixedStringId;

    public const ID_PREFIX = 'n';

    public const UPDATED_AT = null;

    protected $fillable = ['id', 'recipient_id', 'class_session_id', 'kind', 'title', 'body', 'seen_at', 'read_at', 'created_at'];

    protected function casts(): array
    {
        return ['seen_at' => 'datetime', 'read_at' => 'datetime', 'created_at' => 'datetime'];
    }

    public function recipient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recipient_id');
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(ClassSession::class, 'class_session_id');
    }
}
