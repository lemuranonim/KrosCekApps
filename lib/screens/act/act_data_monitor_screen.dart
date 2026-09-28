import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/act_sync_status.dart';
import '../../providers/act_sync_status_provider.dart';
import '../../theme/app_theme.dart';

enum ActReviewStatusFilter { all, needsConfirmation, reviewed }

List<ActHarvestReview> filterActHarvestReviews(
  List<ActHarvestReview> source, {
  String query = '',
  String? region,
  String? district,
  String? owner,
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
  const ActDataMonitorScreen({super.key});

  @override
  ConsumerState<ActDataMonitorScreen> createState() =>
      _ActDataMonitorScreenState();
}

class _ActDataMonitorScreenState extends ConsumerState<ActDataMonitorScreen> {
  final _searchController = TextEditingController();
  String? _region;
  String? _district;
  String? _owner;
  ActReviewStatusFilter _statusFilter = ActReviewStatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(actSyncStatusProvider);
    ref.invalidate(actSyncHarvestReviewsProvider);
    ref.invalidate(actSyncHistoryProvider);
    await Future.wait([
      ref.read(actSyncStatusProvider.future),
      ref.read(actSyncHarvestReviewsProvider.future),
      ref.read(actSyncHistoryProvider.future),
    ]);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _region = null;
      _district = null;
      _owner = null;
      _statusFilter = ActReviewStatusFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(actSyncStatusProvider);
    final reviewsAsync = ref.watch(actSyncHarvestReviewsProvider);
    final historyAsync = ref.watch(actSyncHistoryProvider);

    return Scaffold(
      backgroundColor: AdvantaColors.softGrey,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACT Data Monitor'),
            Text(
              'Sync, PLD & Harvest Review',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui status',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: statusAsync.when(
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
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Review panen',
                subtitle: status.hasHarvestReview
                    ? '${_integer(status.harvestNeedsReview)} FN memerlukan konfirmasi'
                    : 'Tidak ada anomali area panen',
                icon: Icons.fact_check_outlined,
              ),
              const SizedBox(height: 10),
              reviewsAsync.when(
                loading: () => const _ReviewLoading(),
                error: (error, _) => _InlineError(
                  message: 'Daftar review belum dapat dimuat.',
                  onRetry: () => ref.invalidate(actSyncHarvestReviewsProvider),
                ),
                data: _buildReviews,
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
      ),
    );
  }

  Widget _buildReviews(List<ActHarvestReview> reviews) {
    final regions = _options(reviews.map((item) => item.region));
    final districts = _options(
      reviews
          .where((item) => _region == null || item.region == _region)
          .map((item) => item.district),
    );
    final owners = _options(
      reviews
          .where((item) => _region == null || item.region == _region)
          .where((item) => _district == null || item.district == _district)
          .map((item) => item.qaOwner == '-' ? null : item.qaOwner),
    );
    final filtered = filterActHarvestReviews(
      reviews,
      query: _searchController.text,
      region: _region,
      district: _district,
      owner: _owner,
      status: _statusFilter,
    );
    final hasFilters =
        _searchController.text.trim().isNotEmpty ||
        _region != null ||
        _district != null ||
        _owner != null ||
        _statusFilter != ActReviewStatusFilter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewSummary(reviews: reviews),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterMenu(
                  label: _region ?? 'Semua region',
                  icon: Icons.map_outlined,
                  selected: _region,
                  options: regions,
                  onSelected: (value) => setState(() {
                    _region = value;
                    _district = null;
                    _owner = null;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _district ?? 'Semua kabupaten',
                  icon: Icons.location_city_outlined,
                  selected: _district,
                  options: districts,
                  onSelected: (value) => setState(() {
                    _district = value;
                    _owner = null;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: _owner ?? 'Semua QA/FI',
                  icon: Icons.person_search_outlined,
                  selected: _owner,
                  options: owners,
                  onSelected: (value) => setState(() => _owner = value),
                ),
              ],
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

  static List<String> _options(Iterable<String?> values) {
    final items = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    items.sort();
    return items;
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
        '${_integer(item.updatedRows)} update • '
        '${_integer(item.harvestNeedsReview)} review',
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('Semua')),
        ...options.map(
          (item) => PopupMenuItem<String?>(value: item, child: Text(item)),
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
