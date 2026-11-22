import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../data/models/lecturer.dart';
import '../../data/repositories/repositories.dart';
import '../lecturer/lecturer_profile_screen.dart';
import '../widgets/async_state_view.dart';
import 'search_controller.dart';

/// P01: search lecturers by partial, case-insensitive name; shows home prodi.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => LecturerSearchController(
          c.read<LecturerRepository>(), c.read<Clock>())
        ..load(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LecturerSearchController>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('search-field'),
            onChanged: controller.onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari nama dosen, mis. "rina"',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: AsyncStateView<List<Lecturer>>(
            state: controller.state,
            onRetry: controller.load,
            emptyTitle: 'Dosen tidak ditemukan',
            emptyMessage: 'Coba nama lain atau sebagian nama saja.',
            emptyImage: BrandAssets.discuss,
            builder: (context, lecturers) => ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lecturers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _LecturerTile(lecturer: lecturers[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _LecturerTile extends StatelessWidget {
  const _LecturerTile({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    final initials = lecturer.name
        .replaceAll(RegExp(r'^(Dr\.|Prof\.)\s*'), '')
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0])
        .join();
    return ListTile(
      key: Key('lecturer-${lecturer.id}'),
      leading: CircleAvatar(child: Text(initials)),
      title: Text(lecturer.name),
      subtitle: Text('Prodi asal: ${lecturer.prodi}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LecturerProfileScreen(lecturerId: lecturer.id),
      )),
    );
  }
}
