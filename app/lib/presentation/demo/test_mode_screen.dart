import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/result.dart';
import '../../data/repositories/repositories.dart';
import '../theme/app_theme.dart';
import '../widgets/ruangin_widgets.dart';

/// Mode uji (PRD §3): time a task done "cara biasa" vs with Ruangin. Backed
/// by `/test-runs`; results are shown as measured, never as claims.
class TestModeScreen extends StatefulWidget {
  const TestModeScreen({super.key});

  @override
  State<TestModeScreen> createState() => _TestModeScreenState();
}

class _TestModeScreenState extends State<TestModeScreen> {
  final _participant = TextEditingController();
  final _task = TextEditingController(text: 'Temukan ruang & jam selesai sesi');
  final _target = TextEditingController();
  final _answerRoom = TextEditingController();
  final _answerEnd = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'ruangin';
  TestRun? _running;
  TestRun? _finished;
  DateTime? _startedAt;
  Timer? _ticker;
  bool _busy = false;
  String? _error;
  TestRunList? _history;

  TestRunRepository get _repo => context.read<TestRunRepository>();

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [
      _participant,
      _task,
      _target,
      _answerRoom,
      _answerEnd,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _finished = null;
    });
    final r = await _repo.start(
      participantCode: _participant.text,
      task: _task.text,
      method: _method,
      targetSessionId: _target.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Success(:final value):
          _running = value;
          _startedAt = DateTime.now();
          _ticker = Timer.periodic(
            const Duration(seconds: 1),
            (_) => setState(() {}),
          );
        case Failure(:final failure):
          _error = failure.message;
      }
    });
  }

  Future<void> _finish() async {
    final run = _running;
    if (run == null) return;
    setState(() => _busy = true);
    final r = await _repo.finish(
      run.id,
      answerRoom: _answerRoom.text,
      answerEndTime: _answerEnd.text,
      notes: _notes.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Success(:final value):
          _ticker?.cancel();
          _running = null;
          _finished = value;
          _answerRoom.clear();
          _answerEnd.clear();
          _notes.clear();
        case Failure(:final failure):
          _error = failure.message;
      }
    });
  }

  Future<void> _loadHistory() async {
    final r = await _repo.list();
    if (!mounted) return;
    switch (r) {
      case Success(:final value):
        setState(() => _history = value);
      case Failure(:final failure):
        showSnack(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _running != null;
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    return Scaffold(
      appBar: AppBar(title: const Text('Mode uji')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Catat waktu peserta menyelesaikan tugas dengan cara biasa atau '
            'dengan Ruangin. Jika ID sesi target diisi, jawaban dicek otomatis '
            'dengan data terbaru sesi itu.',
            style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (!running) ...[
            TextField(
              key: const Key('test-participant'),
              controller: _participant,
              decoration: const InputDecoration(labelText: 'Kode peserta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _task,
              decoration: const InputDecoration(labelText: 'Tugas'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _target,
              decoration: const InputDecoration(
                labelText: 'ID sesi target (opsional)',
                hintText: 'mis. s-pm-today',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'biasa', label: Text('Cara biasa')),
                ButtonSegment(value: 'ruangin', label: Text('Ruangin')),
              ],
              selected: {_method},
              onSelectionChanged: (v) => setState(() => _method = v.first),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('test-start'),
              onPressed: _busy ? null : _start,
              child: const Text('Mulai stopwatch'),
            ),
          ] else ...[
            Center(
              child: Text(
                '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
                '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                key: const Key('test-elapsed'),
                style: AppFonts.sansStyle(56, 700, color: AppColors.accent),
              ),
            ),
            Center(
              child: Text(
                '${_running!.participantCode} · ${_running!.method}',
                style: AppFonts.sansStyle(14, 400, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerRoom,
              decoration: const InputDecoration(labelText: 'Jawaban: ruang'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _answerEnd,
              decoration: const InputDecoration(
                labelText: 'Jawaban: jam selesai',
                hintText: '10.00',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('test-finish'),
              onPressed: _busy ? null : _finish,
              child: const Text('Selesai'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_finished case final f?) ...[
            const SizedBox(height: 16),
            SoftCard(
              key: const Key('test-result'),
              child: Text(
                'Selesai dalam ${f.durationSeconds ?? '-'} detik'
                '${f.isCorrect == null
                    ? ''
                    : f.isCorrect!
                    ? ' · jawaban benar'
                    : ' · jawaban salah'}'
                '${f.json['expectedRoom'] != null ? '\nSeharusnya: ${f.json['expectedRoom']} · selesai ${f.json['expectedEndTime']}' : ''}',
              ),
            ),
          ],
          const Divider(height: 40),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Lihat ringkasan hasil'),
            onPressed: _loadHistory,
          ),
          if (_history case final h?) ...[
            const SizedBox(height: 12),
            for (final m in ['biasa', 'ruangin'])
              if (h.summary[m] case final Map<String, dynamic> s)
                ListTile(
                  title: Text(m == 'biasa' ? 'Cara biasa' : 'Ruangin'),
                  subtitle: Text(
                    '${s['finished']} selesai · median '
                    '${(s['durationSeconds'] as Map?)?['median'] ?? '-'} dtk · '
                    'rata-rata ${(s['durationSeconds'] as Map?)?['mean'] ?? '-'} dtk · '
                    'benar ${s['correctRate'] == null ? '-' : '${((s['correctRate'] as num) * 100).round()}%'}',
                  ),
                ),
            Text(
              '${h.runs.length} percobaan tercatat.',
              style: AppFonts.sansStyle(13, 400, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
