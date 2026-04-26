import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/qa_mapping_provider.dart';
import '../../theme/app_theme.dart';

class QaMappingScreen extends ConsumerStatefulWidget {
  const QaMappingScreen({super.key});

  @override
  ConsumerState<QaMappingScreen> createState() => _QaMappingScreenState();
}

class _QaMappingScreenState extends ConsumerState<QaMappingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showForm(BuildContext context, [Map<String, dynamic>? existingData]) {
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
        onSave: (dataToSave) {
          if (isEdit) {
            ref
                .read(qaMappingProvider.notifier)
                .updateMapping(existingData['id'] as int, dataToSave);
          } else {
            ref.read(qaMappingProvider.notifier).addMapping(dataToSave);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        title: Text('Hapus Data?',
            style: AdvantaText.heading2
                .copyWith(color: theme.colorScheme.onSurface)),
        content: Text(
          'Apakah kamu yakin ingin menghapus pemetaan ini?',
          style: AdvantaText.body1.copyWith(
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(180)
                : AdvantaColors.charcoal.withAlpha(180),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: AdvantaText.bodyBold
                    .copyWith(color: AdvantaColors.mutedGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(qaMappingProvider.notifier).deleteMapping(id);
              Navigator.pop(ctx);
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mappingState = ref.watch(qaMappingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Wilayah'),
        elevation: 0,
      ),
      body: mappingState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: AdvantaBanner.error(message: 'Terjadi kesalahan: $err'),
        ),
        data: (mappings) {
          final filteredMappings = mappings.where((item) {
            if (_searchQuery.isEmpty) return true;

            final q = _searchQuery.toLowerCase();
            final kec = (item['sub_district_kec'] ?? '').toString().toLowerCase();
            final desa = (item['village_desa'] ?? '').toString().toLowerCase();
            final kab = (item['district_kab'] ?? '').toString().toLowerCase();
            final fi = (item['qa_fi'] ?? '').toString().toLowerCase();
            final spv = (item['qa_spv'] ?? '').toString().toLowerCase();
            final fa = (item['fa'] ?? '').toString().toLowerCase();
            final region = (item['region'] ?? '').toString().toLowerCase();

            return kec.contains(q) || desa.contains(q) || kab.contains(q) ||
                fi.contains(q) || spv.contains(q) || fa.contains(q) || region.contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Cari desa, kecamatan, FI, SPV...',
                    hintStyle: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
                    prefixIcon: const Icon(Icons.search, color: AdvantaColors.mutedGrey, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: AdvantaColors.mutedGrey, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        FocusScope.of(context).unfocus();
                      },
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              Expanded(
                child: filteredMappings.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          mappings.isEmpty ? Icons.map_outlined : Icons.search_off_rounded,
                          size: 64,
                          color: AdvantaColors.mutedGrey.withAlpha(100)
                      ),
                      const SizedBox(height: 16),
                      Text(
                          mappings.isEmpty ? 'Belum ada data wilayah.' : 'Data tidak ditemukan.',
                          style: AdvantaText.heading3.copyWith(color: theme.colorScheme.onSurface)
                      ),
                      Text(
                        mappings.isEmpty
                            ? 'Silakan tambah pemetaan area kerja Anda.'
                            : 'Coba gunakan kata kunci pencarian lain.',
                        style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: filteredMappings.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemBuilder: (ctx, index) {
                    final item = filteredMappings[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: AdvantaRadius.cardRadius,
                        boxShadow: AdvantaShadows.card(isDark),
                        border: Border.all(
                          color: isDark
                              ? AdvantaColors.goldLight.withAlpha(30)
                              : AdvantaColors.charcoal.withAlpha(12),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kec. ${item['sub_district_kec'] ?? '-'} — ${item['village_desa'] ?? '-'}',
                                style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((item['region'] ?? '').isNotEmpty)
                                _subtitleRow(Icons.public, 'Region', item['region'], theme),
                              _subtitleRow(Icons.location_city, 'Kabupaten', item['district_kab'] ?? '-', theme),
                              if ((item['qa_spv'] ?? '').isNotEmpty)
                                _subtitleRow(Icons.supervisor_account, 'QA SPV', item['qa_spv'], theme),
                              if ((item['qa_fi'] ?? '').isNotEmpty)
                                _subtitleRow(Icons.person_search, 'QA FI', item['qa_fi'], theme),
                              _subtitleRow(Icons.agriculture, 'FA', item['fa'] ?? '-', theme),
                              if (item['ha'] != null)
                                _subtitleRow(Icons.crop_square, 'Luas', '${item['ha']} ha', theme),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                              onPressed: () => _showForm(context, item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AdvantaColors.error),
                              onPressed: () => _confirmDelete(context, item['id'] as int),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _subtitleRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$label: $value',
              style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Form Sheet
// =============================================================================
class _WilayahFormSheet extends ConsumerStatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? existingData;
  final void Function(Map<String, dynamic>) onSave;

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

  @override
  void initState() {
    super.initState();
    _haCtrl = TextEditingController(text: widget.existingData?['ha']?.toString() ?? '');
    _regionCtrl = TextEditingController(text: widget.existingData?['region'] ?? '');
    _qaSpvCtrl = TextEditingController(text: widget.existingData?['qa_spv'] ?? '');
    _qaFiCtrl = TextEditingController(text: widget.existingData?['qa_fi'] ?? '');
    _faCtrl = TextEditingController(text: widget.existingData?['fa'] ?? '');
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
      String label, TextEditingController ctrl, ThemeData theme,
      {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sessionAsync = ref.watch(currentSessionProvider);

    // bool? — null saat loading, true/false saat resolved
    final bool? isRestricted = sessionAsync.when(
      data: (s) => s?.isRestricted ?? false,
      loading: () => null,
      error: (_, __) => false,
    );

    final selectedKab = ref.watch(selectedKabupatenProvider);
    final selectedKec = ref.watch(selectedKecamatanProvider);
    final selectedDesa = ref.watch(selectedDesaProvider);

    final kabupatenAsync = ref.watch(kabupatenListProvider);
    final kecamatanAsync = ref.watch(kecamatanListProvider);
    final desaAsync = ref.watch(desaListProvider);

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
            // Handle bar
            Center(
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
            ),

            Text(
              widget.isEdit ? 'Edit Wilayah' : 'Tambah Wilayah Baru',
              style: AdvantaText.heading2.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Pastikan kelengkapan data sesuai wilayah penugasan.',
              style: AdvantaText.caption.copyWith(
                color: isDark
                    ? AdvantaColors.goldLight.withAlpha(150)
                    : AdvantaColors.mutedGrey,
              ),
            ),
            const SizedBox(height: 20),

            // ── Dynamic Fields berdasarkan Role ──────────────────────────
            if (isRestricted == null) ...[
              // Session masih loading — tampilkan shimmer/indicator
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ] else if (isRestricted == true) ...[
              // QA FI (Restricted)
              if (widget.isEdit) ...[
                _ReadOnlyField(label: 'Region', value: _regionCtrl.text),
                _ReadOnlyField(label: 'QA Supervisor', value: _qaSpvCtrl.text),
                _ReadOnlyField(label: 'QA FI', value: _qaFiCtrl.text),
                _ReadOnlyField(label: 'Field Assistant (FA)', value: _faCtrl.text),
                const SizedBox(height: 8),
                Divider(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(30)
                        : AdvantaColors.charcoal.withAlpha(20)),
                const SizedBox(height: 8),
                Text(
                  'Perbarui Wilayah Utama',
                  style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // Mode ADD untuk FI — hanya perlu isi FA
                _buildTextField('Field Assistant (FA)', _faCtrl, theme),
                const SizedBox(height: 8),
                Divider(
                    color: isDark
                        ? AdvantaColors.goldLight.withAlpha(30)
                        : AdvantaColors.charcoal.withAlpha(20)),
                const SizedBox(height: 12),
              ],
            ] else ...[
              // SPV / Admin / Manager
              _buildTextField('Region', _regionCtrl, theme),
              _buildTextField('QA Supervisor', _qaSpvCtrl, theme),
              _buildTextField('QA Field Inspector (FI)', _qaFiCtrl, theme),
              _buildTextField('Field Assistant (FA)', _faCtrl, theme),
              const SizedBox(height: 8),
              Divider(
                  color: isDark
                      ? AdvantaColors.goldLight.withAlpha(30)
                      : AdvantaColors.charcoal.withAlpha(20)),
              const SizedBox(height: 12),
            ],

            // ── Cascade Wilayah ──────────────────────────────────────────
            _CascadeDropdown<WilayahItem>(
              label: 'Kabupaten / Kota',
              asyncValue: kabupatenAsync,
              selected: selectedKab,
              hint: 'Pilih Kabupaten',
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
              hint: selectedKab == null ? 'Pilih kabupaten dulu' : 'Pilih Kecamatan',
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
              hint: selectedKec == null ? 'Pilih kecamatan dulu' : 'Pilih Desa',
              enabled: selectedKec != null,
              itemLabel: (e) => e.name,
              onChanged: (val) {
                ref.read(selectedDesaProvider.notifier).select(val);
              },
            ),

            _buildTextField('Luas Lahan (ha)', _haCtrl, theme, isNumeric: true),

            const SizedBox(height: 16),

            // ── Tombol Simpan ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRestricted == null
                    ? null // disable saat session masih loading
                    : () {
                  if (selectedKab == null ||
                      selectedKec == null ||
                      selectedDesa == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mohon pilih kabupaten, kecamatan, dan desa.')),
                    );
                    return;
                  }

                  final dataToSave = <String, dynamic>{
                    'district_kab': selectedKab.name,
                    'sub_district_kec': selectedKec.name,
                    'village_desa': selectedDesa.name,
                    if (_haCtrl.text.trim().isNotEmpty)
                      'ha': double.tryParse(_haCtrl.text.trim()),
                  };

                  if (isRestricted == true) {
                    // FI — hanya kirim fa, qa_fi akan di-set oleh addMapping di provider
                    dataToSave['fa'] = _faCtrl.text.trim();
                  } else {
                    // SPV/Admin — kirim semua field
                    dataToSave['region'] = _regionCtrl.text.trim();
                    dataToSave['qa_spv'] = _qaSpvCtrl.text.trim();
                    dataToSave['qa_fi'] = _qaFiCtrl.text.trim();
                    dataToSave['fa'] = _faCtrl.text.trim();
                  }

                  widget.onSave(dataToSave);
                },
                child: Text(widget.isEdit ? 'SIMPAN PERUBAHAN' : 'TAMBAH DATA'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
          decoration: InputDecoration(labelText: label, errorText: 'Gagal memuat data'),
          child: const SizedBox.shrink(),
        ),
        data: (items) => DropdownButtonFormField<T>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          hint: Text(hint,
              style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey)),
          onChanged: enabled ? onChanged : null,
          items: items
              .map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel(item),
              style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ))
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
        ),
      ),
    );
  }
}