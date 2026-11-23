<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use App\Support\Fmt;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * One teaching session ("sesi") of a lecturer.
 *
 * Status is derived, never stored, so the PRD rule "no attendance record =>
 * Belum terkonfirmasi, never Batal" holds everywhere.
 */
class ClassSession extends Model
{
    use HasPrefixedStringId;

    public const ID_PREFIX = 's';

    public const STATUS_TERCATAT = 'tercatat';
    public const STATUS_BELUM = 'belumTerkonfirmasi';
    public const STATUS_BATAL = 'batal';

    protected $fillable = [
        'id', 'lecturer_id', 'external_id', 'course_name', 'prodi', 'start_at', 'end_at',
        'room', 'source', 'is_cancelled', 'attendance_recorded_at', 'attendance_source',
    ];

    protected function casts(): array
    {
        return [
            'start_at' => 'datetime',
            'end_at' => 'datetime',
            'is_cancelled' => 'boolean',
            'attendance_recorded_at' => 'datetime',
            'early_warning_sent_at' => 'datetime',
            'version' => 'integer',
        ];
    }

    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(Lecturer::class);
    }

    public function changes(): HasMany
    {
        return $this->hasMany(SessionChange::class)->orderBy('at')->orderBy('id');
    }

    public function followers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'follows', 'class_session_id', 'user_id');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(EmptyRoomReport::class);
    }

    public function pendingReports(): HasMany
    {
        return $this->hasMany(EmptyRoomReport::class)->where('status', EmptyRoomReport::PENDING);
    }

    public function status(): string
    {
        if ($this->is_cancelled) {
            return self::STATUS_BATAL;
        }

        return $this->attendance_recorded_at ? self::STATUS_TERCATAT : self::STATUS_BELUM;
    }

    public function statusLabel(): string
    {
        return match ($this->status()) {
            self::STATUS_BATAL => 'Batal',
            self::STATUS_TERCATAT => 'Tercatat · Sinkron absensi '.Fmt::time($this->attendance_recorded_at),
            default => 'Belum terkonfirmasi',
        };
    }

    public function statusExplanation(): string
    {
        return match ($this->status()) {
            self::STATUS_TERCATAT => 'Kehadiran kelas tercatat di sistem absensi. "Tercatat" bukan berarti '
                .'dosen sedang ada di ruangan sekarang.',
            self::STATUS_BELUM => 'Belum ada catatan absensi untuk sesi ini. Ini bukan berarti batal — '
                .'cek lagi mendekati jam mulai.',
            default => 'Sesi dibatalkan oleh dosen/petugas.',
        };
    }
}
