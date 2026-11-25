import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../data/models/session.dart';
import '../theme/app_theme.dart';
import 'session_detail_controller.dart';

/// P12 "Salin usulan pesan": the server writes a polite message that proposes
/// meeting right after the class, in its room. Ruangin only copies it — it
/// never sends messages or shows the lecturer's contact.
Future<void> showMessageDraftSheet(
  BuildContext context,
  SessionDetailController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _MessageDraftSheet(load: controller.messageDraft),
    ),
  );
}

class _MessageDraftSheet extends StatefulWidget {
  const _MessageDraftSheet({required this.load});

  final Future<Result<MessageDraft>> Function(String purpose) load;

  @override
  State<_MessageDraftSheet> createState() => _MessageDraftSheetState();
}

class _MessageDraftSheetState extends State<_MessageDraftSheet> {
  final _purpose = TextEditingController();
  MessageDraft? _draft;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.load(_purpose.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (r) {
        case Success(:final value):
          _draft = value;
        case Failure(:final failure):
          _error = failure.message;
      }
    });
  }

  Future<void> _copy() async {
    final d = _draft;
    if (d == null) return;
    await Clipboard.setData(ClipboardData(text: d.text));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          key: Key('draft-copied'),
          content: Text(
            'Pesan disalin. Tempel di aplikasi chat Anda — '
            'Ruangin tidak mengirim pesan.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Usulan pesan ke dosen', style: AppFonts.serifStyle(24, 700)),
          const SizedBox(height: 6),
          Text(
            'Draf pesan sopan yang mengusulkan bertemu setelah kelas selesai, '
            'di ruang kelas itu.',
            style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('draft-purpose'),
            controller: _purpose,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _generate(),
            decoration: const InputDecoration(
              labelText: 'Keperluan (opsional)',
              hintText: 'mis. meminta arahan lomba',
            ),
          ),
          FilledButton(
            key: const Key('draft-generate'),
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(d == null ? 'Buat draf' : 'Buat ulang'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('draft-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (d != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('draft-text'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                d.text,
                style: AppFonts.sansStyle(15, 400, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Usulan: ${formatDate(d.proposedTime)} pukul '
              '${formatTime(d.proposedTime)} di ${d.proposedPlace}.\n${d.note}',
              style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('draft-copy'),
              icon: const Icon(Icons.copy),
              label: const Text('Salin pesan'),
              onPressed: _copy,
            ),
          ],
        ],
      ),
    );
  }
}
