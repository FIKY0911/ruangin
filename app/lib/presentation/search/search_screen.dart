import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/repositories/repositories.dart';
import '../lecturer/lecturer_profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_widgets.dart';
import 'search_controller.dart';

Future<void> openSearch(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));

/// P01 — image/ui-ux/Hasil_Pencarian.png and Hasil_Pencarian_Tidak_Ada.png.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => LecturerSearchController(
        c.read<LecturerRepository>(),
        c.read<Clock>(),
      )..load(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LecturerSearchController>();
    final hasQuery = controller.query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SearchPill(
                      key: const Key('search-field'),
                      controller: _text,
                      autofocus: true,
                      hint: 'Cari nama dosen, mis. "rina"',
                      onChanged: controller.onQueryChanged,
                      onClear: hasQuery
                          ? () {
                              _text.clear();
                              controller.onQueryChanged('');
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle(
              hasQuery ? 'Hasil cari' : 'Semua dosen',
              subtitle: switch (controller.state) {
                ViewData(:final data) => '${data.length} dosen ditemukan',
                _ => null,
              },
            ),
            Expanded(
              child: AsyncStateView<List<Lecturer>>(
                state: controller.state,
                onRetry: controller.load,
                emptyTitle: 'Tidak ada hasil',
                emptyMessage:
                    'Tidak ada dosen yang cocok. Coba sebagian nama saja.',
                emptyImage: BrandAssets.discuss,
                showFreshness: false,
                builder: (context, lecturers) => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: lecturers.length,
                  itemBuilder: (context, i) =>
                      _LecturerCard(lecturer: lecturers[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LecturerCard extends StatelessWidget {
  const _LecturerCard({required this.lecturer});

  final Lecturer lecturer;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      key: Key('lecturer-${lecturer.id}'),
      onTap: () => openLecturer(context, lecturer.id),
      child: Row(
        children: [
          InitialsAvatar(name: lecturer.name, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecturer.name,
                  style: AppFonts.sansStyle(17, 700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  lecturer.prodi,
                  style: AppFonts.sansStyle(15, 400, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
