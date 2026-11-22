import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models/session.dart';
import '../../domain/session_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.session, this.dense = false});

  final Session session;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (session.status) {
      SessionStatus.tercatat =>
        (const Color(0xFFDCFCE7), const Color(0xFF166534), Icons.check_circle),
      SessionStatus.belumTerkonfirmasi =>
        (const Color(0xFFFEF3C7), const Color(0xFF92400E), Icons.help_outline),
      SessionStatus.batal =>
        (const Color(0xFFFEE2E2), const Color(0xFF991B1B), Icons.cancel_outlined),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              session.statusLabel,
              style: TextStyle(
                  color: fg, fontSize: dense ? 11 : 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.onTap,
    this.subtitlePrefix,
    this.isFollowed = false,
    this.showDate = false,
  });

  final Session session;
  final VoidCallback onTap;
  final String? subtitlePrefix;
  final bool isFollowed;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = session.isCancelled;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        key: Key('session-${session.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatTime(session.start),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('s.d. ${formatTime(session.end)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        ?subtitlePrefix,
                        if (showDate) formatShortDate(session.start),
                        session.room,
                        'Prodi ${session.prodi}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    StatusChip(session: session, dense: true),
                  ],
                ),
              ),
              if (isFollowed)
                Icon(Icons.notifications_active,
                    size: 20, color: theme.colorScheme.primary,
                    semanticLabel: 'Diikuti'),
            ],
          ),
        ),
      ),
    );
  }
}
