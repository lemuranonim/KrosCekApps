import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/act_sync_status.dart';
import '../providers/act_sync_status_provider.dart';
import '../theme/app_theme.dart';

class ActSyncStatusStrip extends ConsumerWidget {
  const ActSyncStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(actSyncStatusProvider);

    return statusAsync.when(
      loading: () => _StatusStripShell(
        icon: Icons.sync_rounded,
        color: AdvantaColors.goldLight,
        label: 'Memeriksa sinkronisasi ACT…',
        onTap: null,
      ),
      error: (_, __) => _StatusStripShell(
        icon: Icons.cloud_off_outlined,
        color: AdvantaColors.goldLight,
        label: 'Status sinkronisasi ACT belum tersedia',
        onTap: () => ref.invalidate(actSyncStatusProvider),
      ),
      data: (status) {
        final presentation = _presentation(status);
        return _StatusStripShell(
          icon: presentation.icon,
          color: presentation.color,
          label: presentation.label,
          onTap: () => _showDetails(context, ref, status),
        );
      },
    );
  }

  _StatusPresentation _presentation(ActSyncStatus status) {
    if (status.isSyncing) {
      final target = _formatDate(status.latestTargetSourceDate);
      return _StatusPresentation(
        icon: Icons.sync_rounded,
        color: AdvantaColors.goldLight,
        label: target == null
            ? 'Sinkronisasi ACT sedang berjalan'
            : 'Sinkronisasi ACT berjalan • target $target',
      );
    }

    if (status.needsAttention) {
      final lastSuccess = _formatDate(status.lastSuccessSourceDate);
      return _StatusPresentation(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFFB74D),
        label: lastSuccess == null
            ? 'Sinkronisasi ACT perlu diperiksa'
            : 'Sync ACT perlu diperiksa • data terakhir $lastSuccess',
      );
    }

    if (!status.hasSuccessfulSync) {
      return const _StatusPresentation(
        icon: Icons.cloud_off_outlined,
        color: Color(0xFFFFB74D),
        label: 'Data ACT belum pernah disinkronkan',
      );
    }

    final sourceDate = _formatDate(status.lastSuccessSourceDate) ?? '-';
    final total = _formatNumber(status.totalRows);
    if (status.isCurrent) {
      return _StatusPresentation(
        icon: Icons.cloud_done_rounded,
        color: const Color(0xFF8BE0AC),
        label: 'ACT tersinkron • $sourceDate • $total FN',
      );
    }

    return _StatusPresentation(
      icon: Icons.schedule_rounded,
      color: AdvantaColors.goldLight,
      label: 'Data ACT terakhir $sourceDate • menunggu sync harian',
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ActSyncStatus status,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ActSyncStatusSheet(
        status: status,
        onRefresh: () {
          ref.invalidate(actSyncStatusProvider);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  static String _formatNumber(int value) {
    return NumberFormat.decimalPattern('id_ID').format(value);
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    return DateFormat('d MMM yyyy', 'id_ID').format(value);
  }
}

class _StatusStripShell extends StatelessWidget {
  const _StatusStripShell({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Material(
        color: AdvantaColors.deepForest.withAlpha(215),
        borderRadius: AdvantaRadius.chipRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AdvantaRadius.chipRadius,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: AdvantaRadius.chipRadius,
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdvantaText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white.withAlpha(180),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActSyncStatusSheet extends StatelessWidget {
  const _ActSyncStatusSheet({required this.status, required this.onRefresh});

  final ActSyncStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final attention = status.needsAttention;
    final syncing = status.isSyncing;
    final accent = attention
        ? const Color(0xFFFFB74D)
        : syncing
        ? AdvantaColors.goldLight
        : const Color(0xFF8BE0AC);
    final title = attention
        ? 'Sinkronisasi perlu diperiksa'
        : syncing
        ? 'Sinkronisasi sedang berjalan'
        : status.isCurrent
        ? 'Data ACT sudah tersinkron'
        : 'Menunggu sinkronisasi harian';

    return Container(
      decoration: const BoxDecoration(
        color: AdvantaColors.deepForest,
        borderRadius: AdvantaRadius.sheetRadius,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(80),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      attention
                          ? Icons.warning_amber_rounded
                          : syncing
                          ? Icons.sync_rounded
                          : Icons.cloud_done_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AdvantaText.heading3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(status),
                          style: AdvantaText.caption.copyWith(
                            color: Colors.white.withAlpha(185),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Perbarui status',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(label: 'Data ACT', value: status.totalRows),
                  _Metric(label: 'FC', value: status.fcCount),
                  _Metric(label: 'PS', value: status.psCount),
                  _Metric(label: 'SC', value: status.scCount),
                  _Metric(label: 'Ditambah', value: status.insertedRows),
                  _Metric(label: 'Diperbarui', value: status.updatedRows),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: AdvantaRadius.cardRadius,
                  border: Border.all(color: Colors.white.withAlpha(28)),
                ),
                child: Text(
                  'Sinkronisasi hanya melakukan insert/update yang lolos '
                  'validasi. Field KC yang tidak ditemukan di ACT tidak '
                  'dihapus otomatis.',
                  style: AdvantaText.caption.copyWith(
                    color: Colors.white.withAlpha(190),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(ActSyncStatus status) {
    if (status.isSyncing) {
      final target = status.latestTargetSourceDate;
      return target == null
          ? 'Data sedang diambil dan divalidasi.'
          : 'Target data sampai ${_date(target)}.';
    }

    final sourceDate = status.lastSuccessSourceDate;
    final syncedAt = status.lastSuccessAt;
    if (sourceDate == null) return 'Belum ada sinkronisasi yang berhasil.';

    final sourceLabel = _date(sourceDate);
    if (syncedAt == null) return 'Data ACT sampai $sourceLabel.';
    return 'Data ACT sampai $sourceLabel • selesai '
        '${DateFormat('d MMM, HH:mm', 'id_ID').format(syncedAt)}';
  }

  static String _date(DateTime value) {
    return DateFormat('d MMM yyyy', 'id_ID').format(value);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 64) / 3,
      constraints: const BoxConstraints(minWidth: 88, maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdvantaColors.midGreen.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            NumberFormat.decimalPattern('id_ID').format(value),
            style: AdvantaText.bodyBold.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdvantaText.caption.copyWith(
              color: Colors.white.withAlpha(170),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}
