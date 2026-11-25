import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/account.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';
import '../session/session_detail_screen.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';

/// Sessions the signed-in lecturer/officer may edit on the selected date
/// (`GET /sessions?date=…&editable=1`).
class ManageController extends AsyncController<List<Session>> {
  ManageController(this._repo, super.clock) : _date = dateOnly(clock.now());

  final SessionRepository _repo;
  DateTime _date;

  DateTime get date => _date;

  @override
  Future<Result<List<Session>>> fetch() =>
      _repo.onDate(_date, editableOnly: true);

  void shift(int days) {
    _date = DateTime(_date.year, _date.month, _date.day + days);
    resetCache();
    load();
  }
}

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.read<AuthController>().account!;
    return ChangeNotifierProvider(
      create: (c) =>
          ManageController(c.read<SessionRepository>(), c.read<Clock>())
            ..load(),
      child: Consumer<ManageController>(
        builder: (context, controller, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                account.role == UserRole.dosen
                    ? 'Sesi yang Anda ampu'
                    : 'Sesi dalam cakupan: ${account.scopeProdi.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('manage-prev'),
                  tooltip: 'Hari sebelumnya',
                  onPressed: () => controller.shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    formatDate(controller.date),
                    key: const Key('manage-date'),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  key: const Key('manage-next'),
                  tooltip: 'Hari berikutnya',
                  onPressed: () => controller.shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Expanded(
              child: AsyncStateView<List<Session>>(
                state: controller.state,
                onRetry: controller.load,
                emptyTitle: 'Tidak ada sesi yang bisa Anda ubah di tanggal ini',
                builder: (context, sessions) => ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, i) => SessionRow(
                    session: sessions[i],
                    onTap: () async {
                      await openSessionDetail(context, sessions[i].id);
                      controller.load();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
