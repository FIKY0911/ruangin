import 'package:flutter/foundation.dart';

/// `GET /app-config`: server facts shown as labels.
@immutable
class AppConfig {
  const AppConfig({
    required this.simulatedData,
    required this.notificationRetentionDays,
  });

  /// Before `/app-config` answers (or when it fails): keep the "Simulasi"
  /// label (the server default, and the safe side of PRD §10); claim no
  /// retention period.
  static const unknown = AppConfig(
    simulatedData: true,
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
