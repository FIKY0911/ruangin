import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';
import '../widgets/ruangin_widgets.dart';
import '../widgets/session_widgets.dart';
import 'edit_session_controller.dart';

/// P05: lecturer/officer edits a session they own or cover.
/// Flow: ubah → cek lagi (confirm dialog) → simpan → lihat konfirmasi.
class EditSessionScreen extends StatelessWidget {
  const EditSessionScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => EditSessionController(
        session: session,
        actor: c.read<AuthController>().account!,
        repo: c.read<SessionRepository>(),
      ),
      child: const _EditView(),
    );
  }
}

class _EditView extends StatefulWidget {
  const _EditView();

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  late final TextEditingController _room = TextEditingController(
    text: context.read<EditSessionController>().draftRoom,
  );

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  /// Shows a "cek lagi" dialog, then runs [action] and shows its message.
  /// On 409 staleVersion offers to reload the latest data.
  Future<void> _confirmThen({
    required String title,
    required String summary,
    required Future<EditOutcome> Function() action,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text('$summary\n\nPengikut sesi akan menerima notifikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            key: const Key('confirm-save'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final controller = context.read<EditSessionController>();
    final outcome = await action();
    if (!mounted) return;
    _room.text = controller.draftRoom;
    if (outcome.stale) {
      final reload = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          key: const Key('stale-dialog'),
          title: const Text('Sesi sudah diubah'),
          content: Text(
            '${outcome.message}\n\nMuat data terbaru sebelum '
            'mengubah lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Nanti'),
            ),
            FilledButton(
              key: const Key('stale-reload'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Muat ulang'),
            ),
          ],
        ),
      );
      if (reload != true || !mounted) return;
      final msg = await controller.reload();
      if (!mounted) return;
      _room.text = controller.draftRoom;
      showSnack(context, msg);
      return;
    }
    showSnack(context, outcome.message);
  }

  Future<void> _pickTime(
    DateTime initial,
    void Function(int, int) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<EditSessionController>();
    final s = c.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah sesi')),
      body: AbsorbPointer(
        absorbing: c.busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.courseName, style: theme.textTheme.titleLarge),
            Text('${formatDate(s.start)} · Prodi ${s.prodi}'),
            Text(
              'Sebagai: ${c.actor.role.label} · ${c.actor.name}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            StatusChip(session: s),
            if (c.busy) const LinearProgressIndicator(),
            const Divider(height: 32),
            Text('Ruang', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('room-field'),
              controller: _room,
              enabled: c.isEditable,
              onChanged: c.setRoom,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'mis. Ruang 402',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('save-room'),
              onPressed: c.isEditable
                  ? () => _confirmThen(
                      title: 'Pindah ruang?',
                      summary: c.roomChangeSummary,
                      action: c.saveRoom,
                    )
                  : null,
              child: const Text('Simpan ruang'),
            ),
            const Divider(height: 32),
            Text('Jam', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.isEditable
                        ? () => _pickTime(c.draftStart, c.setStart)
                        : null,
                    child: Text('Mulai ${formatTime(c.draftStart)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.isEditable
                        ? () => _pickTime(c.draftEnd, c.setEnd)
                        : null,
                    child: Text('Selesai ${formatTime(c.draftEnd)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: c.isEditable
                  ? () => _confirmThen(
                      title: 'Ubah jam?',
                      summary: c.timeChangeSummary,
                      action: c.saveTime,
                    )
                  : null,
              child: const Text('Simpan jam'),
            ),
            const Divider(height: 32),
            Text('Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const Key('record-attendance'),
              icon: const Icon(Icons.how_to_reg),
              onPressed: c.canRecordAttendance
                  ? () => _confirmThen(
                      title: 'Catat kehadiran?',
                      summary:
                          'Sesi akan berstatus "Tercatat" dengan jam sekarang.',
                      action: c.recordAttendance,
                    )
                  : null,
              label: const Text('Catat kehadiran kelas'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('cancel-session'),
              icon: const Icon(Icons.cancel_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: c.isEditable
                  ? () => _confirmThen(
                      title: 'Batalkan sesi?',
                      summary: c.cancelSummary,
                      destructive: true,
                      action: c.cancelSession,
                    )
                  : null,
              label: const Text('Batalkan sesi'),
            ),
          ],
        ),
      ),
    );
  }
}
