import 'package:flutter/foundation.dart';

/// A student's "ruang kosong" report. It is informational only and never
/// changes the session status until confirmed by a lecturer/officer
/// (confirmation is out of scope for M1).
@immutable
class EmptyRoomReport {
  const EmptyRoomReport({
    required this.id,
    required this.sessionId,
    required this.reporterId,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String reporterId;
  final DateTime createdAt;

  static const confirmationLabel = 'belum dikonfirmasi';

  factory EmptyRoomReport.fromJson(Map<String, dynamic> json) =>
      EmptyRoomReport(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        reporterId: json['reporterId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'reporterId': reporterId,
        'createdAt': createdAt.toIso8601String(),
      };
}
