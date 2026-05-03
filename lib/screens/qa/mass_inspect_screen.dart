// lib/screens/qa/mass_inspect_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../theme/app_theme.dart';

enum _ViewMode { list, form }
enum _SortBy { fieldNumber, farmerName, hybrid, region }

class MassInspectScreen extends ConsumerStatefulWidget {
  final List<String> fieldNumbers;
  final String targetPhase;

  const MassInspectScreen({
    super.key,
    required this.fieldNumbers,
    required this.targetPhase,
  });

  @override
  ConsumerState<MassInspectScreen> createState() => _MassInspectScreenState();
}

class _MassInspectScreenState extends ConsumerState<MassInspectScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  _ViewMode _viewMode = _ViewMode.list;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortBy _sortBy = _SortBy.fieldNumber;

  final TextEditingController _qaFiController  = TextEditingController();
  final TextEditingController _qaSpvController = TextEditingController();
  DateTime _auditDateUser = DateTime.now();

  String? _commonRecommendation;
  String? _commonCropUniformity;
  String? _commonCropHealth;
  String? _commonMaleRowsChopping;
  String? _commonEarCondition;

  late AnimationController _tabAnimController;

  @override
  void initState() {
    super.initState();
    _tabAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _qaFiController.dispose();
    _qaSpvController.dispose();
    _searchController.dispose();
    _tabAnimController.dispose();
    super.dispose();
  }

  bool get _isDiscard => _commonRecommendation == 'Discard';

  bool get _isFormReady =>
      _qaFiController.text.isNotEmpty &&
          _qaSpvController.text.isNotEmpty &&
          _commonRecommendation != null;

  // ── Helper Resolusi Fase (Pengganti AdvantaPhase) ──
  String _getPhaseLabel(String phase) {
    if (phase.startsWith('generative_')) {
      final cp = phase.split('_');
      return cp.length > 1 ? 'Generatif CP${cp[1]}' : 'Generatif';
    }
    switch (phase) {
      case 'vegetative': return 'Vegetatif';
      case 'pre_harvest': return 'Pre-Harvest';
      case 'harvest': return 'Harvest';
      default: return phase.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getPhaseColor(String phase) {
    if (phase.startsWith('generative_')) return const Color(0xFF7B61FF);
    switch (phase) {
      case 'vegetative': return const Color(0xFF43A047);
      case 'pre_harvest': return const Color(0xFFE65100);
      case 'harvest': return const Color(0xFFD4A017);
      default: return AdvantaColors.mutedGrey;
    }
  }
  // ───────────────────────────────────────────────────

  void _switchView(_ViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    if (mode == _ViewMode.form) {
      _tabAnimController.forward();
    } else {
      _tabAnimController.reverse();
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDark) async {
    final picked = await showDatePicker(
      context    : context,
      initialDate: _auditDateUser,
      firstDate  : DateTime(2000),
      lastDate   : DateTime.now(),
      builder    : (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(primary: AdvantaColors.primaryGreen, onPrimary: Colors.white, surface: AdvantaColors.deepForest)
              : const ColorScheme.light(primary: AdvantaColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _auditDateUser) {
      setState(() => _auditDateUser = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterFieldsAsync = ref.watch(masterFieldsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(isDark),
      body: masterFieldsAsync.when(
        data: (allFields) {
          final selectedFields = allFields
              .where((f) => widget.fieldNumbers.contains(f['field_number']))
              .toList();

          return Column(
            children: [
              _buildHeaderStrip(selectedFields.length, isDark),
              _buildViewToggle(isDark),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _viewMode == _ViewMode.list
                      ? _buildListView(selectedFields, theme, isDark)
                      : _buildFormView(selectedFields, theme, isDark),
                ),
              ),
              _buildBottomBar(selectedFields, theme, isDark),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdvantaColors.primaryGreen),
        ),
        error: (err, _) => Center(
          child: _EmptyState(
            title   : 'Gagal Memuat Data',
            subtitle: err.toString(),
            icon    : Icons.cloud_off_rounded,
            isDark  : isDark,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen,
      elevation      : 0,
      leading: IconButton(
        icon    : const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize      : MainAxisSize.min,
        children          : [
          Text('Mass Inspeksi', style: AdvantaText.brandTitle.copyWith(color: Colors.white)),
          Text(_getPhaseLabel(widget.targetPhase), style: AdvantaText.brandSubtitle),
        ],
      ),
      actions: [
        if (_isFormReady)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child  : Container(
              padding   : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color       : AdvantaColors.gold.withAlpha(40),
                borderRadius: AdvantaRadius.chipRadius,
                border      : Border.all(color: AdvantaColors.gold.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  const Icon(Icons.check_rounded, size: 12, color: AdvantaColors.goldLight),
                  const SizedBox(width: 4),
                  Text('Siap Submit', style: AdvantaText.caption.copyWith(color: AdvantaColors.goldLight)),
                ],
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderStrip(int count, bool isDark) {
    return Container(
      padding : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color   : isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen,
      child   : Row(
        children: [
          Container(
            padding  : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color       : Colors.white.withAlpha(20),
              borderRadius: AdvantaRadius.chipRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children    : [
                const Icon(Icons.layers_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text('$count Field', style: AdvantaText.label.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PhaseBadge(phase: widget.targetPhase, label: _getPhaseLabel(widget.targetPhase), color: _getPhaseColor(widget.targetPhase)),
          const Spacer(),
          if (_commonRecommendation != null)
            _StatusBadge(status: _commonRecommendation),
        ],
      ),
    );
  }

  Widget _buildViewToggle(bool isDark) {
    return Container(
      color  : isDark ? AdvantaColors.deepForest : AdvantaColors.primaryGreen,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
      child: Container(
        height    : 40,
        decoration: BoxDecoration(
          color       : Colors.black.withAlpha(50),
          borderRadius: AdvantaRadius.chipRadius,
        ),
        child: Row(
          children: [
            _buildToggleTab(label: 'Daftar Field',  icon: Icons.format_list_bulleted_rounded, mode: _ViewMode.list, isActive: _viewMode == _ViewMode.list, isDark: isDark),
            _buildToggleTab(label: 'Isi Formulir',  icon: Icons.assignment_outlined, mode: _ViewMode.form, isActive: _viewMode == _ViewMode.form, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTab({
    required String label, required IconData icon,
    required _ViewMode mode, required bool isActive, required bool isDark
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchView(mode),
        child: AnimatedContainer(
          duration  : const Duration(milliseconds: 220),
          curve     : Curves.easeOutCubic,
          margin    : const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color       : isActive ? (isDark ? AdvantaColors.midGreen : Colors.white) : Colors.transparent,
            borderRadius: AdvantaRadius.chipRadius,
            boxShadow   : isActive ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0,2))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children         : [
              Icon(icon, size: 15, color: isActive ? (isDark ? Colors.white : AdvantaColors.primaryGreen) : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: AdvantaText.label.copyWith(
                  color     : isActive ? (isDark ? Colors.white : AdvantaColors.primaryGreen) : Colors.white70,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIST VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildListView(List<Map<String, dynamic>> selectedFields, ThemeData theme, bool isDark) {
    var displayed = selectedFields.where((f) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (f['field_number']?.toString().toLowerCase().contains(q) ?? false) ||
          (f['farmer_name']?.toString().toLowerCase().contains(q) ?? false) ||
          (f['hybrid']?.toString().toLowerCase().contains(q) ?? false) ||
          (f['region']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    displayed.sort((a, b) {
      switch (_sortBy) {
        case _SortBy.farmerName: return (a['farmer_name'] ?? '').toString().compareTo((b['farmer_name'] ?? '').toString());
        case _SortBy.hybrid:     return (a['hybrid'] ?? '').toString().compareTo((b['hybrid'] ?? '').toString());
        case _SortBy.region:     return (a['region'] ?? '').toString().compareTo((b['region'] ?? '').toString());
        case _SortBy.fieldNumber:return (a['field_number'] ?? '').toString().compareTo((b['field_number'] ?? '').toString());
      }
    });

    return Column(
      children: [
        _buildListToolbar(selectedFields.length, displayed.length, theme, isDark),
        if (!_isFormReady) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child  : _BannerInfo(
              message: 'Lengkapi tab "Isi Formulir" sebelum submit.',
              icon   : Icons.edit_note_rounded,
              isDark : isDark,
            ),
          ),
        ],
        Expanded(
          child: displayed.isEmpty
              ? _EmptyState(
            title   : 'Tidak Ada Hasil',
            subtitle: 'Coba ubah kata kunci pencarian.',
            icon    : Icons.search_off_rounded,
            isDark  : isDark,
          )
              : ListView.builder(
            padding    : const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount  : displayed.length,
            itemBuilder: (ctx, i) => _buildFieldListCard(displayed[i], theme, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildListToolbar(int total, int filtered, ThemeData theme, bool isDark) {
    return Container(
      color  : theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child  : Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged : (v) => setState(() => _searchQuery = v),
            style     : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText     : 'Cari field, petani, hybrid, region...',
              hintStyle    : AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
              prefixIcon   : const Icon(Icons.search_rounded, size: 20, color: AdvantaColors.mutedGrey),
              suffixIcon   : _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
              )
                  : null,
              filled       : true,
              fillColor    : isDark ? AdvantaColors.deepForest.withAlpha(150) : AdvantaColors.softGrey,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border       : OutlineInputBorder(borderRadius: AdvantaRadius.chipRadius, borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: AdvantaRadius.chipRadius, borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
              focusedBorder: OutlineInputBorder(borderRadius: AdvantaRadius.chipRadius, borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _searchQuery.isNotEmpty ? 'Menampilkan $filtered dari $total field' : '$total field dipilih',
                style: AdvantaText.caption,
              ),
              const Spacer(),
              const Icon(Icons.sort_rounded, size: 14, color: AdvantaColors.mutedGrey),
              const SizedBox(width: 6),
              DropdownButton<_SortBy>(
                value    : _sortBy,
                underline: const SizedBox(),
                isDense  : true,
                style    : AdvantaText.caption.copyWith(color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen),
                icon     : Icon(Icons.expand_more_rounded, size: 16, color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen),
                dropdownColor: theme.colorScheme.surface,
                borderRadius: AdvantaRadius.cardRadius,
                items    : const [
                  DropdownMenuItem(value: _SortBy.fieldNumber, child: Text('No. Field')),
                  DropdownMenuItem(value: _SortBy.farmerName,  child: Text('Nama Petani')),
                  DropdownMenuItem(value: _SortBy.hybrid,      child: Text('Hybrid')),
                  DropdownMenuItem(value: _SortBy.region,      child: Text('Region')),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? _SortBy.fieldNumber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldListCard(Map<String, dynamic> field, ThemeData theme, bool isDark) {
    final fieldNo    = field['field_number']?.toString() ?? '-';
    final farmerName = field['farmer_name']?.toString() ?? '-';
    final hybrid     = field['hybrid']?.toString() ?? '-';
    final region     = field['region']?.toString();
    final district   = field['kabupaten']?.toString() ?? field['district']?.toString();
    final area       = field['area_ha']?.toString() ?? field['luas_ha']?.toString();
    final lastRec    = field['recommendation']?.toString() ?? field['action_needed']?.toString();
    final dap        = field['dap']?.toString() ?? field['day_after_planting']?.toString();
    final season     = field['season']?.toString() ?? field['musim']?.toString();

    final phaseColor = _getPhaseColor(widget.targetPhase);

    return Container(
      margin     : const EdgeInsets.only(bottom: 10),
      decoration : BoxDecoration(
        color       : theme.colorScheme.surface,
        borderRadius: AdvantaRadius.cardRadius,
        border      : Border.all(color: isDark ? AdvantaColors.goldLight.withAlpha(30) : Colors.black.withAlpha(12)),
        boxShadow   : AdvantaShadows.card(isDark),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width     : 5,
              decoration: BoxDecoration(
                color       : phaseColor,
                borderRadius: const BorderRadius.only(
                  topLeft   : Radius.circular(12.0),
                  bottomLeft: Radius.circular(12.0),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children          : [
                    Row(
                      children: [
                        Container(
                          padding  : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: isDark ? AdvantaColors.midGreen : AdvantaColors.deepForest, borderRadius: AdvantaRadius.chipRadius),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children    : [
                              const Icon(Icons.tag_rounded, size: 11, color: AdvantaColors.goldLight),
                              const SizedBox(width: 4),
                              Text(fieldNo, style: AdvantaText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PhaseBadge(phase: widget.targetPhase, label: _getPhaseLabel(widget.targetPhase), color: phaseColor, small: true),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _removeField(fieldNo, theme, isDark),
                          child: Container(
                            width     : 28,
                            height    : 28,
                            decoration: BoxDecoration(color: isDark ? AdvantaColors.error.withAlpha(40) : AdvantaColors.errorLight, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded, size: 16, color: AdvantaColors.error),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 14, color: AdvantaColors.mutedGrey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(farmerName, style: AdvantaText.bodyBold.copyWith(color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.science_outlined, size: 13, color: AdvantaColors.mutedGrey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(hybrid, style: AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing   : 6,
                      runSpacing: 6,
                      children  : [
                        if (region != null)   _buildMetaChip(Icons.map_outlined, region, isDark),
                        if (district != null) _buildMetaChip(Icons.location_city_outlined, district, isDark),
                        if (area != null)     _buildMetaChip(Icons.straighten_rounded, '$area ha', isDark),
                        if (dap != null)      _buildMetaChip(Icons.calendar_month_outlined, 'DAP $dap', isDark),
                        if (season != null)   _buildMetaChip(Icons.wb_sunny_outlined, season, isDark),
                      ],
                    ),
                    if (lastRec != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('Inspeksi terakhir: ', style: AdvantaText.caption),
                        _StatusBadge(status: lastRec, small: true),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, bool isDark) {
    return Container(
      padding  : const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color       : isDark ? Colors.white10 : AdvantaColors.softGrey,
        borderRadius: AdvantaRadius.chipRadius,
        border      : Border.all(color: isDark ? Colors.white24 : AdvantaColors.dividerGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children    : [
          Icon(icon, size: 11, color: AdvantaColors.mutedGrey),
          const SizedBox(width: 4),
          Text(label, style: AdvantaText.caption),
        ],
      ),
    );
  }

  void _removeField(String fieldNo, ThemeData theme, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape          : const RoundedRectangleBorder(borderRadius: AdvantaRadius.dialogRadius),
        backgroundColor: theme.colorScheme.surface,
        title          : Text('Hapus dari Daftar?', style: AdvantaText.heading3.copyWith(color: theme.colorScheme.onSurface)),
        content        : Text('Field #$fieldNo akan dikeluarkan dari batch inspeksi ini.', style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface)),
        actions        : [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child    : Text('Batal', style: AdvantaText.label.copyWith(color: AdvantaColors.mutedGrey)),
          ),
          ElevatedButton(
            onPressed: () { setState(() => widget.fieldNumbers.remove(fieldNo)); Navigator.pop(ctx); },
            style    : ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.error,
              foregroundColor: Colors.white,
              elevation      : 0,
              shape          : const RoundedRectangleBorder(borderRadius: AdvantaRadius.buttonRadius),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORM VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  InputDecoration _inputDeco(String label, IconData icon, bool isReq, bool isDark, ThemeData theme) {
    return InputDecoration(
      labelText: isReq ? '$label *' : label,
      prefixIcon: Icon(icon, color: isDark ? AdvantaColors.goldLight : AdvantaColors.midGreen, size: 20),
      filled: true,
      fillColor: isDark ? AdvantaColors.deepForest.withAlpha(150) : AdvantaColors.softGrey,
      labelStyle: AdvantaText.body2.copyWith(color: isDark ? AdvantaColors.goldLight.withAlpha(180) : AdvantaColors.mutedGrey),
      border: OutlineInputBorder(borderRadius: AdvantaRadius.inputRadius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: AdvantaRadius.inputRadius,
        borderSide: BorderSide(color: isDark ? AdvantaColors.goldLight.withAlpha(50) : AdvantaColors.charcoal.withAlpha(18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AdvantaRadius.inputRadius,
        borderSide: BorderSide(color: isDark ? AdvantaColors.goldLight : theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildFormView(List<Map<String, dynamic>> selectedFields, ThemeData theme, bool isDark) {
    return Form(
      key : _formKey,
      child: ListView(
        padding : const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _SectionHeader(label: 'DATA UMUM', isDark: isDark),
          const SizedBox(height: 12),

          InkWell(
            onTap       : () => _selectDate(context, isDark),
            borderRadius: AdvantaRadius.inputRadius,
            child       : InputDecorator(
              decoration: _inputDeco('Tanggal Audit (Semua Field)', Icons.calendar_today_outlined, true, isDark, theme),
              child: Row(children: [
                Expanded(child: Text(DateFormat('dd MMMM yyyy').format(_auditDateUser), style: AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface))),
                const Icon(Icons.edit_calendar_outlined, size: 16, color: AdvantaColors.mutedGrey),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _qaFiController,
            style     : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            decoration: _inputDeco('QA FI (Semua Field)', Icons.person_outline_rounded, true, isDark, theme),
            onChanged : (_) => setState(() {}),
            validator : (v) => v!.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _qaSpvController,
            style     : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            decoration: _inputDeco('QA SPV (Semua Field)', Icons.supervisor_account_outlined, true, isDark, theme),
            onChanged : (_) => setState(() {}),
            validator : (v) => v!.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: _commonRecommendation,
            style       : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            dropdownColor: theme.colorScheme.surface,
            decoration  : _inputDeco('Recommendation (Semua Field)', Icons.recommend_outlined, true, isDark, theme),
            items: ['Continue', 'Discard'].map((e) => DropdownMenuItem(
              value: e,
              child: Row(children: [
                Icon(_getStatusIcon(e), size: 16, color: _getStatusColor(e)),
                const SizedBox(width: 8),
                Text(e),
              ]),
            )).toList(),
            onChanged: (val) => setState(() => _commonRecommendation = val),
            validator: (v) => v == null ? 'Wajib diisi' : null,
          ),

          if (_isDiscard) ...[
            const SizedBox(height: 12),
            _BannerWarning(message: 'Mode "Discard": Field Assessment di bawah menjadi opsional.', isDark: isDark),
          ],

          const SizedBox(height: 24),
          _SectionHeader(label: 'ASSESSMENT MASSAL', isDark: isDark),
          const SizedBox(height: 14),

          if (widget.targetPhase == 'pre_harvest') ...[
            DropdownButtonFormField<String>(
              initialValue: _commonMaleRowsChopping,
              style       : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
              dropdownColor: theme.colorScheme.surface,
              decoration  : _inputDeco('Male Rows Chopping', Icons.cut_rounded, !_isDiscard, isDark, theme),
              items: const [
                DropdownMenuItem(value: 'A', child: Text('A = Complete')),
                DropdownMenuItem(value: 'B', child: Text('B = Not Complete')),
              ],
              onChanged: (val) => setState(() => _commonMaleRowsChopping = val),
              validator: (v) => (!_isDiscard && v == null) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),
          ],

          if (widget.targetPhase == 'harvest') ...[
            DropdownButtonFormField<String>(
              initialValue: _commonEarCondition,
              style       : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
              dropdownColor: theme.colorScheme.surface,
              decoration  : _inputDeco('Ear Condition Observation', Icons.grain_rounded, !_isDiscard, isDark, theme),
              items: ['2', '3', '4'].map((e) => DropdownMenuItem(value: e, child: Text('Stage $e'))).toList(),
              onChanged: (val) => setState(() => _commonEarCondition = val),
              validator: (v) => (!_isDiscard && v == null) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),
          ],

          DropdownButtonFormField<String>(
            initialValue: _commonCropUniformity,
            style       : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            dropdownColor: theme.colorScheme.surface,
            decoration  : _inputDeco('Crop Uniformity', Icons.view_module_outlined, !_isDiscard, isDark, theme),
            items: List.generate(5, (i) => '${i + 1}').map((e) => DropdownMenuItem(value: e, child: Text('Score $e'))).toList(),
            onChanged: (val) => setState(() => _commonCropUniformity = val),
            validator: (v) => (!_isDiscard && v == null) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: _commonCropHealth,
            style       : AdvantaText.body2.copyWith(color: theme.colorScheme.onSurface),
            dropdownColor: theme.colorScheme.surface,
            decoration  : _inputDeco('Crop Health', Icons.health_and_safety_outlined, !_isDiscard, isDark, theme),
            items: List.generate(5, (i) => '${i + 1}').map((e) => DropdownMenuItem(value: e, child: Text('Score $e'))).toList(),
            onChanged: (val) => setState(() => _commonCropHealth = val),
            validator: (v) => (!_isDiscard && v == null) ? 'Wajib diisi' : null,
          ),

          const SizedBox(height: 24),
          _SectionHeader(label: 'RANGKUMAN FIELD', isDark: isDark),
          const SizedBox(height: 10),

          Wrap(
            spacing  : 8,
            runSpacing: 8,
            children : widget.fieldNumbers.map((fn) => Container(
              padding  : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color       : isDark ? AdvantaColors.midGreen.withAlpha(50) : AdvantaColors.paleGreen,
                borderRadius: AdvantaRadius.chipRadius,
                border      : Border.all(color: isDark ? AdvantaColors.primaryGreen : AdvantaColors.lightGreen.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  Icon(Icons.tag_rounded, size: 12, color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen),
                  const SizedBox(width: 4),
                  Text(fn, style: AdvantaText.label.copyWith(color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => widget.fieldNumbers.remove(fn)),
                    child: Icon(Icons.close_rounded, size: 14, color: isDark ? AdvantaColors.goldLight : AdvantaColors.midGreen),
                  ),
                ],
              ),
            )).toList(),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBottomBar(List<Map<String, dynamic>> selectedFields, ThemeData theme, bool isDark) {
    final canSubmit = widget.fieldNumbers.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [BoxShadow(color: isDark ? Colors.black54 : Colors.black12, blurRadius: 10, offset: const Offset(0, -4))]
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AdvantaColors.primaryGreen))
          : Row(
        children: [
          Container(
            padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color       : isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey,
              borderRadius: AdvantaRadius.buttonRadius,
              border      : Border.all(color: isDark ? AdvantaColors.goldLight.withAlpha(50) : AdvantaColors.dividerGrey),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children    : [
                Text('${widget.fieldNumbers.length}', style: AdvantaText.heading2.copyWith(color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen)),
                Text('Field', style: AdvantaText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canSubmit && _isFormReady ? () => _submitBulkInternal(selectedFields) : null,
              icon : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                canSubmit && !_isFormReady ? 'Lengkapi Formulir Dulu' : 'SUBMIT ${widget.fieldNumbers.length} FIELD',
                style: AdvantaText.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor        : AdvantaColors.primaryGreen,
                foregroundColor        : Colors.white,
                disabledBackgroundColor: isDark ? Colors.white10 : AdvantaColors.dividerGrey,
                disabledForegroundColor: AdvantaColors.mutedGrey,
                elevation              : 0,
                minimumSize            : const Size(double.infinity, 54),
                shape                  : const RoundedRectangleBorder(borderRadius: AdvantaRadius.buttonRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBulkInternal(List<Map<String, dynamic>> selectedFields) async {
    if (!_formKey.currentState!.validate()) {
      _switchView(_ViewMode.form);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final records = <Map<String, dynamic>>[];
      final dateStr = DateFormat('yyyy-MM-dd').format(_auditDateUser);
      final week    = ((_auditDateUser.day - 1) / 7).floor() + 1;

      for (final field in selectedFields) {
        final record = <String, dynamic>{
          'field_number'  : field['field_number'],
          'is_mass_submit': true,
        };

        if (widget.targetPhase.startsWith('generative_')) {
          final checkpoint = int.parse(widget.targetPhase.split('_')[1]);
          record['audit_date_$checkpoint']      = DateFormat('yyyy-MM-dd').format(DateTime.now());
          record['date_of_audit_$checkpoint']   = dateStr;
          record['audit_week_$checkpoint']      = week;
          record['qa_fi_$checkpoint']           = _qaFiController.text;
          record['qa_spv']                      = _qaSpvController.text;
          record['action_needed_$checkpoint']   = _commonRecommendation == 'Discard' ? 'Discard' : 'None';
          record['crop_uniformity_$checkpoint'] = _commonCropUniformity;
          record['crop_health_$checkpoint']     = _commonCropHealth;
          record['is_mass_submit_$checkpoint']  = true;
        } else {
          record['audit_date']      = DateFormat('yyyy-MM-dd').format(DateTime.now());
          record['audit_date_user'] = dateStr;
          record['audit_week']      = week;
          record['qa_fi']           = _qaFiController.text;
          record['qa_spv']          = _qaSpvController.text;
          record['recommendation']  = _commonRecommendation;
          record['crop_uniformity'] = _commonCropUniformity;
          record['crop_health']     = _commonCropHealth;
          record['is_mass_submit']  = true;

          if (widget.targetPhase == 'pre_harvest') {
            record['male_rows_chopping'] = _commonMaleRowsChopping;
          } else if (widget.targetPhase == 'harvest') {
            record['ear_condition'] = _commonEarCondition;
          }
        }

        records.add(record);
      }

      final service = ref.read(supabaseServiceProvider);
      await service.bulkUpsertInspection(phase: widget.targetPhase, records: records);

      final attendance = ref.read(attendanceProvider);
      if (attendance.isCheckedIn && attendance.attendanceId != null) {
        double lat = 0.0, lng = 0.0;
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (e) {
          debugPrint('Gagal mendapat lokasi untuk bulk logActivity: $e');
        }

        for (final field in selectedFields) {
          await service.logActivity(
            attendanceId: attendance.attendanceId!,
            userId      : _qaFiController.text,
            fieldNumber : field['field_number'],
            phase       : widget.targetPhase,
            actionType  : 'mass_submit',
            lat         : lat,
            lng         : lng,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('${records.length} field berhasil di-submit!'),
            ]),
            backgroundColor: AdvantaColors.success,
          ),
        );
        ref.invalidate(masterFieldsProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Gagal submit: $e')),
            ]),
            backgroundColor: AdvantaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helper Warna Status Khusus Mass Inspect ──
  Color _getStatusColor(String? status) {
    if (status == 'Continue') return AdvantaColors.success;
    if (status == 'Discard') return AdvantaColors.error;
    return AdvantaColors.mutedGrey;
  }

  IconData _getStatusIcon(String? status) {
    if (status == 'Continue') return Icons.check_circle_outline_rounded;
    if (status == 'Discard') return Icons.cancel_outlined;
    return Icons.radio_button_unchecked_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL REUSABLE WIDGETS
// (Menghindari ketergantungan file eksternal yang sudah dihapus konfigurasinya)
// ─────────────────────────────────────────────────────────────────────────────

class _PhaseBadge extends StatelessWidget {
  final String phase;
  final String label;
  final Color color;
  final bool small;

  const _PhaseBadge({required this.phase, required this.label, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding  : small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color       : color.withAlpha(22),
        borderRadius: AdvantaRadius.chipRadius,
        border      : Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children    : [
          Icon(Icons.spa_rounded, size: small ? 11 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: (small ? AdvantaText.caption : AdvantaText.label).copyWith(
              color     : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  final bool small;

  const _StatusBadge({this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isContinue = status == 'Continue';
    final color = isContinue ? AdvantaColors.success : AdvantaColors.error;
    final bgColor = isContinue ? AdvantaColors.successLight : AdvantaColors.errorLight;
    final icon = isContinue ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;

    return Container(
      padding  : small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color       : bgColor,
        borderRadius: AdvantaRadius.chipRadius,
        border      : Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children    : [
          Icon(icon, size: small ? 11 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            status ?? '-',
            style: (small ? AdvantaText.caption : AdvantaText.label).copyWith(
              color     : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerInfo extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool isDark;

  const _BannerInfo({required this.message, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color       : isDark ? AdvantaColors.midGreen.withAlpha(60) : AdvantaColors.paleGreen,
        borderRadius: AdvantaRadius.cardRadius,
        border      : Border.all(color: isDark ? AdvantaColors.goldLight.withAlpha(60) : AdvantaColors.primaryGreen.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AdvantaText.body2.copyWith(color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerWarning extends StatelessWidget {
  final String message;
  final bool isDark;

  const _BannerWarning({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color       : isDark ? AdvantaColors.gold.withAlpha(40) : const Color(0xFFFFF8E1),
        borderRadius: AdvantaRadius.cardRadius,
        border      : Border.all(color: AdvantaColors.gold.withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AdvantaColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AdvantaText.body2.copyWith(color: isDark ? AdvantaColors.goldLight : AdvantaColors.gold, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;

  const _EmptyState({required this.title, required this.subtitle, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child  : Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Container(
              width     : 72,
              height    : 72,
              decoration: BoxDecoration(
                color       : isDark ? Colors.white10 : AdvantaColors.paleGreen,
                shape       : BoxShape.circle,
              ),
              child: Icon(icon, size : 36, color: isDark ? AdvantaColors.goldLight : AdvantaColors.lightGreen),
            ),
            const SizedBox(height: 20),
            Text(title, style: AdvantaText.heading3.copyWith(color: isDark ? Colors.white : AdvantaColors.charcoal), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style    : AdvantaText.body2.copyWith(color: AdvantaColors.mutedGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: isDark ? AdvantaColors.goldLight : AdvantaColors.primaryGreen,
          margin: const EdgeInsets.only(right: 8),
        ),
        Text(label, style: AdvantaText.label.copyWith(letterSpacing: 1.5, color: isDark ? AdvantaColors.goldLight : AdvantaColors.mutedGrey)),
      ],
    );
  }
}
