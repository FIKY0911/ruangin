import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../widgets/async_state_view.dart';
import '../widgets/session_widgets.dart';
import 'follow_controller.dart';
import 'session_detail_screen.dart';

class FollowedSessionsController extends AsyncController<List<Session>> {
  FollowedSessionsController(this._repo, this._follows, super.clock) {
    _follows.addListener(load);
  }

  final SessionRepository _repo;
  final FollowController _follows;

  @override
  Future<Result<List<Session>>> fetch() => _repo.byIds(_follows.followed);

  @override
  void dispose() {
    _follows.removeListener(load);
    super.dispose();
  }
}

/// List of sessions the user follows (P04).
class FollowedScreen extends StatelessWidget {
  const FollowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => FollowedSessionsController(
          c.read<SessionRepository>(), c.read<FollowController>(), c.read<Clock>())
        ..load(),
      child: Consumer<FollowedSessionsController>(
        builder: (context, controller, _) => AsyncStateView<List<Session>>(
          state: controller.state,
          onRetry: controller.load,
          emptyTitle: 'Belum mengikuti sesi apa pun',
          emptyMessage: 'Buka detail sesi lalu ketuk "Ikuti sesi".',
          builder: (context, sessions) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final s in sessions)
                SessionTile(
                  session: s,
                  showDate: true,
                  isFollowed: true,
                  onTap: () async {
                    await openSessionDetail(context, s.id);
                    controller.load();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
