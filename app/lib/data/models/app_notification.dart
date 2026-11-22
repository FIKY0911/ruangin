import 'package:flutter/foundation.dart';

enum NotificationKind {
  /// Official change by a lecturer/officer.
  sessionChanged,

  /// A student report — always labelled "belum dikonfirmasi".
  emptyRoomReport,
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.sessionId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String recipientId;
  final String sessionId;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  AppNotification markRead() => AppNotification(
        id: id,
        recipientId: recipientId,
        sessionId: sessionId,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: true,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        recipientId: json['recipientId'] as String,
        sessionId: json['sessionId'] as String,
        kind: NotificationKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientId': recipientId,
        'sessionId': sessionId,
        'kind': kind.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };
}
