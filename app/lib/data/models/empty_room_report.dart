import 'package:flutter/foundation.dart';

import 'json.dart';
import 'session.dart';

enum ReportStatus {
  pending('Belum dikonfirmasi'),
  confirmed('Dikonfirmasi'),
  rejected('Ditolak');

  const ReportStatus(this.label);
  final String label;

  static ReportStatus parse(String? raw) => ReportStatus.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => pending,
  );
}

/// A student's "ruang kosong" report (P09). It never changes the session
/// status until a lecturer/officer confirms it; a confirmed report cancels
/// the session and awards points to the reporters (P10).
@immutable
class EmptyRoomReport {
  const EmptyRoomReport({
    required this.id,
    required this.sessionId,
    required this.reporterId,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.resolvedAt,
    this.pointsAwarded = 0,
    this.session,
    this.reporterName,
  });

  final String id;
  final String sessionId;
  final String reporterId;
  final DateTime createdAt;
  final ReportStatus status;
  final DateTime? resolvedAt;
  final int pointsAwarded;

  /// Included in the confirmation queue (`GET /reports`).
  final Session? session;
  final String? reporterName;

  bool get isPending => status == ReportStatus.pending;

  static const confirmationLabel = 'belum dikonfirmasi';

  factory EmptyRoomReport.fromJson(Map<String, dynamic> json) =>
      EmptyRoomReport(
        id: '${json['id']}',
        sessionId: json['sessionId'] as String,
        reporterId: '${json['reporterId']}',
        createdAt: parseApiDate(json['createdAt']),
        status: ReportStatus.parse(json['status'] as String?),
        resolvedAt: parseApiDateOrNull(json['resolvedAt']),
        pointsAwarded: (json['pointsAwarded'] as num?)?.toInt() ?? 0,
        session: json['session'] is Map<String, dynamic>
            ? Session.fromJson(json['session'] as Map<String, dynamic>)
            : null,
        reporterName: json['reporterName'] as String?,
      );
}
