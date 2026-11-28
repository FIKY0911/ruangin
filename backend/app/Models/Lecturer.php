<?php

namespace App\Models;

use App\Models\Concerns\HasPrefixedStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Lecturer extends Model
{
    use HasPrefixedStringId;

    public const ID_PREFIX = 'l';

    protected $fillable = ['id', 'name', 'prodi', 'faculty'];

    public function sessions(): HasMany
    {
        return $this->hasMany(ClassSession::class);
    }

    public function followers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'lecturer_follows', 'lecturer_id', 'user_id');
    }
}
