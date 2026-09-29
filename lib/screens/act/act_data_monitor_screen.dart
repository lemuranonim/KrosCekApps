import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/act_sync_status.dart';
import '../../providers/act_sync_status_provider.dart';
import '../../theme/app_theme.dart';

enum ActReviewStatusFilter { all, needsConfirmation, reviewed }

enum ActDataMonitorMode { syncStatus, plantingData }

List<ActHarvestReview> filterActHarvestReviews(
  List<ActHarvestReview> source, {
  String query = '',
  String? region,
  String? district,
  String? owner,
  String? season,
  String? seedType,
  ActReviewStatusFilter status = ActReviewStatusFilter.all,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return source
      .where((item) {
        if (normalizedQuery.isNotEmpty &&
            !item.searchableText.contains(normalizedQuery)) {
          return false;
        }
        if (region != null && item.region != region) return false;
        if (district != null && item.district != district) return false;
        if (owner != null && item.qaOwner != owner) return false;
        if (season != null && item.season != season) return false;
        if (seedType != null && item.seedType != seedType) return false;
        return switch (status) {
          ActReviewStatusFilter.all => true,
          ActReviewStatusFilter.needsConfirmation =>
            item.status == 'NEEDS_CONFIRMATION',
          ActReviewStatusFilter.reviewed => item.status != 'NEEDS_CONFIRMATION',
        };
      })
      .toList(growable: false);
}

class ActDataMonitorScreen extends ConsumerStatefulWidget {
  const ActDataMonitorScreen({
    super.key,
    this.mode = ActDataMonitorMode.syncStatus,
  });

  final ActDataMonitorMode mode;

  @override
  ConsumerState<ActDataMonitorScreen> createState() =>
      _ActDataMonitorScreenState();
}

class _ActDataMonitorScreenState extends ConsumerState<ActDataMonitorScreen> {
  final _searchController = TextEditingController();
  final _syncSearchController = TextEditingController();
  String? _region;
  String? _district;
  String? _owner;
  String? _season;
  String? _seedType;
  ActReviewStatusFilter _statusFilter = ActReviewStatusFilter.all;
  String _syncCategory = 'CHANGED';
  String? _syncQuery;
  int _syncOffset = 0;

  static const _syncPageSize = 20;

  PlantingDataMonitorFilter get _plantingFilter => PlantingDataMonitorFilter(
    region: _region,
    district: _district,
    owner: _owner,
    season: _season,
    seedType: _seedType,
  );

  ActSyncDailyQuery get _syncDailyQuery => ActSyncDailyQuery(
    category: _syncCategory,
    query: _syncQuery,
    offset: _syncOffset,
    limit: _syncPageSize,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _syncSearchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(actSyncStatusProvider);
    if (widget.mode == ActDataMonitorMode.syncStatus) {
      ref.invalidate(actSyncHistoryProvider);
      ref.invalidate(actSyncDailySummaryProvider);
      ref.invalidate(actSyncDailyChangesProvider);
      await Future.wait([
        ref.read(actSyncStatusProvider.future),
        ref.read(actSyncHistoryProvider.future),
        ref.read(actSyncDailySummaryProvider.future),
        ref.read(actSyncDailyChangesProvider(_syncDailyQuery).future),
      ]);
      return;
    }

    ref.invalidate(actSyncHarvestReviewsProvider);
    ref.invalidate(plantingDataMonitorOptionsProvider);
    ref.invalidate(plantingDataMonitorSummaryProvider);
    await Future.wait([
      ref.read(actSyncStatusProvider.future),
      ref.read(actSyncHarvestReviewsProvider.future),
      ref.read(plantingDataMonitorOptionsProvider.future),
      ref.read(plantingDataMonitorSummaryProvider(_plantingFilter).future),
    ]);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _region = null;
      _district = null;
      _owner = null;
      _season = null;
      _seedType = null;
      _statusFilter = ActReviewStatusFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSync = widget.mode == ActDataMonitorMode.syncStatus;
    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isSync ? 'ACT Sync Status' : 'Data Tanam Monitor'),
            Text(
              isSync
                  ? 'Status dan riwayat sinkronisasi'
                  : 'Planting, PLD, effective & harvest',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isSync ? 'Perbarui status' : 'Perbarui data monitor',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isSync ? _buildSyncMonitor() : _buildPlantingMonitor(),
    );
  }

  Widget _buildSyncMonitor() {
    final statusAsync = ref.watch(actSyncStatusProvider);
    final historyAsync = ref.watch(actSyncHistoryProvider);
    final dailySummaryAsync = ref.watch(actSyncDailySummaryProvider);
    final dailyChangesAsync = ref.watch(
      actSyncDailyChangesProvider(_syncDailyQuery),
    );

    return statusAsync.when(
      loading: () => const _MonitorLoading(),
      error: (error, _) => _MonitorError(
        message: 'Status sinkronisasi belum dapat dimuat.',
        onRetry: _refresh,
      ),
      data: (status) => RefreshIndicator(
        color: AdvantaColors.primaryGreen,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SyncHero(status: status),
            const SizedBox(height: 12),
            _SyncMetrics(status: status),
            const SizedBox(height: 12),
            _AutomationNote(status: status),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Hasil sync harian area saya',
              subtitle: 'FN dibatasi otomatis sesuai role akun',
              icon: Icons.manage_search_rounded,
            ),
            const SizedBox(height: 10),
            dailySummaryAsync.when(
              loading: () => const _LoadingPanel(
                message: 'Menghitung hasil sync area Anda…',
              ),
              error: (error, _) => _InlineError(
                message: 'Ringkasan hasil sync harian belum dapat dimuat.',
                onRetry: () => ref.invalidate(actSyncDailySummaryProvider),
              ),
              data: (summary) => _DailySyncSummaryCard(summary: summary),
            ),
            const SizedBox(height: 12),
            _buildDailySyncFilters(),
            const SizedBox(height: 10),
            dailyChangesAsync.when(
              loading: () => const _LoadingPanel(
                message: 'Memuat FN yang berubah dan perlu perhatian…',
              ),
              error: (error, _) => _InlineError(
                message: 'Detail hasil sync harian belum dapat dimuat.',
                onRetry: () => ref.invalidate(
                  actSyncDailyChangesProvider(_syncDailyQuery),
                ),
              ),
              data: _buildDailySyncPage,
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Riwayat sinkronisasi',
              subtitle: 'Run server-side terbaru',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 10),
            historyAsync.when(
              loading: () => const _HistoryLoading(),
              error: (error, _) => _InlineError(
                message: 'Riwayat sinkronisasi belum dapat dimuat.',
                onRetry: () => ref.invalidate(actSyncHistoryProvider),
              ),
              data: (items) => _SyncHistoryList(items: items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySyncFilters() {
    const categories = [
      ('CHANGED', 'Berubah/masalah'),
      ('INSERT', 'FN baru'),
      ('UPDATE', 'Diperbarui'),
      ('ISSUE', 'Perlu perhatian'),
      ('UNCHANGED', 'Tidak berubah'),
      ('ALL', 'Semua'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        children: [
          TextField(
            controller: _syncSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applyDailySyncSearch(),
            decoration: InputDecoration(
              hintText: 'Cari FN, petani, hybrid, atau lokasi',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: _syncSearchController.text.trim().isEmpty
                    ? 'Cari'
                    : 'Terapkan pencarian',
                onPressed: _applyDailySyncSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  _SyncCategoryChoice(
                    label: categories[index].$2,
                    selected: _syncCategory == categories[index].$1,
                    onTap: () => setState(() {
                      _syncCategory = categories[index].$1;
                      _syncOffset = 0;
                    }),
                  ),
                  if (index != categories.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_syncQuery != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pencarian: “$_syncQuery”',
                    style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.mutedGrey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _syncSearchController.clear();
                    setState(() {
                      _syncQuery = null;
                      _syncOffset = 0;
                    });
                  },
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _applyDailySyncSearch() {
    final value = _syncSearchController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _syncQuery = value.isEmpty ? null : value;
      _syncOffset = 0;
    });
  }

  Widget _buildDailySyncPage(ActSyncDailyPage page) {
    if (page.items.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.checklist_rtl_rounded,
        title: 'Tidak ada FN pada filter ini',
        message: 'Ganti kategori atau pencarian untuk melihat hasil lainnya.',
      );
    }
    final first = page.offset + 1;
    final last = page.offset + page.items.length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$first–$last dari ${_integer(page.totalCount)} FN',
                style: AdvantaText.label.copyWith(
                  color: AdvantaColors.deepForest,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Halaman sebelumnya',
              onPressed: page.hasPrevious
                  ? () => setState(() {
                      final previous = _syncOffset - _syncPageSize;
                      _syncOffset = previous < 0 ? 0 : previous;
                    })
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Halaman berikutnya',
              onPressed: page.hasNext
                  ? () => setState(() => _syncOffset += _syncPageSize)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...page.items.map((item) => _SyncDailyChangeCard(item: item)),
      ],
    );
  }

  Widget _buildPlantingMonitor() {
    final statusAsync = ref.watch(actSyncStatusProvider);
    final reviewsAsync = ref.watch(actSyncHarvestReviewsProvider);
    final optionsAsync = ref.watch(plantingDataMonitorOptionsProvider);
    final summaryAsync = ref.watch(
      plantingDataMonitorSummaryProvider(_plantingFilter),
    );

    return RefreshIndicator(
      color: AdvantaColors.primaryGreen,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PlantingMonitorHero(status: statusAsync),
          const SizedBox(height: 12),
          optionsAsync.when(
            loading: () =>
                const _LoadingPanel(message: 'Memuat kelompok filter…'),
            error: (error, _) => _InlineError(
              message: 'Filter Data Tanam belum dapat dimuat.',
              onRetry: () => ref.invalidate(plantingDataMonitorOptionsProvider),
            ),
            data: _buildPlantingFilters,
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            loading: () =>
                const _LoadingPanel(message: 'Menghitung ringkasan luasan…'),
            error: (error, _) => _InlineError(
              message: 'Ringkasan luasan belum dapat dimuat.',
              onRetry: () => ref.invalidate(
                plantingDataMonitorSummaryProvider(_plantingFilter),
              ),
            ),
            data: (summary) => _PlantingAreaSummary(summary: summary),
          ),
          const SizedBox(height: 20),
          summaryAsync.maybeWhen(
            data: (summary) => _SectionTitle(
              title: 'Data panen perlu konfirmasi',
              subtitle: summary.harvestNeedsReview > 0
                  ? '${_integer(summary.harvestNeedsReview)} FN perlu direview bersama FA'
                  : 'Tidak ada anomali area panen',
              icon: Icons.fact_check_outlined,
            ),
            orElse: () => const _SectionTitle(
              title: 'Data panen perlu konfirmasi',
              subtitle: 'Memuat status review panen',
              icon: Icons.fact_check_outlined,
            ),
          ),
          const SizedBox(height: 10),
          reviewsAsync.when(
            loading: () => const _ReviewLoading(),
            error: (error, _) => _InlineError(
              message: 'Daftar review panen belum dapat dimuat.',
              onRetry: () => ref.invalidate(actSyncHarvestReviewsProvider),
            ),
            data: _buildReviews,
          ),
        ],
      ),
    );
  }

  Widget _buildPlantingFilters(PlantingDataMonitorOptions options) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: AdvantaColors.primaryGreen,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Kelompok filter',
                  style: AdvantaText.bodyBold.copyWith(
                    color: AdvantaColors.deepForest,
                  ),
                ),
              ),
              if (!_plantingFilter.isEmpty)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterMenu(
                  label: _region ?? 'Semua region',
                  icon: Icons.map_outlined,
                  selected: _region,
                  options: options.regions,
                  onSelected: (value) => setState(() {
                    _region = value;
                    _district = null;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _district ?? 'Semua kabupaten',
                  icon: Icons.location_city_outlined,
                  selected: _district,
                  options: options.districts,
                  onSelected: (value) => setState(() => _district = value),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _owner ?? 'Semua QA/FI',
                  icon: Icons.person_search_outlined,
                  selected: _owner,
                  options: options.owners,
                  onSelected: (value) => setState(() => _owner = value),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _season ?? 'Semua season',
                  icon: Icons.calendar_month_outlined,
                  selected: _season,
                  options: options.seasons,
                  onSelected: (value) => setState(() => _season = value),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _seedType ?? 'Semua tipe',
                  icon: Icons.eco_outlined,
                  selected: _seedType,
                  options: options.seedTypes,
                  onSelected: (value) => setState(() => _seedType = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews(List<ActHarvestReview> reviews) {
    final filtered = filterActHarvestReviews(
      reviews,
      query: _searchController.text,
      region: _region,
      district: _district,
      owner: _owner,
      season: _season,
      seedType: _seedType,
      status: _statusFilter,
    );
    final hasFilters =
        _searchController.text.trim().isNotEmpty ||
        _region != null ||
        _district != null ||
        _owner != null ||
        _season != null ||
        _seedType != null ||
        _statusFilter != ActReviewStatusFilter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewSummary(reviews: filtered),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari FN, petani, hybrid, desa, atau QA/FI',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChoice(
                label: 'Semua',
                selected: _statusFilter == ActReviewStatusFilter.all,
                onTap: () =>
                    setState(() => _statusFilter = ActReviewStatusFilter.all),
              ),
              _StatusChoice(
                label: 'Perlu konfirmasi',
                selected:
                    _statusFilter == ActReviewStatusFilter.needsConfirmation,
                onTap: () => setState(
                  () => _statusFilter = ActReviewStatusFilter.needsConfirmation,
                ),
              ),
              _StatusChoice(
                label: 'Sudah direview',
                selected: _statusFilter == ActReviewStatusFilter.reviewed,
                onTap: () => setState(
                  () => _statusFilter = ActReviewStatusFilter.reviewed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_integer(filtered.length)} dari ${_integer(reviews.length)} FN ditampilkan',
                  style: AdvantaText.label.copyWith(
                    color: AdvantaColors.deepForest,
                  ),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Reset'),
                ),
            ],
          ),
          if (filtered.isEmpty)
            const _EmptyReviews(filtered: true)
          else
            ...filtered.map((review) => _HarvestReviewCard(review: review)),
        ] else
          const _EmptyReviews(),
      ],
    );
  }
}

class _DailySyncSummaryCard extends StatelessWidget {
  const _DailySyncSummaryCard({required this.summary});

  final ActSyncDailySummary summary;

  @override
  Widget build(BuildContext context) {
    final sourceDate = summary.sourceTo == null
        ? '-'
        : DateFormat('d MMM yyyy', 'id_ID').format(summary.sourceTo!);
    final scopeLabel = switch (summary.scopeRole) {
      'SPV' => 'Area QA SPV saya',
      'FI' => 'Area QA FI saya',
      'ADMIN' || 'DEV' || 'MANAGER' || 'SERVICE_ROLE' => 'Semua area',
      _ => 'Tidak ada area yang ditugaskan',
    };
    final metrics = [
      ('FN area saya', summary.totalRows, AdvantaColors.primaryGreen),
      ('FN baru', summary.insertedRows, const Color(0xFF168B5B)),
      ('Diperbarui', summary.updatedRows, const Color(0xFF2476B8)),
      ('Tetap', summary.unchangedRows, AdvantaColors.mutedGrey),
      ('Missing ACT', summary.missingSourceRows, const Color(0xFFE58A00)),
      (
        'Invalid/konflik',
        summary.invalidRows + summary.conflictRows,
        AdvantaColors.error,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AdvantaColors.paleGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_pin_circle_outlined,
                  color: AdvantaColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scopeLabel,
                      style: AdvantaText.bodyBold.copyWith(
                        color: AdvantaColors.deepForest,
                      ),
                    ),
                    Text(
                      'Hasil run selesai • data ACT sampai $sourceDate',
                      style: AdvantaText.caption.copyWith(
                        color: AdvantaColors.mutedGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _DailySyncMetric(
                label: metric.$1,
                value: metric.$2,
                color: metric.$3,
              );
            },
          ),
          if (summary.issueRows > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${_integer(summary.issueRows)} FN perlu diperiksa. Missing ACT hanya informasi dan tidak otomatis menghapus data KC.',
              style: AdvantaText.caption.copyWith(
                color: const Color(0xFF9A5A00),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailySyncMetric extends StatelessWidget {
  const _DailySyncMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _integer(value),
            maxLines: 1,
            style: AdvantaText.heading3.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(color: AdvantaColors.charcoal),
          ),
        ],
      ),
    );
  }
}

class _SyncCategoryChoice extends StatelessWidget {
  const _SyncCategoryChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AdvantaRadius.chipRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AdvantaColors.primaryGreen : Colors.white,
          borderRadius: AdvantaRadius.chipRadius,
          border: Border.all(
            color: selected
                ? AdvantaColors.primaryGreen
                : AdvantaColors.dividerGrey,
          ),
        ),
        child: Text(
          label,
          style: AdvantaText.label.copyWith(
            color: selected ? Colors.white : AdvantaColors.deepForest,
          ),
        ),
      ),
    );
  }
}

class _SyncDailyChangeCard extends StatelessWidget {
  const _SyncDailyChangeCard({required this.item});

  final ActSyncDailyChange item;

  @override
  Widget build(BuildContext context) {
    final presentation = _changePresentation(item.changeKind);
    final subtitle = [
      item.farmerName,
      item.hybrid,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
    final errors = [
      ...item.validationErrors,
      if (item.applyError != null) item.applyError!,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: presentation.$2.withAlpha(75)),
        boxShadow: AdvantaShadows.card(false),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: presentation.$2.withAlpha(18),
            shape: BoxShape.circle,
          ),
          child: Icon(presentation.$3, color: presentation.$2, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.fieldNumber,
                style: AdvantaText.bodyBold.copyWith(
                  color: AdvantaColors.deepForest,
                ),
              ),
            ),
            _SyncKindBadge(label: presentation.$1, color: presentation.$2),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdvantaText.caption.copyWith(
                  color: AdvantaColors.charcoal,
                ),
              ),
            Text(
              '${item.sourceType ?? 'KC'} • ${item.changedFieldCount} kolom berubah'
              '${item.applied ? ' • diterapkan' : ''}',
              style: AdvantaText.caption.copyWith(
                color: AdvantaColors.mutedGrey,
              ),
            ),
          ],
        ),
        children: [
          if (item.locationLabel.isNotEmpty)
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: item.locationLabel,
            ),
          if (item.qaFi != null || item.qaSpv != null) ...[
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.person_outline_rounded,
              text: [
                if (item.qaFi != null) 'FI ${item.qaFi}',
                if (item.qaSpv != null) 'SPV ${item.qaSpv}',
              ].join(' • '),
            ),
          ],
          if (item.changeKind == 'MISSING_SOURCE') ...[
            const SizedBox(height: 10),
            const _SyncNotice(
              text:
                  'FN tidak ditemukan pada file ACT run ini. Data KC tetap dipertahankan dan tidak dinonaktifkan otomatis.',
              color: Color(0xFFE58A00),
            ),
          ],
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SyncNotice(text: errors.join(' • '), color: AdvantaColors.error),
          ],
          if (item.changedFields.isNotEmpty) ...[
            const SizedBox(height: 11),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Perubahan nilai',
                style: AdvantaText.label.copyWith(
                  color: AdvantaColors.deepForest,
                ),
              ),
            ),
            const SizedBox(height: 7),
            for (final change in item.changedFields.take(8))
              _SyncValueChange(change: change),
            if (item.changedFields.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${item.changedFields.length - 8} kolom lainnya',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static (String, Color, IconData) _changePresentation(String kind) {
    return switch (kind) {
      'INSERT' => (
        'FN Baru',
        const Color(0xFF168B5B),
        Icons.add_circle_outline,
      ),
      'UPDATE' => ('Diperbarui', const Color(0xFF2476B8), Icons.update_rounded),
      'UNCHANGED' => (
        'Tetap',
        AdvantaColors.mutedGrey,
        Icons.check_circle_outline,
      ),
      'MISSING_SOURCE' => (
        'Missing ACT',
        const Color(0xFFE58A00),
        Icons.find_in_page_outlined,
      ),
      'INVALID' => (
        'Invalid',
        AdvantaColors.error,
        Icons.error_outline_rounded,
      ),
      'CONFLICT_SOURCE_DUPLICATE' || 'CONFLICT_KC_DUPLICATE' => (
        'Konflik',
        AdvantaColors.error,
        Icons.copy_all_outlined,
      ),
      _ => ('Perlu dicek', AdvantaColors.mutedGrey, Icons.help_outline_rounded),
    };
  }
}

class _SyncKindBadge extends StatelessWidget {
  const _SyncKindBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AdvantaText.caption.copyWith(color: color)),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AdvantaText.caption.copyWith(color: color)),
    );
  }
}

class _SyncValueChange extends StatelessWidget {
  const _SyncValueChange({required this.change});

  final ActSyncFieldChange change;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _syncFieldLabel(change.fieldName),
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  change.oldText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdvantaText.body2.copyWith(
                    color: AdvantaColors.charcoal,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AdvantaColors.mutedGrey,
                ),
              ),
              Expanded(
                child: Text(
                  change.newText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdvantaText.bodyBold.copyWith(
                    color: AdvantaColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _syncFieldLabel(String value) {
  const labels = {
    'field_number': 'Field Number',
    'farmer_name': 'Nama petani',
    'grower': 'Grower',
    'hybrid': 'Hybrid',
    'total_area_planted_ha': 'Actual planted area',
    'discard_area_ha': 'Discard/PLD area',
    'effective_area_ha': 'Effective area',
    'harvested_area_ha': 'Harvested area',
    'planting_date_pdn': 'Tanggal tanam',
    'village_desa': 'Desa',
    'sub_district_kec': 'Kecamatan',
    'district_kab': 'Kabupaten',
    'region': 'Region',
    'fa': 'Field Assistant',
    'field_spv': 'Field SPV',
    'coordinate': 'Koordinat',
    'geometry_wkt': 'Geometry WKT',
    'correction_geometry_wkt': 'Correction Geometry WKT',
    'type': 'Tipe',
  };
  return labels[value] ?? value.replaceAll('_', ' ');
}

class _PlantingMonitorHero extends StatelessWidget {
  const _PlantingMonitorHero({required this.status});

  final AsyncValue<ActSyncStatus> status;

  @override
  Widget build(BuildContext context) {
    final syncLabel = status.when(
      loading: () => 'Memeriksa sumber data ACT…',
      error: (_, __) => 'Status sync belum tersedia',
      data: (value) {
        final sourceDate = value.lastSuccessSourceDate;
        if (sourceDate == null) return 'Belum ada sync ACT yang berhasil';
        return 'Data ACT sampai ${DateFormat('d MMM yyyy', 'id_ID').format(sourceDate)}';
      },
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdvantaColors.deepForest, AdvantaColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AdvantaShadows.card(false),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(45)),
            ),
            child: const Icon(
              Icons.landscape_outlined,
              color: AdvantaColors.goldLight,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan luasan aktual',
                  style: AdvantaText.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  syncLabel,
                  style: AdvantaText.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  'Summary mengikuti kelompok filter di bawah.',
                  style: AdvantaText.caption.copyWith(
                    color: Colors.white.withAlpha(165),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantingAreaSummary extends StatelessWidget {
  const _PlantingAreaSummary({required this.summary});

  final PlantingDataMonitorSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Total data tanam',
        summary.plantedAreaHa,
        Icons.agriculture_outlined,
        AdvantaColors.primaryGreen,
        'Luas awal ${_integer(summary.fieldCount)} FN',
      ),
      (
        'Discard / PLD',
        summary.discardAreaHa,
        Icons.flag_outlined,
        const Color(0xFFE67E22),
        'Tanam dikurangi effective',
      ),
      (
        'Effective area',
        summary.effectiveAreaHa,
        Icons.verified_outlined,
        const Color(0xFF2E7D6B),
        'Area netto aktif',
      ),
      (
        'Harvested area',
        summary.harvestedAreaHa,
        Icons.inventory_2_outlined,
        const Color(0xFF8D6E20),
        'Luas panen aman',
      ),
      (
        'Standing crop sisa',
        summary.standingCropAreaHa,
        Icons.grass_rounded,
        const Color(0xFF1976A3),
        'Effective dikurangi panen',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Summary area',
                  style: AdvantaText.heading3.copyWith(
                    color: AdvantaColors.deepForest,
                  ),
                ),
              ),
              if (summary.harvestNeedsReview > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withAlpha(30),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_integer(summary.harvestNeedsReview)} review',
                    style: AdvantaText.caption.copyWith(
                      color: const Color(0xFF9A5A00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < metrics.length; index++)
                    SizedBox(
                      width: index == metrics.length - 1
                          ? constraints.maxWidth
                          : cardWidth,
                      child: _AreaSummaryCard(
                        label: metrics[index].$1,
                        area: metrics[index].$2,
                        icon: metrics[index].$3,
                        color: metrics[index].$4,
                        caption: metrics[index].$5,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Validasi: total tanam = PLD + effective, dan effective = harvested + standing crop.',
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 4),
          Text(
            'Sumber summary: master_fields aktif KC, termasuk FN KC-only yang tidak dihapus oleh sync ACT.',
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ],
      ),
    );
  }
}

class _AreaSummaryCard extends StatelessWidget {
  const _AreaSummaryCard({
    required this.label,
    required this.area,
    required this.icon,
    required this.color,
    required this.caption,
  });

  final String label;
  final double area;
  final IconData icon;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdvantaText.label.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${_area(area)} ha',
            style: AdvantaText.heading2.copyWith(
              color: AdvantaColors.deepForest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ],
      ),
    );
  }
}

class _SyncHero extends StatelessWidget {
  const _SyncHero({required this.status});

  final ActSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final syncing = status.isSyncing;
    final attention = status.hasSyncError;
    final color = attention
        ? const Color(0xFFFFB74D)
        : syncing
        ? AdvantaColors.goldLight
        : const Color(0xFF8BE0AC);
    final title = attention
        ? 'Sinkronisasi perlu diperiksa'
        : syncing
        ? 'Sinkronisasi sedang berjalan'
        : 'Data ACT sudah tersinkron';
    final sourceDate = status.lastSuccessSourceDate == null
        ? '-'
        : DateFormat(
            'd MMM yyyy',
            'id_ID',
          ).format(status.lastSuccessSourceDate!);
    final completed = status.lastSuccessAt == null
        ? null
        : DateFormat('d MMM • HH:mm', 'id_ID').format(status.lastSuccessAt!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdvantaColors.deepForest, AdvantaColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AdvantaShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(100)),
                ),
                child: Icon(
                  attention
                      ? Icons.warning_amber_rounded
                      : syncing
                      ? Icons.sync_rounded
                      : Icons.cloud_done_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AdvantaText.heading2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status ${status.latestStatus}',
                      style: AdvantaText.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _integer(status.totalRows),
            style: AdvantaText.display.copyWith(color: Colors.white),
          ),
          Text(
            'Field Number dari ACT • data sampai $sourceDate',
            style: AdvantaText.body2.copyWith(color: Colors.white70),
          ),
          if (completed != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white60,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  'Selesai $completed',
                  style: AdvantaText.caption.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncMetrics extends StatelessWidget {
  const _SyncMetrics({required this.status});

  final ActSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('FC', status.fcCount, Icons.grass_rounded),
      ('PS', status.psCount, Icons.eco_outlined),
      ('SC', status.scCount, Icons.agriculture_outlined),
      ('Diperbarui', status.updatedRows, Icons.update_rounded),
      ('Missing ACT', status.missingSourceRows, Icons.find_in_page_outlined),
      ('Invalid', status.invalidRows, Icons.report_problem_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.12,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AdvantaRadius.cardRadius,
            border: Border.all(color: AdvantaColors.dividerGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(metric.$3, size: 18, color: AdvantaColors.primaryGreen),
              Text(
                _integer(metric.$2),
                style: AdvantaText.heading3.copyWith(
                  color: AdvantaColors.deepForest,
                ),
              ),
              Text(
                metric.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdvantaText.caption.copyWith(
                  color: AdvantaColors.mutedGrey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutomationNote extends StatelessWidget {
  const _AutomationNote({required this.status});

  final ActSyncStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdvantaColors.paleGreen,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.lightGreen.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_send_outlined,
            color: AdvantaColors.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.isSyncing
                  ? 'Server sedang mengambil dan memvalidasi data ACT. Data KC lama tetap aman sampai transaksi selesai.'
                  : 'Sinkronisasi berjalan otomatis di server setiap pukul 01.00 WIB. Tombol refresh hanya memperbarui status, bukan memulai sync baru.',
              style: AdvantaText.body2.copyWith(
                color: AdvantaColors.deepForest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.reviews});

  final List<ActHarvestReview> reviews;

  @override
  Widget build(BuildContext context) {
    final attention = reviews
        .where((item) => item.status == 'NEEDS_CONFIRMATION')
        .length;
    final totalDelta = reviews.fold<double>(
      0,
      (value, item) =>
          value +
          (item.reportedHarvestAreaHa - item.safeHarvestAreaHa).clamp(
            0,
            double.infinity,
          ),
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: attention == 0
            ? AdvantaColors.paleGreen
            : const Color(0xFFFFF5E5),
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: attention == 0
              ? AdvantaColors.lightGreen.withAlpha(90)
              : const Color(0xFFFFB74D).withAlpha(120),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: attention == 0
                  ? AdvantaColors.successLight
                  : const Color(0xFFFFB74D).withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(
              attention == 0
                  ? Icons.verified_outlined
                  : Icons.fact_check_outlined,
              color: attention == 0
                  ? AdvantaColors.success
                  : const Color(0xFFE58A00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attention == 0
                      ? 'Tidak ada review terbuka'
                      : '${_integer(attention)} FN perlu konfirmasi',
                  style: AdvantaText.bodyBold.copyWith(
                    color: AdvantaColors.deepForest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attention == 0
                      ? 'Area Harvest konsisten dengan effective area.'
                      : 'Selisih area ACT yang diamankan ${_area(totalDelta)} ha',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestReviewCard extends StatelessWidget {
  const _HarvestReviewCard({required this.review});

  final ActHarvestReview review;

  @override
  Widget build(BuildContext context) {
    final needsConfirmation = review.status == 'NEEDS_CONFIRMATION';
    final delta = (review.reportedHarvestAreaHa - review.safeHarvestAreaHa)
        .clamp(0, double.infinity);
    final lastHarvest = review.lastHarvestDate == null
        ? '-'
        : DateFormat('d MMM yyyy', 'id_ID').format(review.lastHarvestDate!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsConfirmation
              ? const Color(0xFFFFB74D).withAlpha(130)
              : AdvantaColors.dividerGrey,
        ),
        boxShadow: AdvantaShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.fieldNumber,
                      style: AdvantaText.heading3.copyWith(
                        color: AdvantaColors.deepForest,
                      ),
                    ),
                    Text(
                      [
                        review.farmerName,
                        review.hybrid,
                      ].whereType<String>().join(' • '),
                      style: AdvantaText.body2.copyWith(
                        color: AdvantaColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              _ReviewStatusBadge(status: review.status),
            ],
          ),
          if (review.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 9),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: review.locationLabel,
            ),
          ],
          const SizedBox(height: 5),
          _InfoLine(
            icon: Icons.person_outline_rounded,
            text:
                'QA/FI ${review.qaOwner}'
                '${review.region == null ? '' : ' • ${review.region}'}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AreaMetric(
                  label: 'Effective',
                  value: review.effectiveAreaHa,
                  color: AdvantaColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AreaMetric(
                  label: 'Laporan ACT',
                  value: review.reportedHarvestAreaHa,
                  color: AdvantaColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AreaMetric(
                  label: 'Dipakai KC',
                  value: review.safeHarvestAreaHa,
                  color: AdvantaColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${review.harvestEventCount} event • terakhir $lastHarvest',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
                  ),
                ),
              ),
              if (delta > 0)
                Text(
                  '+${_area(delta)} ha perlu dicek',
                  style: AdvantaText.label.copyWith(color: AdvantaColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncHistoryList extends StatelessWidget {
  const _SyncHistoryList({required this.items});

  final List<ActSyncHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.history_toggle_off_rounded,
        title: 'Belum ada riwayat',
        message: 'Riwayat akan muncul setelah server menjalankan sinkronisasi.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _HistoryTile(item: items[index]),
            if (index != items.length - 1) const Divider(height: 1, indent: 52),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final ActSyncHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final success = item.isSuccessful;
    final period = item.sourceFrom == null || item.sourceTo == null
        ? '-'
        : '${DateFormat('d MMM', 'id_ID').format(item.sourceFrom!)}–${DateFormat('d MMM yyyy', 'id_ID').format(item.sourceTo!)}';
    final time = item.completedAt ?? item.startedAt;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: success ? AdvantaColors.successLight : const Color(0xFFFFF5E5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          success ? Icons.check_rounded : Icons.warning_amber_rounded,
          color: success ? AdvantaColors.success : const Color(0xFFE58A00),
          size: 19,
        ),
      ),
      title: Text(
        '${item.status} • $period',
        style: AdvantaText.bodyBold.copyWith(color: AdvantaColors.deepForest),
      ),
      subtitle: Text(
        '${DateFormat('d MMM, HH:mm', 'id_ID').format(time)} • '
        '${_integer(item.sourceRows)} sumber • '
        '${_integer(item.updatedRows)} update',
        style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AdvantaColors.paleGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AdvantaColors.primaryGreen, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdvantaText.heading3.copyWith(
                  color: AdvantaColors.deepForest,
                ),
              ),
              Text(
                subtitle,
                style: AdvantaText.caption.copyWith(
                  color: AdvantaColors.mutedGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => onSelected(value == _allValue ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: _allValue, child: Text('Semua')),
        ...options.map(
          (item) => PopupMenuItem<String>(value: item, child: Text(item)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected == null ? Colors.white : AdvantaColors.paleGreen,
          borderRadius: AdvantaRadius.chipRadius,
          border: Border.all(
            color: selected == null
                ? AdvantaColors.dividerGrey
                : AdvantaColors.primaryGreen.withAlpha(90),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AdvantaColors.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: AdvantaText.label.copyWith(
                color: AdvantaColors.deepForest,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AdvantaColors.mutedGrey,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AdvantaColors.primaryGreen,
      labelStyle: AdvantaText.label.copyWith(
        color: selected ? Colors.white : AdvantaColors.deepForest,
      ),
      side: BorderSide(
        color: selected
            ? AdvantaColors.primaryGreen
            : AdvantaColors.dividerGrey,
      ),
      backgroundColor: Colors.white,
      showCheckmark: false,
    );
  }
}

class _ReviewStatusBadge extends StatelessWidget {
  const _ReviewStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final attention = status == 'NEEDS_CONFIRMATION';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: attention ? const Color(0xFFFFF5E5) : AdvantaColors.paleGreen,
        borderRadius: AdvantaRadius.chipRadius,
      ),
      child: Text(
        attention ? 'Perlu konfirmasi' : 'Sudah direview',
        style: AdvantaText.caption.copyWith(
          color: attention ? const Color(0xFFB86600) : AdvantaColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AreaMetric extends StatelessWidget {
  const _AreaMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 2),
          Text(
            '${_area(value)} ha',
            style: AdvantaText.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AdvantaColors.mutedGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ),
      ],
    );
  }
}

class _MonitorLoading extends StatelessWidget {
  const _MonitorLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 14),
          Text('Memuat status ACT…'),
        ],
      ),
    );
  }
}

class _ReviewLoading extends StatelessWidget {
  const _ReviewLoading();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(message: 'Memuat daftar review panen…');
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(message: 'Memuat riwayat sync…');
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(message, style: AdvantaText.body2),
        ],
      ),
    );
  }
}

class _MonitorError extends StatelessWidget {
  const _MonitorError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _InlineError(message: message, onRetry: onRetry),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdvantaColors.errorLight,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.error.withAlpha(60)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AdvantaColors.error,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AdvantaText.bodyBold.copyWith(color: AdvantaColors.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({this.filtered = false});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return _EmptyPanel(
      icon: filtered ? Icons.search_off_rounded : Icons.verified_outlined,
      title: filtered ? 'Tidak ada hasil' : 'Area panen aman',
      message: filtered
          ? 'Ubah atau reset filter untuk melihat FN lainnya.'
          : 'Tidak ada FN Harvest yang memerlukan konfirmasi.',
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: AdvantaColors.dividerGrey),
      ),
      child: Column(
        children: [
          Icon(icon, color: AdvantaColors.primaryGreen, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            style: AdvantaText.bodyBold.copyWith(
              color: AdvantaColors.deepForest,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ],
      ),
    );
  }
}

String _integer(int value) =>
    NumberFormat.decimalPattern('id_ID').format(value);

String _area(num value) => NumberFormat('0.##', 'id_ID').format(value);
