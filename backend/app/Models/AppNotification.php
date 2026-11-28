<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;
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

    /**
     * Deletes notifications older than the retention period, except the ones
     * that are user-test evidence: a notification that was seen (seen_at set)
     * on a day (campus date of created_at) when a mode-uji test run started
     * or finished. Those rows feed GET /test/notification-latency (PRD §3
     * "jeda notifikasi") and are kept. They stay hidden from the user's own
     * list because of retained().
     *
     * @return int number of notifications deleted (0 when retention is off)
     */
    public static function pruneExpired(): int
    {
        $cutoff = self::retentionCutoff();
        if ($cutoff === null) {
            return 0;
        }

        $tz = config('app.timezone');
        $testDays = TestRun::query()
            ->get(['started_at', 'finished_at'])
            ->flatMap(fn (TestRun $r) => array_filter([$r->started_at, $r->finished_at]))
            ->map(fn ($t) => $t->copy()->setTimezone($tz)->toDateString())
            ->unique()
            ->values();

        return static::query()
            ->where('created_at', '<', $cutoff)
            ->where(function (Builder $q) use ($testDays, $tz) {
                $q->whereNull('seen_at');
                if ($testDays->isNotEmpty()) {
                    $q->orWhere(function (Builder $seen) use ($testDays, $tz) {
                        foreach ($testDays as $day) {
                            $start = Carbon::parse($day, $tz)->startOfDay();
                            $seen->whereNot(fn (Builder $d) => $d
                                ->where('created_at', '>=', $start)
                                ->where('created_at', '<', $start->copy()->addDay()));
                        }
                    });
                } else {
                    $q->orWhereNotNull('seen_at');
                }
            })
            ->delete();
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
