<?php

use App\Http\Controllers\Api\AttendanceSyncController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DemoController;
use App\Http\Controllers\Api\FollowController;
use App\Http\Controllers\Api\LecturerController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MessageDraftController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\TestModeController;
use Illuminate\Support\Facades\Route;

// All routes are prefixed with /api. Full reference: backend/README.md.

Route::get('/', fn () => ['name' => 'Ruangin API', 'status' => 'ok', 'time' => now()->toIso8601String()]);

Route::prefix('auth')->middleware('throttle:auth')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
});

// P08: X-Sync-Key header or a petugas bearer token (checked in the controller).
Route::post('sync/attendance', AttendanceSyncController::class)->middleware('throttle:60,1');

Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
    Route::get('auth/me', [AuthController::class, 'me']);
    Route::post('auth/logout', [AuthController::class, 'logout']);

    // P01 / P02
    Route::get('lecturers', [LecturerController::class, 'index']);
    Route::get('lecturers/{lecturer}', [LecturerController::class, 'show']);
    Route::get('lecturers/{lecturer}/timeline', [LecturerController::class, 'timeline']);

    // P03 / P05
    Route::get('sessions', [SessionController::class, 'index']);
    Route::get('sessions/{id}', [SessionController::class, 'show']);
    Route::post('sessions/{id}/time', [SessionController::class, 'changeTime']);
    Route::post('sessions/{id}/room', [SessionController::class, 'changeRoom']);
    Route::post('sessions/{id}/cancel', [SessionController::class, 'cancel']);
    Route::post('sessions/{id}/attendance', [SessionController::class, 'recordAttendance']);

    // P04
    Route::get('me/follows', [FollowController::class, 'index']);
    Route::put('sessions/{id}/follow', [FollowController::class, 'store']);
    Route::delete('sessions/{id}/follow', [FollowController::class, 'destroy']);

    // P06
    Route::get('me/notifications', [NotificationController::class, 'index']);
    Route::post('me/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('notifications/{id}/read', [NotificationController::class, 'markRead']);

    Route::post('me/notifications/seen', [NotificationController::class, 'markSeen']);

    // P09 / P10
    Route::post('sessions/{id}/reports', [ReportController::class, 'store']);
    Route::get('reports', [ReportController::class, 'index']);
    Route::post('reports/{id}/confirm', [ReportController::class, 'confirm']);
    Route::post('reports/{id}/reject', [ReportController::class, 'reject']);

    // P12 usulan pesan
    Route::get('sessions/{id}/message-draft', MessageDraftController::class);

    // Kartu "Hari ini" + P07 device tokens
    Route::get('me/today', [MeController::class, 'today']);
    Route::post('me/devices', [MeController::class, 'storeDevice']);
    Route::delete('me/devices', [MeController::class, 'destroyDevice']);

    // Mode uji
    Route::post('test-runs', [TestModeController::class, 'start']);
    Route::post('test-runs/{id}/finish', [TestModeController::class, 'finish']);
    Route::get('test-runs', [TestModeController::class, 'index']);
    Route::get('test-runs/export', [TestModeController::class, 'export']);
    Route::get('test/notification-latency', [TestModeController::class, 'notificationLatency']);

    // Panel demo (petugas, RUANGIN_DEMO_MODE=true)
    Route::post('demo/attendance-batch', [DemoController::class, 'attendanceBatch']);
    Route::post('demo/early-warnings', [DemoController::class, 'earlyWarnings']);
    Route::post('demo/reset', [DemoController::class, 'reset']);
});
