import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/qa_mapping_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class QaMappingScreen extends ConsumerStatefulWidget {
  const QaMappingScreen({super.key});

  @override
  ConsumerState<QaMappingScreen> createState() => _QaMappingScreenState();
}

class _QaMappingScreenState extends ConsumerState<QaMappingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _selectedIds = <int>{};

  String _searchQuery = '';
  _QaCoverageFilters _filters = const _QaCoverageFilters();
  bool _selectionMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runMutation(
      Future<void> Function() action, String successMessage) async {
    await action();
    if (!mounted) return;

    final state = ref.read(qaMappingProvider);
    state.whenOrNull(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      },
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $error')),
        );
      },
    );
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(QaMappingItem item) {
    setState(() {
      _selectionMode = true;
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _showForm(BuildContext context, [QaMappingItem? existingData]) {
    final isEdit = existingData != null;

    ref.read(selectedKabupatenProvider.notifier).select(null);
    ref.read(selectedKecamatanProvider.notifier).select(null);
    ref.read(selectedDesaProvider.notifier).select(null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => _WilayahFormSheet(
        isEdit: isEdit,
        existingData: existingData,
        onSave: (dataToSave) async {
          if (isEdit) {
            await _runMutation(
              () => ref
                  .read(qaMappingProvider.notifier)
                  .updateMapping(existingData.id, dataToSave),
              'Coverage berhasil diperbarui.',
            );
          } else {
            await _runMutation(
              () => ref.read(qaMappingProvider.notifier).addMapping(dataToSave),
              'Coverage berhasil ditambahkan.',
            );
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, List<int> ids) {
    final theme = Theme.of(context);
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        title: Text(
          'Nonaktifkan Mapping?',
          style:
              AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ids.length} data coverage akan dinonaktifkan. Jika kolom soft delete belum tersedia, sistem akan memakai fallback lama.',
              style: AdvantaText.body2
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                  labelText: 'Alasan perubahan (opsional)'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _runMutation(
                () => ref.read(qaMappingProvider.notifier).deactivateMappings(
                      ids: ids,
                      reason: reasonCtrl.text,
                    ),
                'Mapping berhasil dinonaktifkan.',
              );
              _clearSelection();
            },
            child: const Text('NONAKTIFKAN'),
          ),
        ],
      ),
    ).whenComplete(reasonCtrl.dispose);
  }

  void _confirmHardDelete(BuildContext context, int id) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        title: Text(
          'Hapus Permanen?',
          style:
              AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Aksi ini menghapus row dari master_qa_mapping dan tidak bisa dibatalkan.',
          style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _runMutation(
                () => ref.read(qaMappingProvider.notifier).deleteMapping(id),
                'Mapping berhasil dihapus permanen.',
              );
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    List<QaMappingItem> mappings,
    bool isRestricted,
  ) {
    final theme = Theme.of(context);
    final regions = _uniqueOptions(mappings.map((item) => item.region));
    final spvs = _uniqueOptions(mappings.map((item) => item.qaSpv));
    final fis = _uniqueOptions(mappings.map((item) => item.qaFi));
    final districts = _uniqueOptions(mappings.map((item) => item.districtKab));
    final subDistricts =
        _uniqueOptions(mappings.map((item) => item.subDistrictKec));
    final fas = _uniqueOptions(mappings.map((item) => item.fa));
    final statuses = _uniqueOptions(mappings.map((item) => item.status));

    var draft = _filters;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHandle(theme: theme),
                  Text(
                    'Filter Coverage',
                    style: AdvantaText.heading2
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  _FilterDropdown(
                    label: 'Region',
                    value: draft.region,
                    options: regions,
                    onChanged: (value) => setSheetState(() {
                      draft = draft.copyWith(region: value);
                    }),
                  ),
                  if (!isRestricted)
                    _FilterDropdown(
                      label: 'QA SPV',
                      value: draft.qaSpv,
                      options: spvs,
                      onChanged: (value) => setSheetState(() {
                        draft = draft.copyWith(qaSpv: value);
                      }),
                    ),
                  if (!isRestricted)
                    _FilterDropdown(
                      label: 'QA FI',
                      value: draft.qaFi,
                      options: fis,
                      onChanged: (value) => setSheetState(() {
                        draft = draft.copyWith(qaFi: value);
                      }),
                    ),
                  _FilterDropdown(
                    label: 'Kabupaten',
                    value: draft.districtKab,
                    options: districts,
                    onChanged: (value) => setSheetState(() {
                      draft = draft.copyWith(districtKab: value);
                    }),
                  ),
                  _FilterDropdown(
                    label: 'Kecamatan',
                    value: draft.subDistrictKec,
                    options: subDistricts,
                    onChanged: (value) => setSheetState(() {
                      draft = draft.copyWith(subDistrictKec: value);
                    }),
                  ),
                  _FilterDropdown(
                    label: 'FA',
                    value: draft.fa,
                    options: fas,
                    onChanged: (value) => setSheetState(() {
                      draft = draft.copyWith(fa: value);
                    }),
                  ),
                  _FilterDropdown(
                    label: 'Status',
                    value: draft.status,
                    options: statuses,
                    onChanged: (value) => setSheetState(() {
                      draft = draft.copyWith(status: value);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            draft = const _QaCoverageFilters();
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _filters = draft);
                            Navigator.pop(ctx);
                          },
                          child: const Text('TERAPKAN'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBulkReassignSheet(List<QaMappingItem> selectedItems) {
    if (selectedItems.isEmpty) return;

    final theme = Theme.of(context);
    final qaFiCtrl = TextEditingController();
    final qaSpvCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final totalHa = _sumHa(selectedItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(theme: theme),
              Text(
                'Reassign QA FI',
                style: AdvantaText.heading2
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                '${selectedItems.length} mapping dipilih • ${_formatHa(totalHa)} ha',
                style:
                    AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: qaFiCtrl,
                decoration: const InputDecoration(labelText: 'QA FI baru'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qaSpvCtrl,
                decoration:
                    const InputDecoration(labelText: 'QA SPV baru (opsional)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                    labelText: 'Alasan perubahan (opsional)'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              Text(
                'Preview',
                style: AdvantaText.bodyBold
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              ...selectedItems.take(5).map((item) => _PreviewRow(item: item)),
              if (selectedItems.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${selectedItems.length - 5} data lainnya',
                    style: AdvantaText.caption
                        .copyWith(color: AdvantaColors.mutedGrey),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final qaFi = qaFiCtrl.text.trim();
                        if (qaFi.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('QA FI baru wajib diisi.')),
                          );
                          return;
                        }

                        final data = <String, dynamic>{'qa_fi': qaFi};
                        if (qaSpvCtrl.text.trim().isNotEmpty) {
                          data['qa_spv'] = qaSpvCtrl.text.trim();
                        }
                        if (reasonCtrl.text.trim().isNotEmpty) {
                          data['change_reason'] = reasonCtrl.text.trim();
                        }

                        Navigator.pop(ctx);
                        await _runMutation(
                          () => ref
                              .read(qaMappingProvider.notifier)
                              .bulkUpdateMappings(
                                ids: selectedItems
                                    .map((item) => item.id)
                                    .toList(),
                                data: data,
                              ),
                          'Bulk reassign QA FI berhasil.',
                        );
                        _clearSelection();
                      },
                      child: const Text('SIMPAN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      qaFiCtrl.dispose();
      qaSpvCtrl.dispose();
      reasonCtrl.dispose();
    });
  }

  void _showBulkSpvSheet(List<QaMappingItem> selectedItems) {
    if (selectedItems.isEmpty) return;
    final theme = Theme.of(context);
    final qaSpvCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.sheetRadius),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(theme: theme),
            Text(
              'Update QA SPV',
              style: AdvantaText.heading2
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qaSpvCtrl,
              decoration: const InputDecoration(labelText: 'QA SPV baru'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final qaSpv = qaSpvCtrl.text.trim();
                      if (qaSpv.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('QA SPV baru wajib diisi.')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      await _runMutation(
                        () => ref
                            .read(qaMappingProvider.notifier)
                            .bulkUpdateMappings(
                          ids: selectedItems.map((item) => item.id).toList(),
                          data: {'qa_spv': qaSpv},
                        ),
                        'Bulk update QA SPV berhasil.',
                      );
                      _clearSelection();
                    },
                    child: const Text('SIMPAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(qaSpvCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mappingState = ref.watch(qaMappingProvider);
    final sessionAsync = ref.watch(currentSessionProvider);
    final session = sessionAsync.whenOrNull(data: (value) => value);
    final currentMappings = mappingState.whenOrNull(data: (value) => value);
    final isRestricted = session?.isRestricted ?? true;
    final canHardDelete =
        !isRestricted && session?.role.toUpperCase() == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedIds.length} dipilih')
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QA Coverage'),
                  SizedBox(height: 2),
                  Text(
                    'Kelola coverage wilayah QA FI',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
        elevation: 0,
        actions: [
          if (!_selectionMode && !isRestricted)
            TextButton.icon(
              onPressed: () => setState(() => _selectionMode = true),
              icon: Icon(Icons.checklist_rounded,
                  color: theme.appBarTheme.foregroundColor),
              label: Text(
                'Pilih',
                style: AdvantaText.label
                    .copyWith(color: theme.appBarTheme.foregroundColor),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(qaMappingProvider.notifier).refresh(),
          ),
        ],
      ),
      body: mappingState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: AdvantaBanner.error(message: 'Terjadi kesalahan: $err'),
        ),
        data: (mappings) {
          final conflictIndex = buildQaMappingConflictIndex(
            mappings.where((item) => item.isActive).toList(),
          );
          final filteredMappings = mappings.where((item) {
            return item.matchesSearch(_searchQuery) && _filters.matches(item);
          }).toList();
          final summary = _QaCoverageSummary.fromItems(
            filteredMappings,
            conflictIndex,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _SearchAndFilterBar(
                  controller: _searchCtrl,
                  query: _searchQuery,
                  activeFilterCount:
                      _filters.activeCount(isRestricted: isRestricted),
                  isDark: isDark,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onClearSearch: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    FocusScope.of(context).unfocus();
                  },
                  onFilter: () =>
                      _showFilterSheet(context, mappings, isRestricted),
                  onResetFilters: _filters.hasActive
                      ? () =>
                          setState(() => _filters = const _QaCoverageFilters())
                      : null,
                ),
              ),
              if (_filters.hasActive)
                _ActiveFilterChips(
                  filters: _filters,
                  isRestricted: isRestricted,
                  onRemove: (next) => setState(() => _filters = next),
                ),
              _SummaryStrip(
                summary: summary,
                isRestricted: isRestricted,
                isDark: isDark,
              ),
              if (_selectionMode && isRestricted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AdvantaBanner.info(
                    message: 'Bulk action hanya tersedia untuk QA SPV/Admin.',
                  ),
                ),
              Expanded(
                child: filteredMappings.isEmpty
                    ? _EmptyState(
                        isEmptySource: mappings.isEmpty,
                        theme: theme,
                      )
                    : ListView.builder(
                        itemCount: filteredMappings.length,
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom: _selectionMode ? 120 : 100,
                        ),
                        itemBuilder: (ctx, index) {
                          final item = filteredMappings[index];
                          final isSelected = _selectedIds.contains(item.id);
                          return _CoverageCard(
                            item: item,
                            isDark: isDark,
                            isSelected: isSelected,
                            selectionMode: _selectionMode,
                            hasConflict: conflictIndex.hasConflict(item),
                            canBulk: !isRestricted,
                            canHardDelete: canHardDelete,
                            onTap: _selectionMode && !isRestricted
                                ? () => _toggleSelection(item)
                                : null,
                            onLongPress: !isRestricted
                                ? () => _toggleSelection(item)
                                : null,
                            onEdit: () => _showForm(context, item),
                            onDeactivate: () =>
                                _confirmDeactivate(context, [item.id]),
                            onReassign: !isRestricted
                                ? () => _showBulkReassignSheet([item])
                                : null,
                            onHardDelete: canHardDelete
                                ? () => _confirmHardDelete(context, item.id)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selectionMode && !isRestricted
          ? _BulkActionBar(
              selectedCount: _selectedIds.length,
              onReassign: currentMappings == null
                  ? null
                  : () {
                      final items = currentMappings
                          .where((item) => _selectedIds.contains(item.id))
                          .toList();
                      _showBulkReassignSheet(items);
                    },
              onUpdateSpv: currentMappings == null
                  ? null
                  : () {
                      final items = currentMappings
                          .where((item) => _selectedIds.contains(item.id))
                          .toList();
                      _showBulkSpvSheet(items);
                    },
              onDeactivate: _selectedIds.isEmpty
                  ? null
                  : () => _confirmDeactivate(context, _selectedIds.toList()),
            )
          : null,
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 4,
              onPressed: () => _showForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _QaCoverageFilters {
  final String? region;
  final String? qaSpv;
  final String? qaFi;
  final String? districtKab;
  final String? subDistrictKec;
  final String? fa;
  final String? status;

  const _QaCoverageFilters({
    this.region,
    this.qaSpv,
    this.qaFi,
    this.districtKab,
    this.subDistrictKec,
    this.fa,
    this.status,
  });

  bool get hasActive => [
        region,
        qaSpv,
        qaFi,
        districtKab,
        subDistrictKec,
        fa,
        status,
      ].any((value) => value != null && value.trim().isNotEmpty);

  int activeCount({required bool isRestricted}) {
    return [
      region,
      if (!isRestricted) qaSpv,
      if (!isRestricted) qaFi,
      districtKab,
      subDistrictKec,
      fa,
      status,
    ].where((value) => value != null && value.trim().isNotEmpty).length;
  }

  bool matches(QaMappingItem item) {
    return item.matchesField(item.region, region) &&
        item.matchesField(item.qaSpv, qaSpv) &&
        item.matchesField(item.qaFi, qaFi) &&
        item.matchesField(item.districtKab, districtKab) &&
        item.matchesField(item.subDistrictKec, subDistrictKec) &&
        item.matchesField(item.fa, fa) &&
        item.matchesField(item.status, status);
  }

  _QaCoverageFilters copyWith({
    Object? region = _filterSentinel,
    Object? qaSpv = _filterSentinel,
    Object? qaFi = _filterSentinel,
    Object? districtKab = _filterSentinel,
    Object? subDistrictKec = _filterSentinel,
    Object? fa = _filterSentinel,
    Object? status = _filterSentinel,
  }) {
    return _QaCoverageFilters(
      region:
          identical(region, _filterSentinel) ? this.region : region as String?,
      qaSpv: identical(qaSpv, _filterSentinel) ? this.qaSpv : qaSpv as String?,
      qaFi: identical(qaFi, _filterSentinel) ? this.qaFi : qaFi as String?,
      districtKab: identical(districtKab, _filterSentinel)
          ? this.districtKab
          : districtKab as String?,
      subDistrictKec: identical(subDistrictKec, _filterSentinel)
          ? this.subDistrictKec
          : subDistrictKec as String?,
      fa: identical(fa, _filterSentinel) ? this.fa : fa as String?,
      status:
          identical(status, _filterSentinel) ? this.status : status as String?,
    );
  }
}

const Object _filterSentinel = Object();

class _QaCoverageSummary {
  final int totalMapping;
  final int totalDesa;
  final int totalKecamatan;
  final double totalHa;
  final int totalQaFi;
  final int totalConflict;

  const _QaCoverageSummary({
    required this.totalMapping,
    required this.totalDesa,
    required this.totalKecamatan,
    required this.totalHa,
    required this.totalQaFi,
    required this.totalConflict,
  });

  factory _QaCoverageSummary.fromItems(
    List<QaMappingItem> items,
    QaMappingConflictIndex conflictIndex,
  ) {
    final uniqueDesa = <String>{};
    final uniqueKec = <String>{};
    final uniqueFi = <String>{};
    var totalHa = 0.0;
    var totalConflict = 0;

    for (final item in items) {
      final desaKey = [item.districtKab, item.subDistrictKec, item.villageDesa]
          .map((part) => part.trim().toLowerCase())
          .join('|');
      final kecKey = [item.districtKab, item.subDistrictKec]
          .map((part) => part.trim().toLowerCase())
          .join('|');
      if (item.villageDesa.trim().isNotEmpty) uniqueDesa.add(desaKey);
      if (item.subDistrictKec.trim().isNotEmpty) uniqueKec.add(kecKey);
      if (item.qaFi.trim().isNotEmpty) {
        uniqueFi.add(item.qaFi.trim().toLowerCase());
      }
      totalHa += item.ha ?? 0;
      if (conflictIndex.hasConflict(item)) totalConflict++;
    }

    return _QaCoverageSummary(
      totalMapping: items.length,
      totalDesa: uniqueDesa.length,
      totalKecamatan: uniqueKec.length,
      totalHa: totalHa,
      totalQaFi: uniqueFi.length,
      totalConflict: totalConflict,
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final int activeFilterCount;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onFilter;
  final VoidCallback? onResetFilters;

  const _SearchAndFilterBar({
    required this.controller,
    required this.query,
    required this.activeFilterCount,
    required this.isDark,
    required this.onChanged,
    required this.onClearSearch,
    required this.onFilter,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: AdvantaText.body2
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Cari desa, kecamatan, FI, SPV...',
              hintStyle:
                  AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
              prefixIcon: const Icon(Icons.search,
                  color: AdvantaColors.mutedGrey, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AdvantaColors.mutedGrey, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? AdvantaColors.charcoal.withAlpha(50)
                  : AdvantaColors.softGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              tooltip: 'Filter',
              onPressed: onFilter,
              icon: const Icon(Icons.tune_rounded),
            ),
            if (activeFilterCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AdvantaColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFilterCount',
                    style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.charcoal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (onResetFilters != null)
          IconButton(
            tooltip: 'Reset filter',
            onPressed: onResetFilters,
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
      ],
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  final _QaCoverageFilters filters;
  final bool isRestricted;
  final ValueChanged<_QaCoverageFilters> onRemove;

  const _ActiveFilterChips({
    required this.filters,
    required this.isRestricted,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <({String label, _QaCoverageFilters next})>[
      if (filters.region != null)
        (
          label: 'Region: ${filters.region}',
          next: filters.copyWith(region: null)
        ),
      if (!isRestricted && filters.qaSpv != null)
        (label: 'SPV: ${filters.qaSpv}', next: filters.copyWith(qaSpv: null)),
      if (!isRestricted && filters.qaFi != null)
        (label: 'FI: ${filters.qaFi}', next: filters.copyWith(qaFi: null)),
      if (filters.districtKab != null)
        (
          label: 'Kab: ${filters.districtKab}',
          next: filters.copyWith(districtKab: null)
        ),
      if (filters.subDistrictKec != null)
        (
          label: 'Kec: ${filters.subDistrictKec}',
          next: filters.copyWith(subDistrictKec: null)
        ),
      if (filters.fa != null)
        (label: 'FA: ${filters.fa}', next: filters.copyWith(fa: null)),
      if (filters.status != null)
        (
          label: 'Status: ${filters.status}',
          next: filters.copyWith(status: null)
        ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return InputChip(
            label: Text(chip.label, overflow: TextOverflow.ellipsis),
            onDeleted: () => onRemove(chip.next),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final _QaCoverageSummary summary;
  final bool isRestricted;
  final bool isDark;

  const _SummaryStrip({
    required this.summary,
    required this.isRestricted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cards = isRestricted
        ? [
            _SummaryMetric(
                'Coverage saya', '${summary.totalMapping}', Icons.map_outlined),
            _SummaryMetric(
                'Desa', '${summary.totalDesa}', Icons.holiday_village_outlined),
            _SummaryMetric(
                'Kecamatan', '${summary.totalKecamatan}', Icons.location_city),
            _SummaryMetric(
                'Total HA', _formatHa(summary.totalHa), Icons.crop_square),
          ]
        : [
            _SummaryMetric(
                'Coverage team', '${summary.totalMapping}', Icons.map_outlined),
            _SummaryMetric(
                'QA FI', '${summary.totalQaFi}', Icons.person_search),
            _SummaryMetric(
                'Desa', '${summary.totalDesa}', Icons.holiday_village_outlined),
            _SummaryMetric('HA', _formatHa(summary.totalHa), Icons.crop_square),
            _SummaryMetric('Konflik', '${summary.totalConflict}',
                Icons.warning_amber_rounded),
          ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final metric = cards[index];
          return Container(
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: AdvantaRadius.cardRadius,
              boxShadow: AdvantaShadows.card(isDark),
              border: Border.all(
                color: isDark
                    ? AdvantaColors.goldLight.withAlpha(30)
                    : AdvantaColors.charcoal.withAlpha(12),
              ),
            ),
            child: Row(
              children: [
                Icon(metric.icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        metric.value,
                        style: AdvantaText.heading2.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        metric.label,
                        style: AdvantaText.caption
                            .copyWith(color: AdvantaColors.mutedGrey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryMetric {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric(this.label, this.value, this.icon);
}

class _CoverageCard extends StatelessWidget {
  final QaMappingItem item;
  final bool isDark;
  final bool isSelected;
  final bool selectionMode;
  final bool hasConflict;
  final bool canBulk;
  final bool canHardDelete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback? onReassign;
  final VoidCallback? onHardDelete;

  const _CoverageCard({
    required this.item,
    required this.isDark,
    required this.isSelected,
    required this.selectionMode,
    required this.hasConflict,
    required this.canBulk,
    required this.canHardDelete,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReassign,
    required this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : isDark
            ? AdvantaColors.goldLight.withAlpha(30)
            : AdvantaColors.charcoal.withAlpha(12);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: item.isActive ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: AdvantaRadius.cardRadius,
          boxShadow: AdvantaShadows.card(isDark),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: AdvantaRadius.cardRadius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: canBulk ? (_) => onTap?.call() : null,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Kec. ${_dash(item.subDistrictKec)} • ${_dash(item.villageDesa)}',
                              style: AdvantaText.bodyBold.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Badge(
                            icon: Icons.person_search,
                            label: 'FI ${_dash(item.qaFi)}',
                            color: theme.colorScheme.primary,
                          ),
                          if (item.qaSpv.isNotEmpty)
                            _Badge(
                              icon: Icons.supervisor_account,
                              label: 'SPV ${item.qaSpv}',
                              color: AdvantaColors.gold,
                            ),
                          _Badge(
                            icon: Icons.crop_square,
                            label: '${_formatHa(item.ha ?? 0)} ha',
                            color: AdvantaColors.midGreen,
                          ),
                          _Badge(
                            icon: hasConflict
                                ? Icons.warning_amber_rounded
                                : Icons.verified_outlined,
                            label: hasConflict ? 'Konflik' : 'Aman',
                            color: hasConflict
                                ? AdvantaColors.error
                                : AdvantaColors.success,
                          ),
                          if (!item.isActive)
                            const _Badge(
                              icon: Icons.pause_circle_outline,
                              label: 'Inactive',
                              color: AdvantaColors.mutedGrey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _subtitleRow(
                          Icons.public, 'Region', _dash(item.region), theme),
                      _subtitleRow(Icons.location_city, 'Kabupaten',
                          _dash(item.districtKab), theme),
                      _subtitleRow(
                          Icons.agriculture, 'FA', _dash(item.fa), theme),
                    ],
                  ),
                ),
                PopupMenuButton<_CoverageAction>(
                  tooltip: 'Aksi mapping',
                  onSelected: (action) {
                    switch (action) {
                      case _CoverageAction.edit:
                        onEdit();
                      case _CoverageAction.reassign:
                        onReassign?.call();
                      case _CoverageAction.deactivate:
                        onDeactivate();
                      case _CoverageAction.hardDelete:
                        onHardDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _CoverageAction.edit,
                      child: Text('Edit'),
                    ),
                    if (onReassign != null)
                      const PopupMenuItem(
                        value: _CoverageAction.reassign,
                        child: Text('Reassign QA FI'),
                      ),
                    const PopupMenuItem(
                      value: _CoverageAction.deactivate,
                      child: Text('Nonaktifkan'),
                    ),
                    if (canHardDelete)
                      const PopupMenuItem(
                        value: _CoverageAction.hardDelete,
                        child: Text('Hapus permanen'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtitleRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$label: $value',
              style:
                  AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CoverageAction { edit, reassign, deactivate, hardDelete }

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: AdvantaRadius.chipRadius,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              style: AdvantaText.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onReassign;
  final VoidCallback? onUpdateSpv;
  final VoidCallback? onDeactivate;

  const _BulkActionBar({
    required this.selectedCount,
    required this.onReassign,
    required this.onUpdateSpv,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: AdvantaShadows.card(
              Theme.of(context).brightness == Brightness.dark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedCount data dipilih',
                style: AdvantaText.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Reassign QA FI',
              onPressed: selectedCount == 0 ? null : onReassign,
              icon: const Icon(Icons.person_search),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Update QA SPV',
              onPressed: selectedCount == 0 ? null : onUpdateSpv,
              icon: const Icon(Icons.supervisor_account),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Nonaktifkan mapping',
              onPressed: selectedCount == 0 ? null : onDeactivate,
              icon: const Icon(Icons.pause_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Semua'),
          ),
          ...options.map(
            (option) => DropdownMenuItem<String?>(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final QaMappingItem item;

  const _PreviewRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 14, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_dash(item.districtKab)} • ${_dash(item.subDistrictKec)} • ${_dash(item.villageDesa)}',
              style:
                  AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isEmptySource;
  final ThemeData theme;

  const _EmptyState({
    required this.isEmptySource,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmptySource ? Icons.map_outlined : Icons.search_off_rounded,
            size: 64,
            color: AdvantaColors.mutedGrey.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            isEmptySource
                ? 'Belum ada data coverage.'
                : 'Data tidak ditemukan.',
            style: AdvantaText.heading3
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          Text(
            isEmptySource
                ? 'Silakan tambah pemetaan area kerja.'
                : 'Coba ubah kata kunci atau filter.',
            style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final ThemeData theme;

  const _SheetHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(50)
              : AdvantaColors.mutedGrey.withAlpha(80),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// =============================================================================
// Form Sheet
// =============================================================================
class _WilayahFormSheet extends ConsumerStatefulWidget {
  final bool isEdit;
  final QaMappingItem? existingData;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _WilayahFormSheet({
    required this.isEdit,
    required this.existingData,
    required this.onSave,
  });

  @override
  ConsumerState<_WilayahFormSheet> createState() => _WilayahFormSheetState();
}

class _WilayahFormSheetState extends ConsumerState<_WilayahFormSheet> {
  late TextEditingController _haCtrl;
  late TextEditingController _regionCtrl;
  late TextEditingController _qaSpvCtrl;
  late TextEditingController _qaFiCtrl;
  late TextEditingController _faCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingData;
    _haCtrl = TextEditingController(text: existing?.ha?.toString() ?? '');
    _regionCtrl = TextEditingController(text: existing?.region ?? '');
    _qaSpvCtrl = TextEditingController(text: existing?.qaSpv ?? '');
    _qaFiCtrl = TextEditingController(text: existing?.qaFi ?? '');
    _faCtrl = TextEditingController(text: existing?.fa ?? '');
  }

  @override
  void dispose() {
    _haCtrl.dispose();
    _regionCtrl.dispose();
    _qaSpvCtrl.dispose();
    _qaFiCtrl.dispose();
    _faCtrl.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    bool isNumeric = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _save(bool isRestricted, ActiveSession? session) async {
    final selectedKab = ref.read(selectedKabupatenProvider);
    final selectedKec = ref.read(selectedKecamatanProvider);
    final selectedDesa = ref.read(selectedDesaProvider);
    final existing = widget.existingData;

    final kabName = selectedKab?.name ?? existing?.districtKab ?? '';
    final kecName = selectedKec?.name ?? existing?.subDistrictKec ?? '';
    final desaName = selectedDesa?.name ?? existing?.villageDesa ?? '';

    if (kabName.trim().isEmpty ||
        kecName.trim().isEmpty ||
        desaName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mohon pilih kabupaten, kecamatan, dan desa.')),
      );
      return;
    }

    final haText = _haCtrl.text.trim();
    final ha =
        haText.isEmpty ? null : double.tryParse(haText.replaceAll(',', '.'));
    if (haText.isNotEmpty && ha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HA harus berupa angka.')),
      );
      return;
    }

    if (!isRestricted && _qaFiCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QA FI wajib diisi untuk SPV/Admin.')),
      );
      return;
    }

    final dataToSave = <String, dynamic>{
      'district_kab': kabName,
      'sub_district_kec': kecName,
      'village_desa': desaName,
      'fa': _faCtrl.text.trim(),
      if (ha != null) 'ha': ha,
    };

    if (isRestricted) {
      dataToSave['qa_fi'] = session?.name ?? existing?.qaFi ?? '';
    } else {
      dataToSave['region'] = _regionCtrl.text.trim();
      dataToSave['qa_spv'] = _qaSpvCtrl.text.trim();
      dataToSave['qa_fi'] = _qaFiCtrl.text.trim();
    }

    setState(() => _saving = true);
    await widget.onSave(dataToSave);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessionAsync = ref.watch(currentSessionProvider);

    final selectedKab = ref.watch(selectedKabupatenProvider);
    final selectedKec = ref.watch(selectedKecamatanProvider);
    final selectedDesa = ref.watch(selectedDesaProvider);

    final kabupatenAsync = ref.watch(kabupatenListProvider);
    final kecamatanAsync = ref.watch(kecamatanListProvider);
    final desaAsync = ref.watch(desaListProvider);

    return sessionAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: AdvantaBanner.error(message: 'Gagal membaca session: $error'),
      ),
      data: (session) {
        final isRestricted = session?.isRestricted ?? false;
        final existing = widget.existingData;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHandle(theme: theme),
                Text(
                  widget.isEdit ? 'Edit Coverage' : 'Tambah Coverage Baru',
                  style: AdvantaText.heading2
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pastikan coverage sesuai wilayah penugasan QA FI.',
                  style: AdvantaText.caption.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(150)
                        : AdvantaColors.mutedGrey,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.isEdit && existing != null) ...[
                  _ReadOnlyField(
                    label: 'Wilayah tersimpan',
                    value:
                        '${_dash(existing.districtKab)} • ${_dash(existing.subDistrictKec)} • ${_dash(existing.villageDesa)}',
                  ),
                  const SizedBox(height: 4),
                ],
                if (isRestricted) ...[
                  _ReadOnlyField(
                      label: 'QA FI',
                      value: session?.name ?? existing?.qaFi ?? '-'),
                  if (widget.isEdit) ...[
                    _ReadOnlyField(label: 'Region', value: _regionCtrl.text),
                    _ReadOnlyField(
                        label: 'QA Supervisor', value: _qaSpvCtrl.text),
                  ],
                  _buildTextField('Field Assistant (FA)', _faCtrl, theme),
                  Divider(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(30)
                        : AdvantaColors.charcoal.withAlpha(20),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _buildTextField('Region', _regionCtrl, theme),
                  _buildTextField('QA Supervisor', _qaSpvCtrl, theme),
                  _buildTextField('QA Field Inspector (FI)', _qaFiCtrl, theme),
                  _buildTextField('Field Assistant (FA)', _faCtrl, theme),
                  Divider(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(30)
                        : AdvantaColors.charcoal.withAlpha(20),
                  ),
                  const SizedBox(height: 12),
                ],
                _CascadeDropdown<WilayahItem>(
                  label: 'Kabupaten / Kota',
                  asyncValue: kabupatenAsync,
                  selected: selectedKab,
                  hint: existing?.districtKab.isNotEmpty == true
                      ? 'Tetap: ${existing!.districtKab}'
                      : 'Pilih Kabupaten',
                  itemLabel: (e) => e.name,
                  onChanged: (val) {
                    ref.read(selectedKabupatenProvider.notifier).select(val);
                    ref.read(selectedKecamatanProvider.notifier).select(null);
                    ref.read(selectedDesaProvider.notifier).select(null);
                  },
                ),
                _CascadeDropdown<WilayahItem>(
                  label: 'Kecamatan',
                  asyncValue: kecamatanAsync,
                  selected: selectedKec,
                  hint: selectedKab == null
                      ? existing?.subDistrictKec.isNotEmpty == true
                          ? 'Tetap: ${existing!.subDistrictKec}'
                          : 'Pilih kabupaten dulu'
                      : 'Pilih Kecamatan',
                  enabled: selectedKab != null,
                  itemLabel: (e) => e.name,
                  onChanged: (val) {
                    ref.read(selectedKecamatanProvider.notifier).select(val);
                    ref.read(selectedDesaProvider.notifier).select(null);
                  },
                ),
                _CascadeDropdown<WilayahItem>(
                  label: 'Desa / Kelurahan',
                  asyncValue: desaAsync,
                  selected: selectedDesa,
                  hint: selectedKec == null
                      ? existing?.villageDesa.isNotEmpty == true
                          ? 'Tetap: ${existing!.villageDesa}'
                          : 'Pilih kecamatan dulu'
                      : 'Pilih Desa',
                  enabled: selectedKec != null,
                  itemLabel: (e) => e.name,
                  onChanged: (val) {
                    ref.read(selectedDesaProvider.notifier).select(val);
                  },
                ),
                _buildTextField('Luas Lahan (ha)', _haCtrl, theme,
                    isNumeric: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _saving ? null : () => _save(isRestricted, session),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.isEdit ? 'SIMPAN PERUBAHAN' : 'TAMBAH DATA'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Widget Helper: Cascade Dropdown
// =============================================================================
class _CascadeDropdown<T> extends StatelessWidget {
  final String label;
  final AsyncValue<List<T>> asyncValue;
  final T? selected;
  final String hint;
  final bool enabled;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _CascadeDropdown({
    required this.label,
    required this.asyncValue,
    required this.selected,
    required this.hint,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: asyncValue.when(
        loading: () => InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: const SizedBox(
            height: 20,
            child: LinearProgressIndicator(),
          ),
        ),
        error: (e, _) => InputDecorator(
          decoration:
              InputDecoration(labelText: label, errorText: 'Gagal memuat data'),
          child: const SizedBox.shrink(),
        ),
        data: (items) => DropdownButtonFormField<T>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          hint: Text(
            hint,
            style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
          ),
          onChanged: enabled ? onChanged : null,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: AdvantaText.body2
                        .copyWith(color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget Helper: Read-only field
// =============================================================================
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark
              ? AdvantaColors.charcoal.withAlpha(60)
              : AdvantaColors.mutedGrey.withAlpha(20),
          suffixIcon: const Icon(Icons.lock_outline, size: 16),
        ),
        child: Text(
          value.isEmpty ? '-' : value,
          style: AdvantaText.body2.copyWith(
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(150)
                : AdvantaColors.mutedGrey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

List<String> _uniqueOptions(Iterable<String> values) {
  final normalized = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return normalized;
}

double _sumHa(List<QaMappingItem> items) {
  var total = 0.0;
  for (final item in items) {
    total += item.ha ?? 0;
  }
  return total;
}

String _formatHa(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();
