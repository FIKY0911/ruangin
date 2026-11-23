<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "class_sessions" (not "sessions") to avoid clashing with Laravel's
        // HTTP session table.
        Schema::create('class_sessions', function (Blueprint $table) {
            $table->string('id', 64)->primary();
            $table->string('lecturer_id', 64);
            // Id of this session in the (simulated) campus attendance system.
            $table->string('external_id', 64)->nullable()->unique();
            $table->string('course_name');
            $table->string('prodi')->index();
            $table->dateTime('start_at');
            $table->dateTime('end_at');
            $table->string('room');
            // Where the latest information came from (shown in the app).
            $table->string('source');
            $table->boolean('is_cancelled')->default(false);
            $table->dateTime('attendance_recorded_at')->nullable();
            $table->string('attendance_source')->nullable();
            // Optimistic locking: edits sent with an older version get 409.
            $table->unsignedInteger('version')->default(1);
            // Set once followers of later sessions got the early warning (P11).
            $table->dateTime('early_warning_sent_at')->nullable();
            $table->timestamps();

            $table->foreign('lecturer_id')->references('id')->on('lecturers')->cascadeOnDelete();
            $table->index(['lecturer_id', 'start_at']);
            $table->index('start_at');
        });

        Schema::create('session_changes', function (Blueprint $table) {
            $table->id();
            $table->string('class_session_id', 64);
            $table->dateTime('at');
            $table->string('actor');
            $table->string('description', 500);

            $table->foreign('class_session_id')->references('id')->on('class_sessions')->cascadeOnDelete();
            $table->index(['class_session_id', 'at']);
        });

        Schema::create('follows', function (Blueprint $table) {
            $table->string('user_id', 64);
            $table->string('class_session_id', 64);
            $table->timestamp('created_at')->nullable();

            $table->primary(['user_id', 'class_session_id']);
            $table->index('class_session_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('class_session_id')->references('id')->on('class_sessions')->cascadeOnDelete();
        });

        Schema::create('app_notifications', function (Blueprint $table) {
            $table->string('id', 64)->primary();
            $table->string('recipient_id', 64);
            $table->string('class_session_id', 64);
            $table->enum('kind', ['sessionChanged', 'emptyRoomReport', 'earlyWarning', 'reportResolved']);
            $table->string('title', 500);
            $table->text('body');
            $table->timestamp('read_at')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->index(['recipient_id', 'created_at']);
            $table->foreign('recipient_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('class_session_id')->references('id')->on('class_sessions')->cascadeOnDelete();
        });

        Schema::create('empty_room_reports', function (Blueprint $table) {
            $table->string('id', 64)->primary();
            $table->string('class_session_id', 64);
            $table->string('reporter_id', 64);
            $table->enum('status', ['pending', 'confirmed', 'rejected'])->default('pending');
            $table->string('resolved_by', 64)->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->unsignedInteger('points_awarded')->default(0);
            $table->timestamps();

            // One report per student per session.
            $table->unique(['class_session_id', 'reporter_id']);
            $table->index(['status', 'created_at']);
            $table->index(['reporter_id', 'created_at']);
            $table->foreign('class_session_id')->references('id')->on('class_sessions')->cascadeOnDelete();
            $table->foreign('reporter_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('resolved_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('empty_room_reports');
        Schema::dropIfExists('app_notifications');
        Schema::dropIfExists('follows');
        Schema::dropIfExists('session_changes');
        Schema::dropIfExists('class_sessions');
    }
};
