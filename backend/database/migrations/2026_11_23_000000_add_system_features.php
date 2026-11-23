<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Mode uji: when the notification was first shown in the app, to
        // measure "jeda dari perubahan disimpan sampai notifikasi terlihat".
        Schema::table('app_notifications', function (Blueprint $table) {
            $table->timestamp('seen_at')->nullable()->after('body');
        });

        // P07: FCM registration tokens per device.
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->string('user_id', 64);
            $table->string('token', 512)->unique();
            $table->string('platform', 20)->default('android');
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        // Mode uji: task-based user test (PRD §3), "cara biasa" vs "Ruangin".
        Schema::create('test_runs', function (Blueprint $table) {
            $table->string('id', 64)->primary();
            $table->string('user_id', 64);
            $table->string('participant_code', 50)->index();
            $table->string('task', 200);
            $table->enum('method', ['biasa', 'ruangin']);
            // Session whose latest room/time is the correct answer (optional).
            $table->string('target_session_id', 64)->nullable();
            $table->timestamp('started_at', 3);
            $table->timestamp('finished_at', 3)->nullable();
            $table->unsignedInteger('duration_ms')->nullable();
            $table->string('answer_room', 100)->nullable();
            $table->string('answer_end_time', 10)->nullable();
            // Snapshot of the truth at finish time.
            $table->string('expected_room', 100)->nullable();
            $table->string('expected_end_time', 10)->nullable();
            $table->boolean('is_correct')->nullable();
            $table->string('notes', 500)->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('target_session_id')->references('id')->on('class_sessions')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('test_runs');
        Schema::dropIfExists('device_tokens');
        Schema::table('app_notifications', fn (Blueprint $table) => $table->dropColumn('seen_at'));
    }
};
