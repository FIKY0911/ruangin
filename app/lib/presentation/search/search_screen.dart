import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/clock.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/models/search_results.dart';
import '../../data/repositories/repositories.dart';
import '../lecturer/lecturer_profile_screen.dart';
import '../session/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/ruangin_chrome.dart';
import '../widgets/ruangin_widgets.dart';
import 'search_controller.dart';

Future<void> openSearch(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));

/// P01 + search by course/room — image/ui-ux/Hasil_cari1.png and
/// Tidak_ada_Hasil.png.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) =>
          SearchResultsController(c.read<SearchRepository>(), c.read<Clock>())
            ..load(),
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
    final controller = context.watch<SearchResultsController>();
    final hasQuery = controller.query.trim().isNotEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const WaveBackground(heightFactor: 0.22),
          SafeArea(
            bottom: false,
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
                          hint: 'Cari sesi, dosen, atau mata kuliah',
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
                    ViewData(:final data) => resultSummary(data),
                    _ => null,
                  },
                ),
                Expanded(
                  child: switch (controller.state) {
                    // Tidak_ada_Hasil.png
                    ViewEmpty() => SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: bottom + 24),
                      child: const Center(
                        key: Key('state-empty'),
                        child: IllustrationMessage(
                          image: BrandAssets.noResults,
                          title: 'Tidak ada hasil',
                          message:
                              'Tidak ada dosen, mata kuliah, atau sesi yang '
                              'cocok.',
                        ),
                      ),
                    ),
                    final state => AsyncStateView<SearchResults>(
                      state: state,
                      onRetry: controller.load,
                      emptyTitle: 'Tidak ada hasil',
                      showFreshness: false,
                      // Hasil_cari1.png: results, then the illustration.
                      builder: (context, results) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(bottom: bottom + 24),
                        children: [
                          if (results.sessions.isNotEmpty &&
                              results.lecturers.isNotEmpty)
                            const _GroupLabel('Dosen'),
                          for (final l in results.lecturers)
                            _LecturerCard(lecturer: l),
                          if (results.sessions.isNotEmpty) ...[
                            const _GroupLabel(
                              'Mata kuliah & sesi · 7 hari ke depan',
                              key: Key('search-sessions'),
                            ),
                            for (final s in results.sessions)
                              SessionRow(
                                session: s,
                                showDate: true,
                                onTap: () => openSessionDetail(context, s.id),
                              ),
                          ],
                          const SizedBox(height: 24),
                          const IllustrationMessage(
                            image: BrandAssets.lecturerSitting,
                            message:
                                'Dosen mengajar dengan tanggung jawab, '
                                'disiplin, dan integritas.',
                          ),
                        ],
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "3 dosen ditemukan" / "1 dosen · 2 sesi ditemukan".
String resultSummary(SearchResults r) => r.sessions.isEmpty
    ? '${r.lecturers.length} dosen ditemukan'
    : '${r.lecturers.length} dosen · ${r.sessions.length} sesi ditemukan';

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Text(
      text,
      style: AppFonts.sansStyle(16, 600, color: AppColors.muted),
    ),
  );
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
