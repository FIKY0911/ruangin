import 'package:flutter/material.dart';

import '../../data/models/session.dart';
import '../../domain/session_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.session, this.dense = false});

  final Session session;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (session.status) {
      SessionStatus.tercatat => (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
        Icons.check_circle,
      ),
      SessionStatus.belumTerkonfirmasi => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        Icons.help_outline,
      ),
      SessionStatus.batal => (
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
        Icons.cancel_outlined,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              session.statusLabel,
              style: TextStyle(
                color: fg,
                fontSize: dense ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
