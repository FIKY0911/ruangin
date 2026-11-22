import 'package:flutter/foundation.dart';

/// Display status of a session. Derived, never stored directly, so the rule
/// "no attendance record => Belum terkonfirmasi, never Batal" holds everywhere.
enum SessionStatus { tercatat, belumTerkonfirmasi, batal }

@immutable
class AttendanceRecord {
  const AttendanceRecord({required this.recordedAt, required this.source});

  final DateTime recordedAt;
  final String source;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        source: json['source'] as String,
      );

  Map<String, dynamic> toJson() => {
        'recordedAt': recordedAt.toIso8601String(),
        'source': source,
      };
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
        at: DateTime.parse(json['at'] as String),
        actor: json['actor'] as String,
        description: json['description'] as String,
      );

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'actor': actor,
        'description': description,
      };
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

  /// Oldest first.
  final List<ChangeEntry> history;

  SessionStatus get status {
    if (isCancelled) return SessionStatus.batal;
    if (attendance != null) return SessionStatus.tercatat;
    return SessionStatus.belumTerkonfirmasi;
  }


  Session copyWith({
    DateTime? start,
    DateTime? end,
    String? room,
    String? source,
    DateTime? updatedAt,
    bool? isCancelled,
    AttendanceRecord? attendance,
    List<ChangeEntry>? history,
  }) =>
      Session(
        id: id,
        lecturerId: lecturerId,
        courseName: courseName,
        prodi: prodi,
        start: start ?? this.start,
        end: end ?? this.end,
        room: room ?? this.room,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
        isCancelled: isCancelled ?? this.isCancelled,
        attendance: attendance ?? this.attendance,
        history: history ?? this.history,
      );

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        lecturerId: json['lecturerId'] as String,
        courseName: json['courseName'] as String,
        prodi: json['prodi'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        room: json['room'] as String,
        source: json['source'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isCancelled: json['isCancelled'] as bool? ?? false,
        attendance: json['attendance'] == null
            ? null
            : AttendanceRecord.fromJson(
                json['attendance'] as Map<String, dynamic>),
        history: List.unmodifiable((json['history'] as List<dynamic>? ?? [])
            .map((e) => ChangeEntry.fromJson(e as Map<String, dynamic>))),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lecturerId': lecturerId,
        'courseName': courseName,
        'prodi': prodi,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'room': room,
        'source': source,
        'updatedAt': updatedAt.toIso8601String(),
        'isCancelled': isCancelled,
        'attendance': attendance?.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
      };
}
