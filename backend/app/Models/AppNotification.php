<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
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

    /**
     * Notifications still inside the retention window
     * (config ruangin.notification_retention_days, 0 = all), so the
     * "dihapus setelah N hari" note holds even before the prune job runs.
     */
    public function scopeRetained(Builder $query): Builder
    {
        $cutoff = self::retentionCutoff();

        return $cutoff ? $query->where('created_at', '>=', $cutoff) : $query;
    }

    /** Oldest created_at that is kept, or null when nothing expires. */
    public static function retentionCutoff(): ?CarbonInterface
    {
        $days = (int) config('ruangin.notification_retention_days');

        return $days > 0 ? now()->subDays($days) : null;
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
