<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * A user-presentable business-rule failure, rendered as
 * {"message": ..., "code": ..., "errors": {...}} with the given HTTP status.
 */
class DomainError extends RuntimeException
{
    /** @param array<string, list<string>> $errors */
    public function __construct(
        string $message,
        public readonly string $errorCode = 'invalidState',
        public readonly int $status = 422,
        public readonly array $errors = [],
    ) {
        parent::__construct($message);
    }

    public static function forbidden(string $message = 'Anda tidak berhak melakukan aksi ini.'): self
    {
        return new self($message, 'forbidden', 403);
    }

    public static function staleVersion(): self
    {
        return new self(
            'Sesi sudah diubah orang lain. Muat ulang lalu coba lagi.',
            'staleVersion',
            409,
        );
    }

    public static function invalid(string $message, string $code = 'invalidState'): self
    {
        return new self($message, $code, 422);
    }
}
