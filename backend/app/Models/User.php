<?php

namespace App\Models;

use App\Enums\UserRole;
use App\Models\Concerns\HasPrefixedStringId;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasPrefixedStringId;

    public const ID_PREFIX = 'u';

    // role, lecturer_id, scope_prodi and points are deliberately NOT fillable:
    // they are set by the server only (seed, register default, report points).
    protected $fillable = ['id', 'name', 'email', 'password', 'subtitle'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'role' => UserRole::class,
            'scope_prodi' => 'array',
            'points' => 'integer',
        ];
    }

    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(Lecturer::class);
    }

    public function followedSessions(): BelongsToMany
    {
        return $this->belongsToMany(ClassSession::class, 'follows', 'user_id', 'class_session_id')
            ->withPivot('created_at');
    }

    public function followedLecturers(): BelongsToMany
    {
        return $this->belongsToMany(Lecturer::class, 'lecturer_follows', 'user_id', 'lecturer_id')
            ->withPivot('created_at');
    }

    public function appNotifications(): HasMany
    {
        return $this->hasMany(AppNotification::class, 'recipient_id');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(EmptyRoomReport::class, 'reporter_id');
    }

    /** "Petugas akademik · Hendra Gunawan" — used as history actor / source. */
    public function actorLabel(): string
    {
        return $this->role->label().' · '.$this->name;
    }

    /** P05: lecturers edit only their own sessions, officers only their prodi scope. */
    public function canEditSession(ClassSession $session): bool
    {
        return match ($this->role) {
            UserRole::Mahasiswa => false,
            UserRole::Dosen => $this->lecturer_id !== null && $this->lecturer_id === $session->lecturer_id,
            UserRole::Petugas => in_array($session->prodi, $this->scope_prodi ?? [], true),
        };
    }

    public function canReportEmptyRoom(): bool
    {
        return $this->role === UserRole::Mahasiswa;
    }
}
