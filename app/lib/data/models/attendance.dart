import 'package:flutter/foundation.dart';

import 'json.dart';
import 'lecturer.dart';

/// Where a session stands in a lecturer's attendance summary
/// (`GET /lecturers/{id}/attendance`). A finished session without an
/// attendance record is [belumTerkonfirmasi] — never "tidak hadir" (PRD).
enum AttendanceMark {
  tercatat,
  belumTerkonfirmasi,
  batal,

  /// No record yet and the session has not ended.
  belumBerlangsung;

  static AttendanceMark parse(Object? raw) => AttendanceMark.values.firstWhere(
    (m) => m.name == raw,
    orElse: () => belumTerkonfirmasi,
  );
}

@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.tercatat,
    required this.belumTerkonfirmasi,
    required this.batal,
    required this.belumBerlangsung,
    required this.counted,
    required this.rate,
  });

  final int total;
  final int tercatat;
  final int belumTerkonfirmasi;
  final int batal;
  final int belumBerlangsung;

  /// tercatat + belumTerkonfirmasi (cancelled and upcoming are left out).
  final int counted;

  /// tercatat / counted, 0..1; null when nothing is counted yet.
  final double? rate;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AttendanceSummary(
      total: n('total'),
      tercatat: n('tercatat'),
      belumTerkonfirmasi: n('belumTerkonfirmasi'),
      batal: n('batal'),
      belumBerlangsung: n('belumBerlangsung'),
      counted: n('counted'),
      rate: (json['rate'] as num?)?.toDouble(),
    );
  }
}

/// One numbered meeting ("Pertemuan n") of a course.
@immutable
class AttendanceMeeting {
  const AttendanceMeeting({
    required this.number,
    required this.sessionId,
    required this.start,
    required this.end,
    required this.room,
    required this.building,
    required this.mark,
  });

  final int number;
  final String sessionId;
  final DateTime start;
  final DateTime end;
  final String room;
  final String? building;
  final AttendanceMark mark;

  factory AttendanceMeeting.fromJson(Map<String, dynamic> json) =>
      AttendanceMeeting(
        number: (json['number'] as num).toInt(),
        sessionId: json['sessionId'] as String,
        start: parseApiDate(json['start']),
        end: parseApiDate(json['end']),
        room: json['room'] as String? ?? '',
        building: json['building'] as String?,
        mark: AttendanceMark.parse(json['status']),
      );
}

@immutable
class CourseAttendance {
  const CourseAttendance({
    required this.courseName,
    required this.prodi,
    required this.summary,
    required this.meetings,
  });

  final String courseName;
  final String prodi;
  final AttendanceSummary summary;

  /// Numbered 1..n in time order.
  final List<AttendanceMeeting> meetings;

  factory CourseAttendance.fromJson(Map<String, dynamic> json) =>
      CourseAttendance(
        courseName: json['courseName'] as String,
        prodi: json['prodi'] as String? ?? '',
        summary: AttendanceSummary.fromJson(
          json['summary'] as Map<String, dynamic>,
        ),
        meetings: List.unmodifiable(
          (json['meetings'] as List<dynamic>? ?? []).map(
            (e) => AttendanceMeeting.fromJson(e as Map<String, dynamic>),
          ),
        ),
      );
}

@immutable
class SemesterInfo {
  const SemesterInfo({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
  });

  final String id;
  final String name;

  /// Calendar dates (local midnight).
  final DateTime startsOn;
  final DateTime endsOn;

  factory SemesterInfo.fromJson(Map<String, dynamic> json) => SemesterInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    startsOn: DateTime.parse(json['startsOn'] as String),
    endsOn: DateTime.parse(json['endsOn'] as String),
  );
}

/// `GET /lecturers/{id}/attendance`: the active semester of one lecturer.
@immutable
class LecturerAttendance {
  const LecturerAttendance({
    required this.lecturer,
    required this.semester,
    required this.summary,
    required this.courses,
  });

  final Lecturer? lecturer;
  final SemesterInfo semester;
  final AttendanceSummary summary;
  final List<CourseAttendance> courses;

  factory LecturerAttendance.fromJson(Map<String, dynamic> json) =>
      LecturerAttendance(
        lecturer: json['lecturer'] is Map<String, dynamic>
            ? Lecturer.fromJson(json['lecturer'] as Map<String, dynamic>)
            : null,
        semester: SemesterInfo.fromJson(
          json['semester'] as Map<String, dynamic>,
        ),
        summary: AttendanceSummary.fromJson(
          json['summary'] as Map<String, dynamic>,
        ),
        courses: List.unmodifiable(
          (json['courses'] as List<dynamic>? ?? []).map(
            (e) => CourseAttendance.fromJson(e as Map<String, dynamic>),
          ),
        ),
      );
}
