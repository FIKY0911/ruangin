<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

/**
 * String primary keys like "u-01jd…", matching the id style of the Flutter
 * app's seed ("a-nadia", "s-mobile-today"). Seeded rows set their own id.
 */
trait HasPrefixedStringId
{
    public static function bootHasPrefixedStringId(): void
    {
        static::creating(function ($model) {
            if (! $model->getKey()) {
                $model->{$model->getKeyName()} = static::ID_PREFIX.'-'.Str::lower((string) Str::ulid());
            }
        });
    }

    public function initializeHasPrefixedStringId(): void
    {
        $this->incrementing = false;
        $this->keyType = 'string';
    }
}
