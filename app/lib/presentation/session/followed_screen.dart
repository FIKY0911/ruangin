import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/session.dart';
import '../../data/repositories/repositories.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'follow_controller.dart';
import 'session_detail_screen.dart';

class FollowedSessionsController extends AsyncController<List<Session>> {
  FollowedSessionsController(this._repo, this._follows, super.clock) {
    _follows.addListener(_onFollowsChanged);
  }

  final FollowRepository _repo;
  final FollowController _follows;
  Set<String> _lastIds = const {};

  void _onFollowsChanged() {
    if (setEquals(_lastIds, _follows.followed)) return;
    load();
  }

  @override
  Future<Result<List<Session>>> fetch() async {
    final r = await _repo.followed();
    if (r case Success(:final value)) _lastIds = {for (final s in value) s.id};
    return r;
  }

  @override
  void dispose() {
    _follows.removeListener(_onFollowsChanged);
    super.dispose();
  }
}

/// List of sessions the user follows (P04, `/me/follows`).
class FollowedScreen extends StatelessWidget {
  const FollowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => FollowedSessionsController(
        c.read<FollowRepository>(),
        c.read<FollowController>(),
        c.read<Clock>(),
      )..load(),
      child: Consumer<FollowedSessionsController>(
        builder: (context, controller, _) => AsyncStateView<List<Session>>(
          state: controller.state,
          onRetry: controller.load,
          emptyTitle: 'Belum mengikuti sesi apa pun',
          emptyMessage: 'Buka detail sesi lalu ketuk "Ikuti sesi".',
          builder: (context, sessions) => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, i) => SessionRow(
              session: sessions[i],
              showDate: true,
              isFollowed: true,
              onTap: () async {
                await openSessionDetail(context, sessions[i].id);
                controller.load();
              },
            ),
          ),
        ),
      ),
    );
  }
}
