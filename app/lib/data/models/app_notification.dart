import 'package:flutter/foundation.dart';

import 'json.dart';

enum NotificationKind {
  /// Official change by a lecturer/officer (or attendance sync).
  sessionChanged,

  /// A student report — always labelled "belum dikonfirmasi".
  emptyRoomReport,

  /// P11: an earlier session of the same lecturer today is still unconfirmed
  /// or was reported empty. Informational only.
  earlyWarning,

  /// The signed-in student's report was confirmed or rejected.
  reportResolved;

  /// Unknown kinds (added server-side later) fall back to [sessionChanged]
  /// instead of throwing like `byName` would.
  static NotificationKind parse(String? raw) => NotificationKind.values
      .firstWhere((k) => k.name == raw, orElse: () => sessionChanged);
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

  /// Session to open when tapped; may be empty for future kinds.
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
        id: '${json['id']}',
        recipientId: '${json['recipientId']}',
        sessionId: json['sessionId'] as String? ?? '',
        kind: NotificationKind.parse(json['kind'] as String?),
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        createdAt: parseApiDate(json['createdAt']),
        isRead: json['isRead'] as bool? ?? false,
      );
}

/// `GET /me/notifications`: newest first + the unread badge count.
@immutable
class NotificationPage {
  const NotificationPage(this.items, this.unreadCount);

  final List<AppNotification> items;
  final int unreadCount;
}
