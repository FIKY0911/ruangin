<?php

use App\Exceptions\DomainError;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Every /api error is JSON: {"message": ..., "code": ..., "errors"?: {field: [..]}}
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());

        $json = fn (string $message, string $code, int $status, array $errors = []) => response()->json(
            array_filter(['message' => $message, 'code' => $code, 'errors' => $errors ?: null], fn ($v) => $v !== null),
            $status,
        );

        $exceptions->render(fn (DomainError $e) => $json($e->getMessage(), $e->errorCode, $e->status, $e->errors));

        $exceptions->render(function (ValidationException $e, Request $request) use ($json) {
            if (! $request->is('api/*')) {
                return null;
            }

            return $json('Periksa kembali isian formulir.', 'invalidInput', 422, $e->errors());
        });

        $exceptions->render(function (AuthenticationException $e, Request $request) use ($json) {
            return $request->is('api/*') ? $json('Sesi login berakhir. Silakan masuk lagi.', 'unauthenticated', 401) : null;
        });

        $exceptions->render(function (NotFoundHttpException $e, Request $request) use ($json) {
            if (! $request->is('api/*')) {
                return null;
            }
            $message = $e->getPrevious() instanceof ModelNotFoundException ? 'Data tidak ditemukan.' : 'Endpoint tidak ditemukan.';

            return $json($message, 'notFound', 404);
        });

        $exceptions->render(function (ThrottleRequestsException $e, Request $request) use ($json) {
            return $request->is('api/*') ? $json('Terlalu banyak percobaan. Coba lagi sebentar lagi.', 'tooManyRequests', 429) : null;
        });

        $exceptions->render(function (HttpExceptionInterface $e, Request $request) use ($json) {
            if (! $request->is('api/*') || $e->getStatusCode() < 400 || $e->getStatusCode() >= 500) {
                return null;
            }

            return $json($e->getMessage() ?: 'Permintaan tidak valid.', 'httpError', $e->getStatusCode());
        });
    })->create();
