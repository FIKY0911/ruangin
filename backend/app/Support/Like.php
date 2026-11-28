<?php

namespace App\Support;

/**
 * Case-insensitive "contains" match that treats % and _ in the user's text
 * literally. Uses an explicit ESCAPE character because SQLite has no default
 * one (MySQL's default backslash would otherwise be the only thing working).
 */
final class Like
{
    private const ESCAPE = '!';

    /** "LOWER(column) LIKE ? ESCAPE '!'" for whereRaw/orWhereRaw. */
    public static function sql(string $column): string
    {
        return "LOWER({$column}) LIKE ? ESCAPE '".self::ESCAPE."'";
    }

    /** "%text%" with !, % and _ escaped, lower-cased. */
    public static function contains(string $text): string
    {
        $escaped = str_replace(
            [self::ESCAPE, '%', '_'],
            [self::ESCAPE.self::ESCAPE, self::ESCAPE.'%', self::ESCAPE.'_'],
            mb_strtolower($text),
        );

        return '%'.$escaped.'%';
    }
}
