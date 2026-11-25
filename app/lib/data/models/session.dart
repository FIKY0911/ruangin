import 'package:flutter/foundation.dart';

import 'empty_room_report.dart';
import 'json.dart';
import 'lecturer.dart';

/// Display status of a session. Computed by the server with the same rule as
/// [Session.status]: "no attendance record => Belum terkonfirmasi, never Batal".
enum SessionStatus { tercatat, belumTerkonfirmasi, batal }

@immutable
class AttendanceRecord {
  const AttendanceRecord({required this.recordedAt, required this.source});

  final DateTime recordedAt;
  final String source;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        recordedAt: parseApiDate(json['recordedAt']),
        source: json['source'] as String? ?? '',
      );
}

@immutable
class ChangeEntry {
  const ChangeEntry({
    required this.at,
    required this.actor,
    required this.description,
  });

  final DateTime at;
  final String actor;
  final String description;

  factory ChangeEntry.fromJson(Map<String, dynamic> json) => ChangeEntry(
    at: parseApiDate(json['at']),
    actor: json['actor'] as String? ?? '',
    description: json['description'] as String,
  );
}

@immutable
class Session {
  const Session({
    required this.id,
    required this.lecturerId,
    required this.courseName,
    required this.prodi,
    required this.start,
    required this.end,
    required this.room,
    required this.source,
    required this.updatedAt,
    this.isCancelled = false,
    this.attendance,
    this.history = const [],
    this.version = 0,
    this.canEdit = false,
    this.isFollowed = false,
    this.lecturer,
    this.pendingReportCount,
    this.myReport,
  });

  final String id;
  final String lecturerId;
  final String courseName;

  /// Prodi that owns this class (may differ from the lecturer's home prodi).
  final String prodi;
  final DateTime start;
  final DateTime end;
  final String room;

  /// Where the latest information came from.
  final String source;
  final DateTime updatedAt;
  final bool isCancelled;
  final AttendanceRecord? attendance;

  /// Oldest first. Only present on the detail endpoint.
  final List<ChangeEntry> history;

  /// Optimistic-locking version; every edit must send it back (409 if stale).
  final int version;

  /// Server-side permission for the signed-in user (P05).
  final bool canEdit;
  final bool isFollowed;
  final Lecturer? lecturer;

  /// Pending empty-room reports (list + detail endpoints).
  final int? pendingReportCount;

  /// The signed-in student's own report on this session (detail only).
  final EmptyRoomReport? myReport;

  SessionStatus get status {
    if (isCancelled) return SessionStatus.batal;
    if (attendance != null) return SessionStatus.tercatat;
    return SessionStatus.belumTerkonfirmasi;
  }

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    lecturerId: json['lecturerId'] as String,
    courseName: json['courseName'] as String,
    prodi: json['prodi'] as String,
    start: parseApiDate(json['start']),
    end: parseApiDate(json['end']),
    room: json['room'] as String,
    source: json['source'] as String? ?? '',
    updatedAt: parseApiDate(json['updatedAt']),
    isCancelled: json['isCancelled'] as bool? ?? false,
    attendance: json['attendance'] is Map<String, dynamic>
        ? AttendanceRecord.fromJson(json['attendance'] as Map<String, dynamic>)
        : null,
    history: List.unmodifiable(
      (json['history'] as List<dynamic>? ?? []).map(
        (e) => ChangeEntry.fromJson(e as Map<String, dynamic>),
      ),
    ),
    version: (json['version'] as num?)?.toInt() ?? 0,
    canEdit: json['canEdit'] as bool? ?? false,
    isFollowed: json['isFollowed'] as bool? ?? false,
    lecturer: json['lecturer'] is Map<String, dynamic>
        ? Lecturer.fromJson(json['lecturer'] as Map<String, dynamic>)
        : null,
    pendingReportCount: (json['pendingReportCount'] as num?)?.toInt(),
    myReport: json['myReport'] is Map<String, dynamic>
        ? EmptyRoomReport.fromJson(json['myReport'] as Map<String, dynamic>)
        : null,
  );
}

/// `GET /me/today`: followed sessions today + badge/points for Beranda.
@immutable
class TodaySummary {
  const TodaySummary({
    required this.sessions,
    required this.nextSessionId,
    required this.unreadCount,
    required this.points,
  });

  final List<Session> sessions;
  final String? nextSessionId;
  final int unreadCount;
  final int points;
}

/// P12 `GET /sessions/{id}/message-draft`: a polite message the student copies.
@immutable
class MessageDraft {
  const MessageDraft({
    required this.text,
    required this.proposedTime,
    required this.proposedPlace,
    required this.note,
  });

  final String text;
  final DateTime proposedTime;
  final String proposedPlace;
  final String note;

  factory MessageDraft.fromJson(Map<String, dynamic> json) => MessageDraft(
    text: json['text'] as String,
    proposedTime: parseApiDate(json['proposedTime']),
    proposedPlace: json['proposedPlace'] as String? ?? '',
    note: json['note'] as String? ?? '',
  );
}
