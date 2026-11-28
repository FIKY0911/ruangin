<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Data the latest mobile designs need (image/ui-ux/):
 * - building ("Gedung") per room, so a session can show "Gedung A · Ruang A201";
 * - semesters, for the per-semester attendance summary of a lecturer;
 * - following a lecturer (all of their sessions), next to following a session.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Room catalog: which building a room is in. A session keeps its own
        // copy (class_sessions.building) taken from here whenever its room is
        // set, so lists need no join. Unknown rooms simply have no building.
        Schema::create('rooms', function (Blueprint $table) {
            $table->string('name', 100)->primary();
            $table->string('building', 100);
            $table->timestamps();
        });

        Schema::table('class_sessions', function (Blueprint $table) {
            $table->string('building', 100)->nullable()->after('room');
        });

        // The active semester is the one whose [starts_on, ends_on] contains today.
        Schema::create('semesters', function (Blueprint $table) {
            $table->string('id', 64)->primary();
            $table->string('name', 100);
            $table->date('starts_on');
            $table->date('ends_on');
            $table->timestamps();

            $table->index(['starts_on', 'ends_on']);
        });

        // Following a lecturer = being notified about every session of theirs.
        Schema::create('lecturer_follows', function (Blueprint $table) {
            $table->string('user_id', 64);
            $table->string('lecturer_id', 64);
            $table->timestamp('created_at')->nullable();

            $table->primary(['user_id', 'lecturer_id']);
            $table->index('lecturer_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('lecturer_id')->references('id')->on('lecturers')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lecturer_follows');
        Schema::dropIfExists('semesters');
        Schema::table('class_sessions', fn (Blueprint $table) => $table->dropColumn('building'));
        Schema::dropIfExists('rooms');
    }
};
