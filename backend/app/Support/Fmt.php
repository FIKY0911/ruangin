<?php

namespace App\Support;

use DateTimeInterface;

/** Indonesian date/time text, identical to app/lib/core/formatters.dart. */
final class Fmt
{
    private const DAYS = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    private const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    /** "10.00" */
    public static function time(DateTimeInterface $t): string
    {
        return $t->format('H.i');
    }

    /** "07.30–10.00" */
    public static function timeRange(DateTimeInterface $start, DateTimeInterface $end): string
    {
        return self::time($start).'–'.self::time($end);
    }

    /** "Minggu, 22 Nov 2026" */
    public static function date(DateTimeInterface $d): string
    {
        return self::DAYS[(int) $d->format('N') - 1].', '.(int) $d->format('j').' '
            .self::MONTHS[(int) $d->format('n') - 1].' '.$d->format('Y');
    }
}
