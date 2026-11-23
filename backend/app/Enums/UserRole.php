<?php

namespace App\Enums;

enum UserRole: string
{
    case Mahasiswa = 'mahasiswa';
    case Dosen = 'dosen';
    case Petugas = 'petugas';

    public function label(): string
    {
        return match ($this) {
            self::Mahasiswa => 'Mahasiswa',
            self::Dosen => 'Dosen',
            self::Petugas => 'Petugas akademik',
        };
    }
}
