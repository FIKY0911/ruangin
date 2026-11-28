import 'package:flutter/foundation.dart';

/// `GET /app-config`: server facts shown as labels.
@immutable
class AppConfig {
  const AppConfig({
    required this.simulatedData,
    required this.notificationRetentionDays,
  });

  /// Nothing is claimed until the server says so.
  static const unknown = AppConfig(
    simulatedData: false,
    notificationRetentionDays: null,
  );

  /// All schedules and attendance are synthetic / simulated ("Simulasi").
  final bool simulatedData;

  /// "Notifikasi otomatis dihapus setelah N hari"; null = kept.
  final int? notificationRetentionDays;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    simulatedData: json['simulatedData'] as bool? ?? false,
    notificationRetentionDays: (json['notificationRetentionDays'] as num?)
        ?.toInt(),
  );
}
