// lib/widgets/field_detail_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/master_fields_provider.dart';
import '../services/phase_iso_export_service.dart';
import '../theme/app_theme.dart';
import '../utils/dap_helper.dart';
import '../utils/audit_status_helper.dart';
import '../utils/pld_visibility_helper.dart';
import 'phase_asset_icon.dart';

class FieldDetailBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> field;
  final void Function(Map<String, dynamic>)? onInspectDone;
  final DateTime? dapReferenceDate;
  static bool _isShowing = false;

  const FieldDetailBottomSheet({
    super.key,
    required this.field,
    this.onInspectDone,
    this.dapReferenceDate,
  });

  static void show(
    BuildContext context,
    Map<String, dynamic> field, {
    void Function(Map<String, dynamic>)? onInspectDone,
    DateTime? dapReferenceDate,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible:
          true, // KUNCI: Memastikan klik di luar (area transparan) menutup sheet
      enableDrag:
          true, // KUNCI: Memastikan sheet bisa di-swipe ke bawah untuk tutup
      builder: (_) => FieldDetailBottomSheet(
        field: field,
        onInspectDone: onInspectDone,
        dapReferenceDate: dapReferenceDate,
      ),
    ).whenComplete(() => _isShowing = false);
  }

  @override
  ConsumerState<FieldDetailBottomSheet> createState() =>
      _FieldDetailBottomSheetState();
}

class _FieldDetailBottomSheetState
    extends ConsumerState<FieldDetailBottomSheet> {
  int _tab = 0; // 0: Info, 1: Histori, 2: Aksi
  bool _isExportingPhaseIso = false;

  // 1. TAMBAHKAN VARIABEL STATE INI
  late int _dap;
  late String _recommendedPhase;
  late String? _finalPlantingDate; // Menyimpan tanggal yang fix dipakai
  late DateTime _dapReferenceDate;
  late bool
      _isPlantingDateRevisied; // Penanda untuk UI (Warna emas jika revisi)

  // ── Penentu Tipe Crop berdasarkan Hybrid ────────────────────
  bool get _isSweetCorn {
    final hybrid =
        widget.field['hybrid']?.toString().toUpperCase().trim() ?? '';
    // SC (Sweet Corn) strictly: AX01, AX02, AX03, AX04
    return ['AX01', 'AX02', 'AX03', 'AX04'].contains(hybrid);
  }

  bool get _isPSP {
    final hybrid =
        widget.field['hybrid']?.toString().toUpperCase().trim() ?? '';
    // PSP (Next): ASF**
    return hybrid.startsWith('ASF');
  }

  // 2. TAMBAHKAN INIT STATE INI
  @override
  void initState() {
    super.initState();

    final revDate = DapHelper.getRevisedPlantingDate(widget.field);
    _finalPlantingDate = DapHelper.getEffectivePlantingDate(widget.field);
    _isPlantingDateRevisied = revDate != null;
    final referenceDate = widget.dapReferenceDate ?? DateTime.now();
    _dapReferenceDate = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    // 3. Hitung DAP dan Rekomendasi Fase
    _dap = DapHelper.calculateDAP(
      _finalPlantingDate,
      referenceDate: _dapReferenceDate,
    );
    _recommendedPhase = DapHelper.getRecommendedPhase(_dap,
        hybrid: widget.field['hybrid']?.toString());
  }

  // ── Phase data dinamis menyesuaikan tipe crop ──────────────────
  List<String> get _phaseKeys {
    if (_isSweetCorn) {
      return [
        'vegetative',
        'generative_1',
        'generative_2',
        'generative_3',
        'generative_4',
        'generative_5',
        'pre_harvest',
        'harvest'
      ];
    }
    if (_isPSP) {
      return ['vegetative', 'generative_5', 'harvest'];
    }
    // Default / Field Corn (FC)
    return [
      'vegetative',
      'generative_1',
      'generative_2',
      'generative_3',
      'pre_harvest',
      'harvest'
    ];
  }

  List<String> get _phaseLabels {
    if (_isSweetCorn) {
      return [
        'Vegetatif',
        'Generatif CP1',
        'Generatif CP2',
        'Generatif CP3',
        'Generatif CP4',
        'Generatif CP5',
        'Pre-Harvest',
        'Harvest'
      ];
    }
    if (_isPSP) {
      return ['Vegetatif (PSP)', 'Generatif (PSP)', 'Harvest'];
    }
    return [
      'Vegetatif',
      'Generatif CP1',
      'Generatif CP2',
      'Generatif CP3',
      'Pre-Harvest',
      'Harvest'
    ];
  }

  List<IconData> get _phaseIcons {
    if (_isSweetCorn) {
      return [
        Icons.grass_rounded,
        Icons.spa_rounded,
        Icons.spa_rounded,
        Icons.spa_rounded,
        Icons.spa_rounded,
        Icons.spa_rounded,
        Icons.content_cut_rounded,
        Icons.agriculture_rounded
      ];
    }
    if (_isPSP) {
      return [
        Icons.grass_rounded,
        Icons.spa_rounded,
        Icons.agriculture_rounded,
      ];
    }
    return [
      Icons.grass_rounded,
      Icons.spa_rounded,
      Icons.spa_rounded,
      Icons.spa_rounded,
      Icons.content_cut_rounded,
      Icons.agriculture_rounded
    ];
  }

  List<Color> get _phaseColors {
    if (_isSweetCorn) {
      return [
        const Color(0xFF43A047),
        const Color(0xFF7B61FF),
        const Color(0xFF7B61FF),
        const Color(0xFF7B61FF),
        const Color(0xFF7B61FF),
        const Color(0xFF7B61FF),
        const Color(0xFFE65100),
        const Color(0xFFD4A017)
      ];
    }
    if (_isPSP) {
      return [
        const Color(0xFF43A047),
        const Color(0xFFE53935),
        const Color(0xFFD4A017),
      ];
    }
    return [
      const Color(0xFF43A047),
      const Color(0xFF7B61FF),
      const Color(0xFF7B61FF),
      const Color(0xFF7B61FF),
      const Color(0xFFE65100),
      const Color(0xFFD4A017)
    ];
  }

  String _getPhaseLabel(String key) {
    final index = _phaseKeys.indexOf(key);
    return index != -1 ? _phaseLabels[index] : key;
  }

  // ── Helpers ───────────────────────────────────────────────
  Map<String, dynamic>? _auditMap(String key) {
    final v = widget.field[key];
    if (v == null) return null;
    if (v is List && v.isNotEmpty) return v[0] as Map<String, dynamic>;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  String _fmt(dynamic v, {String fallback = '—'}) =>
      (v == null || v.toString().trim().isEmpty) ? fallback : v.toString();

  bool _isExplicitPldValue(dynamic value) {
    return PldVisibilityHelper.isExplicitPld(value);
  }

  bool _isVegetativePldDecision(dynamic value) {
    return PldVisibilityHelper.isDecisionPld(value);
  }

  bool _isVegetativePldAction(dynamic value) {
    return PldVisibilityHelper.isVegetativeActionPldFull(value);
  }

  bool _isPldFlagging(dynamic value) => _isExplicitPldValue(value);

  bool _isVegetativePldAudit(Map<String, dynamic>? audit) {
    if (audit == null) return false;
    return _isVegetativePldDecision(audit['decision']) ||
        _isVegetativePldDecision(audit['final_decision']) ||
        _isVegetativePldAction(audit['action_needed']) ||
        _isPldFlagging(audit['flagging']);
  }

  bool _isGenerativePldAudit(Map<String, dynamic>? audit, int checkpoint) {
    if (audit == null) return false;
    return _isVegetativePldDecision(audit['final_decision_$checkpoint']) ||
        PldVisibilityHelper.isPldOrDiscardFull(
          audit['action_needed_$checkpoint'],
        ) ||
        _isPldFlagging(audit['final_flagging_$checkpoint']) ||
        _isPldFlagging(audit['flagging_$checkpoint']);
  }

  bool _isPreHarvestPldAudit(Map<String, dynamic>? audit) {
    if (audit == null) return false;
    return _isVegetativePldDecision(audit['final_decision']) ||
        _isPldFlagging(audit['flagging']) ||
        _isPldFlagging(audit['final_flagging']);
  }

  bool _isHarvestPldAudit(Map<String, dynamic>? audit) {
    if (audit == null) return false;
    return _isVegetativePldDecision(audit['final_decision']) ||
        _isPldFlagging(audit['final_flagging']) ||
        _isPldFlagging(audit['downgrade_flagging']);
  }

  bool _isMasterPldFlag(Map<String, dynamic> field) {
    return _isPldFlagging(field['flagging_final']) ||
        _isExplicitPldValue(field['final_decision']);
  }

  List<String> _pldAuditPhases() {
    final hits = <String>[];

    void addIfPld(String phase, bool isPld) {
      if (hits.contains(phase)) return;
      if (isPld) hits.add(phase);
    }

    final veg = _auditMap('audit_vegetative');
    addIfPld('Vegetatif', _isVegetativePldAudit(veg));

    final gen = _auditMap('audit_generative');
    for (var i = 1; i <= 5; i++) {
      addIfPld('Generatif CP$i', _isGenerativePldAudit(gen, i));
    }

    final preHarvest = _auditMap('audit_pre_harvest');
    addIfPld('Pre-Harvest', _isPreHarvestPldAudit(preHarvest));

    final harvest = _auditMap('audit_harvest');
    addIfPld('Harvest', _isHarvestPldAudit(harvest));

    addIfPld('Master', _isMasterPldFlag(widget.field));

    return hits;
  }

  Color _flagColor(String? flag) {
    switch (flag?.toLowerCase()) {
      case 'green':
        return AdvantaColors.success;
      case 'yellow':
        return AdvantaColors.gold; // Ganti .warning dengan .gold
      case 'red':
        return AdvantaColors.error;
      case 'black':
        return AdvantaColors.charcoal;
      default:
        return AdvantaColors.mutedGrey;
    }
  }

  // Fungsi untuk mengecek apakah sebuah fase spesifik sudah diaudit
  bool _isPhaseAudited(String phaseKey, FieldAuditStatus status) {
    switch (phaseKey) {
      case 'vegetative':
        return status.vegetative == SingleAuditStatus.sampun;
      case 'generative_1':
        return status.gen1Done;
      case 'generative_2':
        return status.gen2Done;
      case 'generative_3':
        return status.gen3Done;
      case 'generative_4':
        return status.gen4Done; // tambah field di FieldAuditStatus
      case 'generative_5':
        return status.gen5Done;
      case 'pre_harvest':
        return status.preHarvest == SingleAuditStatus.sampun;
      case 'harvest':
        return status.harvest == SingleAuditStatus.sampun;
      default:
        return false;
    }
  }

  Future<void> _openInGoogleMaps(double? lat, double? lng) async {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat tidak valid untuk navigasi.')),
      );
      return;
    }

    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
        );
      }
    }
  }

  List<(PhaseIsoType, String, IconData, Color)> _phaseIsoOptions() {
    return const [
      (
        PhaseIsoType.vegetative,
        'Vegetative',
        Icons.grass_rounded,
        Color(0xFF78909C),
      ),
      (
        PhaseIsoType.preHarvest,
        'Pre-Harvest',
        Icons.content_cut_rounded,
        Color(0xFF26C6DA),
      ),
      (
        PhaseIsoType.harvest,
        'Harvest',
        Icons.agriculture_rounded,
        Color(0xFFFF7043),
      ),
    ];
  }

  Future<void> _downloadPhaseIso(
    PhaseIsoType phase, {
    required bool asPdf,
  }) async {
    if (_isExportingPhaseIso) return;

    var fieldData = widget.field;
    final fieldNumber = fieldData['field_number']?.toString().trim() ?? '';
    if (fieldNumber.isNotEmpty) {
      final cachedDetail =
          ref.read(masterFieldDetailProvider(fieldNumber)).value;
      if (cachedDetail != null) {
        fieldData = cachedDetail;
      } else {
        try {
          final freshDetail = await ref
              .read(supabaseServiceProvider)
              .getMasterFieldWithAllAudits(fieldNumber);
          if (freshDetail != null) fieldData = freshDetail;
        } catch (_) {
          // Tetap gunakan data yang sudah ada di sheet.
        }
      }
    }

    if (!PhaseIsoExportService.hasAuditData(fieldData, phase)) {
      _showSheetSnack(
        'Data audit ${PhaseIsoExportService.phaseLabel(phase)} belum tersedia.',
        err: true,
      );
      return;
    }

    setState(() => _isExportingPhaseIso = true);
    try {
      final payload = PhaseIsoExportData(fieldData: fieldData, phase: phase);
      final path = asPdf
          ? await PhaseIsoExportService.downloadPdf(payload)
          : await PhaseIsoExportService.downloadPicture(payload);
      if (mounted) {
        _showSheetSnack(
          'ISO ${PhaseIsoExportService.phaseLabel(phase)} tersimpan: $path',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSheetSnack(
          'Gagal generate ISO ${PhaseIsoExportService.phaseLabel(phase)}: $e',
          err: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPhaseIso = false);
    }
  }

  void _showSheetSnack(String msg, {bool err = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AdvantaText.body2.copyWith(color: Colors.white),
        ),
        backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final fieldNumber = field['field_number']?.toString() ?? '';
    final flag = field['flagging_final']?.toString();
    final user = ref.watch(currentUserProvider).value;
    final canEditMasterData =
        user != null && user.role.toLowerCase() != 'guest';
    final pldPhases = _pldAuditPhases();
    final isPldField = pldPhases.isNotEmpty;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // KUNCI 1: GestureDetector Terluar (Menangkap klik di area transparan)
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque, // Pastikan area transparan tetap bisa diklik
      onTap: () => Navigator.pop(context), // Perintah menutup sheet
      child: DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.60, 0.95],
        builder: (ctx, scrollCtrl) {
          // KUNCI 2: GestureDetector Dalam (Melindungi konten dari perintah tutup)
          return GestureDetector(
            onTap:
                () {}, // Kosongkan agar menyerap klik (klik tidak diteruskan ke luar)
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AdvantaRadius.sheetRadius,
                border: isPldField
                    ? Border.all(
                        color: AdvantaColors.error.withAlpha(150),
                        width: 1.4,
                      )
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DragHandle(isDark: isDark),
                      _buildHeader(fieldNumber, _dap, _recommendedPhase, flag,
                          field, theme, isDark, pldPhases),
                      _buildTabBar(theme, isDark, isPldField),
                      _buildContent(_dap, _recommendedPhase, fieldNumber, field,
                          theme, isDark, canEditMasterData),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(
    String fieldNumber,
    int dap,
    String recommendedPhase,
    String? flag,
    Map<String, dynamic> field,
    ThemeData theme,
    bool isDark,
    List<String> pldPhases,
  ) {
    final hybrid = field['hybrid']?.toString();
    final isPldField = pldPhases.isNotEmpty;
    final markerColor = isPldField
        ? AdvantaColors.error
        : DapHelper.getDapMarkerColor(dap, hybrid: hybrid);
    final farmName = _fmt(field['farmer_name']);
    final region = _fmt(field['region']);
    final district = _fmt(field['district_kab']);

    final coordStr = field['coordinate']?.toString() ?? '';
    final corrStr = field['correction_tagging']?.toString() ?? '';

    double? targetLat, targetLng;
    if (corrStr.contains(',')) {
      final p = corrStr.split(',');
      targetLat = double.tryParse(p[0]);
      targetLng = double.tryParse(p[1]);
    } else if (coordStr.contains(',')) {
      final p = coordStr.split(',');
      targetLat = double.tryParse(p[0]);
      targetLng = double.tryParse(p[1]);
    }

    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final textSubColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
      decoration: BoxDecoration(
        color:
            isPldField ? AdvantaColors.error.withAlpha(isDark ? 40 : 18) : null,
        border: Border(
          bottom: BorderSide(
            color: isPldField
                ? AdvantaColors.error.withAlpha(isDark ? 160 : 120)
                : borderColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDapBadge(dap, markerColor),
              const SizedBox(width: 12.0),

              // Field number + lokasi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Field #$fieldNumber',
                            style: AdvantaText.heading2
                                .copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                        _buildNavButton(targetLat, targetLng),
                        const SizedBox(width: 8),
                        if (isPldField)
                          const _FlagBadge(
                              flag: 'PLD', color: AdvantaColors.error)
                        else if (flag != null && flag.isNotEmpty)
                          _FlagBadge(flag: flag, color: _flagColor(flag)),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(farmName,
                        style: AdvantaText.label.copyWith(color: textSubColor)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: textSubColor, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          '$district · $region',
                          style:
                              AdvantaText.caption.copyWith(color: textSubColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          if (isPldField) ...[
            _PldAlertBanner(phases: pldPhases, isDark: isDark),
            const SizedBox(height: 12.0),
          ],

          // DAP Progress bar
          _DapProgressBar(
            dap: dap,
            recommendedPhase: _getPhaseLabel(recommendedPhase),
            phaseColors: _phaseColors,
            hybrid: hybrid,
          ),
          Builder(builder: (context) {
            final auditStatus = AuditStatusHelper.fromRaw(field);
            final isRecPhaseAudited =
                _isPhaseAudited(recommendedPhase, auditStatus);

            return _DapCalculationBox(
              plantingDate:
                  _finalPlantingDate, // <-- Pakai _finalPlantingDate yang sudah difilter
              dap: dap,
              phaseKey: recommendedPhase,
              hybrid: hybrid,
              isAudited: isRecPhaseAudited,
              isDark: isDark,
              referenceDate: _dapReferenceDate,
              isRevisied: _isPlantingDateRevisied, // <-- Kirim penanda revisi
            );
          }),
        ],
      ),
    );
  }

  // Fungsi helper untuk tombol navigasi kecil yang cantik
  Widget _buildNavButton(double? lat, double? lng) {
    return InkWell(
      onTap: () => _openInGoogleMaps(lat, lng),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AdvantaColors.primaryGreen.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdvantaColors.primaryGreen.withAlpha(100)),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_outlined,
                color: AdvantaColors.primaryGreen, size: 14),
            const SizedBox(width: 4),
            Text(
              'RUTE',
              style: AdvantaText.label
                  .copyWith(color: AdvantaColors.primaryGreen, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi helper untuk DAP Badge
  Widget _buildDapBadge(int dap, Color markerColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: markerColor.withAlpha(38),
        shape: BoxShape.circle,
        border: Border.all(color: markerColor, width: 2),
        boxShadow: [
          BoxShadow(color: markerColor.withAlpha(90), blurRadius: 12),
        ],
      ),
      child: Center(
        child: Text(
          '$dap',
          style: AdvantaText.heading3.copyWith(color: markerColor, height: 1.0),
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────
  Widget _buildTabBar(ThemeData theme, bool isDark, bool isPldField) {
    const tabs = ['Info Lahan', 'Histori', 'Mulai Inspeksi'];
    const tabIcons = [
      Icons.info_outline_rounded,
      Icons.history_rounded,
      Icons.assignment_outlined,
    ];

    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final textSubColor = isDark ? Colors.white60 : AdvantaColors.mutedGrey;

    return Container(
      decoration: BoxDecoration(
        color: isPldField
            ? AdvantaColors.error.withAlpha(isDark ? 32 : 14)
            : (isDark
                ? AdvantaColors.deepForest.withAlpha(100)
                : AdvantaColors.softGrey),
        border: Border(
          bottom: BorderSide(
            color: isPldField
                ? AdvantaColors.error.withAlpha(isDark ? 140 : 90)
                : borderColor,
          ),
        ),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _tab == i;
          final activeColor = isPldField
              ? AdvantaColors.error
              : (i == 2
                  ? AdvantaColors.lightGreen
                  : (isDark
                      ? AdvantaColors.goldLight
                      : theme.colorScheme.primary));

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? activeColor : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      tabIcons[i],
                      size: 16,
                      color: active ? activeColor : textSubColor,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i],
                      style: AdvantaText.caption.copyWith(
                        color: active ? activeColor : textSubColor,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── CONTENT ROUTER ────────────────────────────────────────
  // ── CONTENT ROUTER ────────────────────────────────────────
  Widget _buildContent(
    int dap,
    String recommendedPhase,
    String fieldNumber,
    Map<String, dynamic> field,
    ThemeData theme,
    bool isDark,
    bool canEditMasterData,
  ) {
    Widget activeTab;
    switch (_tab) {
      case 0:
        activeTab = _buildInfoTab(field, theme, isDark, canEditMasterData);
        break;
      case 1:
        activeTab = _buildHistoriTab(dap, field, theme, isDark);
        break;
      default:
        activeTab =
            _buildAksiTab(dap, recommendedPhase, fieldNumber, theme, isDark);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(key: ValueKey(_tab), child: activeTab),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TAB 0 — INFO LAHAN
  // ──────────────────────────────────────────────────────────
  Widget _buildInfoTab(Map<String, dynamic> field, ThemeData theme, bool isDark,
      bool canEditMasterData) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      child: Column(
        children: [
          _SectionCard(
            title: 'Identitas Lahan',
            icon: Icons.badge_outlined,
            theme: theme,
            isDark: isDark,
            children: [
              _Row2Col(
                left: _InfoCell('Season', _fmt(field['season']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('Tipe', _fmt(field['type']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('Hybrid', _fmt(field['hybrid']),
                    theme: theme, isDark: isDark),
                right: _InfoCell(
                    'Planting Ratio', _fmt(field['planting_ratio']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('Jarak Tanam', _fmt(field['planting_space']),
                    theme: theme, isDark: isDark),
                right: _InfoCell(
                    'Standing Crops', _fmt(field['standing_crops']),
                    theme: theme, isDark: isDark),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          _SectionCard(
            title: 'Area & Tanaman',
            icon: Icons.crop_landscape_outlined,
            theme: theme,
            isDark: isDark,
            children: [
              _Row3Col(
                a: _InfoCell(
                    'Total Area', '${_fmt(field['total_area_planted_ha'])} Ha',
                    theme: theme, isDark: isDark),
                b: _InfoCell('Discard', '${_fmt(field['discard_area_ha'])} Ha',
                    theme: theme, isDark: isDark),
                c: _InfoCell(
                    'Efektif', '${_fmt(field['effective_area_ha'])} Ha',
                    highlight: true, theme: theme, isDark: isDark),
              ),
              _Row3Col(
                a: _InfoCell(
                    'Hasil Panen', '${_fmt(field['harvested_area_ha'])} Ha',
                    theme: theme, isDark: isDark),
                b: _InfoCell(
                    'Qty Panen', '${_fmt(field['harvested_qty_kg'])} Kg',
                    theme: theme, isDark: isDark),
                c: _InfoCell('Prev Crop', _fmt(field['previous_crop_data_a_b']),
                    theme: theme, isDark: isDark),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          _SectionCard(
            title: 'Penanggung Jawab',
            icon: Icons.people_alt_outlined,
            theme: theme,
            isDark: isDark,
            children: [
              _Row2Col(
                left: _InfoCell('Petani', _fmt(field['farmer_name']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('Grower', _fmt(field['grower']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('FA', _fmt(field['fa']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('SPV', _fmt(field['field_spv']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('QA FI', _fmt(field['qa_fi']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('QA SPV', _fmt(field['qa_spv']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('Area Manager', _fmt(field['area_manager']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('Corr. Tag', _fmt(field['correction_tagging']),
                    theme: theme, isDark: isDark),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          _SectionCard(
            title: 'Lokasi',
            icon: Icons.place_outlined,
            theme: theme,
            isDark: isDark,
            isEditable: canEditMasterData,
            action: canEditMasterData
                ? InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/edit-field', extra: field);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdvantaColors.gold.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AdvantaColors.gold.withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              color: AdvantaColors.gold, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'EDIT',
                            style: AdvantaText.label.copyWith(
                                color: AdvantaColors.gold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
            children: [
              _Row2Col(
                left: _InfoCell('Provinsi', _fmt(field['prov']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('Kabupaten', _fmt(field['district_kab']),
                    theme: theme, isDark: isDark),
              ),
              _Row2Col(
                left: _InfoCell('Kecamatan', _fmt(field['sub_district_kec']),
                    theme: theme, isDark: isDark),
                right: _InfoCell('Desa', _fmt(field['village_desa']),
                    theme: theme, isDark: isDark),
              ),
              _InfoCell('Dusun', _fmt(field['hamlet_dusun']),
                  theme: theme, isDark: isDark),
              const SizedBox(height: 4),
              _InfoCell('Koordinat', _fmt(field['coordinate']),
                  theme: theme, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TAB 1 — HISTORI INSPEKSI
  // ──────────────────────────────────────────────────────────
  Widget _buildHistoriTab(
      int dap, Map<String, dynamic> field, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      child: Column(
        children: [
          _buildPhaseIsoExportCard(field, theme, isDark),
          const SizedBox(height: 14.0),
          ..._buildPhaseTimeline(dap, field, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildPhaseIsoExportCard(
    Map<String, dynamic> field,
    ThemeData theme,
    bool isDark,
  ) {
    final options = _phaseIsoOptions();
    return _SectionCard(
      title: 'ISO Output',
      icon: Icons.description_outlined,
      theme: theme,
      isDark: isDark,
      children: [
        Text(
          'Export format ISO untuk fase Vegetative, Pre-Harvest, dan Harvest.',
          style: AdvantaText.caption.copyWith(
            color: isDark ? Colors.white60 : AdvantaColors.mutedGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(options.length, (index) {
          final option = options[index];
          final hasData = PhaseIsoExportService.hasAuditData(field, option.$1);
          return Column(
            children: [
              _PhaseIsoExportRow(
                label: option.$2,
                icon: option.$3,
                color: option.$4,
                enabled: hasData,
                busy: _isExportingPhaseIso,
                theme: theme,
                isDark: isDark,
                onPicture: () => _downloadPhaseIso(option.$1, asPdf: false),
                onPdf: () => _downloadPhaseIso(option.$1, asPdf: true),
              ),
              if (index != options.length - 1)
                Divider(
                  height: 18,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
            ],
          );
        }),
      ],
    );
  }

// 👇 SILAKAN PASTE FUNGSI INI DI BAWAH _buildHistoriTab 👇
  List<Widget> _buildPhaseTimeline(
      int dap, Map<String, dynamic> field, ThemeData theme, bool isDark) {
    final phaseToAudit = {
      'vegetative': 'audit_vegetative',
      'generative_1': 'audit_generative',
      'generative_2': 'audit_generative',
      'generative_3': 'audit_generative',
      'generative_4': 'audit_generative',
      'generative_5': 'audit_generative',
      'pre_harvest': 'audit_pre_harvest',
      'harvest': 'audit_harvest',
    };

    // Gunakan AuditStatusHelper sebagai single source of truth
    final auditStatus = AuditStatusHelper.fromRaw(field);
    final widgets = <Widget>[];

    for (int i = 0; i < _phaseKeys.length; i++) {
      final phaseKey = _phaseKeys[i];
      final auditKey = phaseToAudit[phaseKey]!;
      final auditData = _auditMap(auditKey);
      final color = _phaseColors[i];
      final isLast = i == _phaseKeys.length - 1;

      String? auditDate;
      String? auditWeek;
      String? decision;

      if (phaseKey.startsWith('generative_')) {
        final cp = phaseKey.split('_')[1];
        auditDate = auditData?['date_of_audit_$cp']?.toString();
        auditWeek = auditData?['audit_week_$cp']?.toString() ??
            auditData?['audit_week']?.toString();
        decision = auditData?['final_decision_$cp']?.toString() ??
            auditData?['action_needed_$cp']?.toString();
      } else if (phaseKey == 'vegetative') {
        auditDate = auditData?['date_of_audit']?.toString();
        auditWeek = auditData?['audit_week']?.toString();
        decision = auditData?['decision']?.toString() ??
            auditData?['final_decision']?.toString() ??
            auditData?['flagging']?.toString();
      } else if (phaseKey == 'pre_harvest') {
        auditDate = auditData?['audit_date']?.toString();
        auditWeek = auditData?['audit_week']?.toString();
        decision = auditData?['final_decision']?.toString() ??
            auditData?['flagging']?.toString();
      } else {
        auditDate = auditData?['date_of_audit']?.toString();
        auditWeek = auditData?['audit_week']?.toString();
        decision = auditData?['final_decision']?.toString() ??
            auditData?['flagging']?.toString();
      }

      final isPldPhase = switch (phaseKey) {
        'vegetative' => _isVegetativePldAudit(auditData),
        'pre_harvest' => _isPreHarvestPldAudit(auditData),
        'harvest' => _isHarvestPldAudit(auditData),
        _ when phaseKey.startsWith('generative_') =>
          _isGenerativePldAudit(auditData, int.parse(phaseKey.split('_')[1])),
        _ => false,
      };
      final hasVegetativeProgress =
          phaseKey == 'vegetative' && auditStatus.hasVegetativePartialProgress;
      final itemColor = isPldPhase
          ? AdvantaColors.error
          : (hasVegetativeProgress ? const Color(0xFFFFA726) : color);

      // Penentuan apakah fase sudah selesai
      final bool hasData;
      switch (phaseKey) {
        case 'vegetative':
          hasData = auditStatus.vegetative == SingleAuditStatus.sampun;
          break;
        case 'generative_1':
          hasData = auditStatus.gen1Done;
          break;
        case 'generative_2':
          hasData = auditStatus.gen2Done;
          break;
        case 'generative_3':
          hasData = auditStatus.gen3Done;
          break;
        case 'generative_4':
          hasData = auditStatus.gen4Done;
          break;
        case 'generative_5':
          hasData = auditStatus.gen5Done;
          break;
        case 'pre_harvest':
          hasData = auditStatus.preHarvest == SingleAuditStatus.sampun;
          break;
        default: // harvest
          hasData = auditStatus.harvest == SingleAuditStatus.sampun;
      }

      final hasDate = auditDate != null && auditDate.trim().isNotEmpty;
      final progressLabel = hasVegetativeProgress
          ? auditStatus.vegetativeProgressPercentLabel
          : null;
      final progressDetail = hasVegetativeProgress
          ? 'Roguing ${auditStatus.vegetativeProgressCountLabel} selesai'
          : null;
      final progressFraction =
          hasVegetativeProgress ? auditStatus.vegetativeProgressFraction : 0.0;

      widgets.add(
        _PhaseTimelineItem(
          index: i,
          phaseKey: phaseKey,
          label: _phaseLabels[i],
          icon: _phaseIcons[i],
          color: itemColor,
          hasData: hasData,
          auditDate: hasDate ? auditDate : null,
          auditWeek: auditWeek,
          decision: decision,
          progressLabel: progressLabel,
          progressDetail: progressDetail,
          progressFraction: progressFraction,
          isLast: isLast,
          dap: dap,
          theme: theme,
          isDark: isDark,
        ),
      );
    }

    return widgets;
  }

  // ──────────────────────────────────────────────────────────
  // TAB 2 — AKSI / MULAI INSPEKSI
  // ──────────────────────────────────────────────────────────
  Widget _buildAksiTab(int dap, String recommendedPhase, String fieldNumber,
      ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info rekomendasi
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isDark
                  ? AdvantaColors.midGreen.withAlpha(80)
                  : AdvantaColors.paleGreen,
              borderRadius: AdvantaRadius.cardRadius,
              border: Border.all(
                color: isDark
                    ? AdvantaColors.goldLight
                    : AdvantaColors.primaryGreen,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: isDark
                        ? AdvantaColors.goldLight
                        : AdvantaColors.primaryGreen,
                    size: 16),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    'DAP saat ini: $dap hari. Fase rekomendasi: '
                    '${_getPhaseLabel(recommendedPhase)}. '
                    'Anda tetap bebas memilih fase lain.',
                    style: AdvantaText.caption.copyWith(
                      color: isDark
                          ? AdvantaColors.goldLight
                          : AdvantaColors.primaryGreen,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Section label
          Text(
            'PILIH FASE INSPEKSI',
            style: AdvantaText.label.copyWith(
                letterSpacing: 1.5,
                color:
                    isDark ? AdvantaColors.goldLight : AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 10.0),

          // Phase buttons
          ...List.generate(_phaseKeys.length, (i) {
            final phaseKey = _phaseKeys[i];
            final color = _phaseColors[i];
            final label = _phaseLabels[i];
            final icon = _phaseIcons[i];

            final isRecommended = recommendedPhase == phaseKey;
            final auditStatus = AuditStatusHelper.fromRaw(widget.field);
            final isAudited = _isPhaseAudited(phaseKey, auditStatus);

            String translatedBadge;
            Color badgeColor;

            if (isAudited) {
              translatedBadge = 'Selesai';
              badgeColor = AdvantaColors.success;
            } else {
              final rawBadge = DapHelper.getDapBadgeLabel(dap, phaseKey,
                  hybrid: widget.field['hybrid']?.toString());
              badgeColor = DapHelper.getDapBadgeColor(rawBadge);

              switch (rawBadge.toLowerCase()) {
                case 'overdue':
                  translatedBadge = 'Terlambat';
                  break;
                case 'upcoming':
                  translatedBadge = 'Akan Datang';
                  break;
                case 'on going':
                  translatedBadge = 'Sedang Berjalan';
                  break;
                default:
                  translatedBadge = rawBadge;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _PhaseActionButton(
                icon: isAudited ? Icons.check_circle_outline : icon,
                phaseKey: phaseKey,
                label: label,
                color: isAudited ? AdvantaColors.success : color,
                phaseColor: color,
                badge: translatedBadge,
                badgeColor: badgeColor,
                isAudited: isAudited,
                isRecommended: isRecommended,
                theme: theme,
                isDark: isDark,
                onTap: () async {
                  final fieldData = widget.field;

                  // LOGIKA ROUTING:
                  if (_isPSP) {
                    if (phaseKey == 'vegetative') {
                      final saved = await context
                          .push('/inspect_psp/vegetative/$fieldNumber');
                      if (saved == true) widget.onInspectDone?.call(fieldData);
                      return;
                    }
                    if (phaseKey == 'generative_5') {
                      final saved = await context
                          .push('/inspect_psp/generative/$fieldNumber');
                      if (saved == true) widget.onInspectDone?.call(fieldData);
                      return;
                    }
                    if (phaseKey == 'harvest') {
                      final saved = await context
                          .push('/inspect_psp/harvest/$fieldNumber');
                      if (saved == true) widget.onInspectDone?.call(fieldData);
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Modul PSP (ASF) selain vegetative akan segera hadir.')),
                    );
                    return;
                  }

                  if (_isSweetCorn) {
                    // Arahkan ke form khusus Sweet Corn (AX01-04)
                    final saved = await context
                        .push('/inspect_sc/$phaseKey/$fieldNumber');
                    if (saved == true) widget.onInspectDone?.call(fieldData);
                  } else {
                    // Arahkan ke form reguler/lama (AX non 01-04 atau lainnya)
                    final saved =
                        await context.push('/inspect/$phaseKey/$fieldNumber');
                    if (saved == true) widget.onInspectDone?.call(fieldData);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  final bool isDark;
  const _DragHandle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black26,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  final String flag;
  final Color color;
  const _FlagBadge({required this.flag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: AdvantaRadius.chipRadius,
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            flag.toUpperCase(),
            style: AdvantaText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PldAlertBanner extends StatelessWidget {
  final List<String> phases;
  final bool isDark;

  const _PldAlertBanner({
    required this.phases,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final phaseText = phases.take(3).join(', ');
    final extraCount = phases.length - 3;
    final suffix = extraCount > 0 ? ' +$extraCount fase' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdvantaColors.error.withAlpha(isDark ? 45 : 24),
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: AdvantaColors.error.withAlpha(isDark ? 140 : 95),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AdvantaColors.error.withAlpha(48),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AdvantaColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Status PLD terdeteksi: $phaseText$suffix',
              style: AdvantaText.caption.copyWith(
                color: isDark ? const Color(0xFFFFCDD2) : AdvantaColors.error,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DapProgressBar extends StatelessWidget {
  final int dap;
  final String recommendedPhase;
  final List<Color> phaseColors;
  final String? hybrid;

  const _DapProgressBar({
    required this.dap,
    required this.recommendedPhase,
    required this.phaseColors,
    this.hybrid,
  });

  @override
  Widget build(BuildContext context) {
    final rules = DapHelper.getPhaseRules(hybrid: hybrid);
    final labels = DapHelper.getPhaseShortLabels(hybrid: hybrid);
    final activePhase = DapHelper.getRecommendedPhase(dap, hybrid: hybrid);
    final activeIndex = rules.indexWhere((rule) => rule.key == activePhase);
    final activeSeg = activeIndex == -1 ? rules.length - 1 : activeIndex;
    final colors = List<Color>.generate(
      rules.length,
      (i) => i < phaseColors.length ? phaseColors[i] : rules[i].markerColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(rules.length, (i) {
            final isActive = i == activeSeg;
            return Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: isActive
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: isActive
                      ? BoxDecoration(
                          color: colors[i].withAlpha(24),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors[i].withAlpha(70)),
                        )
                      : null,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AdvantaText.caption.copyWith(
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                      color: isActive
                          ? colors[i]
                          : AdvantaColors.mutedGrey.withAlpha(120),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: SizedBox(
            height: 6,
            child: Row(
              children: List.generate(rules.length, (i) {
                final segStart = i == 0 ? 0 : rules[i - 1].phaseEnd;
                final segEnd = rules[i].phaseEnd;
                final segWidth = (segEnd - segStart).clamp(1, 1000).toInt();

                double fill = 0.0;
                if (dap >= segEnd) {
                  fill = 1.0;
                } else if (dap > segStart) {
                  fill = (dap - segStart) / segWidth;
                }

                return Expanded(
                  flex: segWidth,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    child: Stack(
                      children: [
                        Container(color: colors[i].withAlpha(30)),
                        FractionallySizedBox(
                          widthFactor: fill,
                          child: Container(color: colors[i]),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8.0,
          runSpacing: 2.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'DAP $dap',
              style: AdvantaText.label.copyWith(
                color: colors[activeSeg],
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Rekomendasi: $recommendedPhase',
              style:
                  AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final ThemeData theme;
  final bool isDark;
  final Widget? action;
  final bool isEditable; // ── TAMBAHAN: Penanda apakah card ini bisa diedit

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.theme,
    required this.isDark,
    this.action,
    this.isEditable = false, // ── Default-nya false (tidak bisa diedit)
  });

  @override
  Widget build(BuildContext context) {
    // Menentukan warna background berdasarkan mode (Edit vs Normal)
    final bgColor = isEditable
        ? AdvantaColors.gold
            .withAlpha(isDark ? 25 : 40) // Highlight emas transparan
        : (isDark
            ? AdvantaColors.deepForest.withAlpha(100)
            : AdvantaColors.softGrey);

    // Menentukan warna garis tepi (border)
    final borderColor = isEditable
        ? AdvantaColors.gold
            .withAlpha(isDark ? 80 : 120) // Border emas yang lebih tegas
        : (isDark ? Colors.white12 : Colors.black12);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
            color: borderColor,
            width: isEditable
                ? 1.5
                : 1.0), // Border sedikit lebih tebal jika bisa diedit
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
            child: Row(
              children: [
                Icon(icon,
                    color: isEditable
                        ? AdvantaColors.gold
                        : (isDark
                            ? AdvantaColors.goldLight
                            : theme.colorScheme.primary),
                    size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AdvantaText.label.copyWith(
                      color: isEditable
                          ? AdvantaColors.gold
                          : (isDark
                              ? AdvantaColors.goldLight
                              : theme.colorScheme.primary),
                      letterSpacing: 0.8,
                      fontWeight:
                          isEditable ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final ThemeData theme;
  final bool isDark;

  const _InfoCell(this.label, this.value,
      {this.highlight = false, required this.theme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AdvantaText.caption.copyWith(
                color: isDark ? Colors.white54 : AdvantaColors.mutedGrey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AdvantaText.body2.copyWith(
              color: highlight
                  ? (isDark
                      ? AdvantaColors.goldLight
                      : theme.colorScheme.primary)
                  : theme.colorScheme.onSurface,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row2Col extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _Row2Col({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12.0),
        Expanded(child: right),
      ],
    );
  }
}

class _Row3Col extends StatelessWidget {
  final Widget a;
  final Widget b;
  final Widget c;
  const _Row3Col({required this.a, required this.b, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 8.0),
        Expanded(child: b),
        const SizedBox(width: 8.0),
        Expanded(child: c),
      ],
    );
  }
}

class _PhaseTimelineItem extends StatelessWidget {
  final int index;
  final String phaseKey;
  final String label;
  final IconData icon;
  final Color color;
  final bool hasData;
  final String? auditDate;
  final String? auditWeek;
  final String? decision;
  final String? progressLabel;
  final String? progressDetail;
  final double progressFraction;
  final bool isLast;
  final int dap;
  final ThemeData theme;
  final bool isDark;

  const _PhaseTimelineItem({
    required this.index,
    required this.phaseKey,
    required this.label,
    required this.icon,
    required this.color,
    required this.hasData,
    required this.auditDate,
    required this.auditWeek,
    required this.decision,
    required this.progressLabel,
    required this.progressDetail,
    required this.progressFraction,
    required this.isLast,
    required this.dap,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final hasProgress = progressLabel != null;
    final activeColor =
        hasData || hasProgress ? color : AdvantaColors.mutedGrey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasData || hasProgress
                      ? color.withAlpha(46)
                      : (isDark ? Colors.white10 : Colors.black12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasData || hasProgress ? color : borderColor,
                    width: hasData || hasProgress ? 2.0 : 1.0,
                  ),
                  boxShadow: hasData || hasProgress
                      ? [BoxShadow(color: color.withAlpha(76), blurRadius: 8)]
                      : null,
                ),
                child: Center(
                  child: PhaseAssetIcon(
                    phaseKey: phaseKey,
                    fallbackIcon: icon,
                    fallbackColor: activeColor,
                    size: 24,
                    completed: hasData,
                    opacity: hasData || hasProgress ? 1 : 0.42,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 52,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: hasData || hasProgress
                        ? color.withAlpha(90)
                        : borderColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: hasData
                    ? color.withAlpha(15)
                    : hasProgress
                        ? color.withAlpha(10)
                        : (isDark
                            ? Colors.white.withAlpha(5)
                            : AdvantaColors.softGrey),
                borderRadius: AdvantaRadius.cardRadius,
                border: Border.all(
                  color: hasData || hasProgress
                      ? color.withAlpha(64)
                      : borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AdvantaText.label.copyWith(
                          color: hasData || hasProgress
                              ? theme.colorScheme.onSurface
                              : AdvantaColors.mutedGrey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (hasData)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(38),
                            borderRadius: AdvantaRadius.chipRadius,
                          ),
                          child: Text(
                            'SELESAI',
                            style: AdvantaText.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else if (hasProgress)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(38),
                            borderRadius: AdvantaRadius.chipRadius,
                          ),
                          child: Text(
                            progressLabel!,
                            style: AdvantaText.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: AdvantaRadius.chipRadius,
                          ),
                          child: Text(
                            'BELUM',
                            style: AdvantaText.caption.copyWith(
                              color: isDark
                                  ? Colors.white54
                                  : AdvantaColors.mutedGrey,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (auditDate != null) ...[
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 10, color: AdvantaColors.mutedGrey),
                        const SizedBox(width: 4),
                        Text(auditDate!,
                            style: AdvantaText.caption
                                .copyWith(color: theme.colorScheme.onSurface)),
                        if (auditWeek != null) ...[
                          const SizedBox(width: 8),
                          Text('Week $auditWeek',
                              style: AdvantaText.caption
                                  .copyWith(color: AdvantaColors.mutedGrey)),
                        ],
                      ],
                    ),
                    if (decision != null && decision!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        decision!,
                        style: AdvantaText.caption.copyWith(
                          color: isDark ? color.withAlpha(204) : color,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                  if (hasProgress) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progressFraction.clamp(0.0, 1.0).toDouble(),
                        minHeight: 5,
                        backgroundColor:
                            isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    if (progressDetail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        progressDetail!,
                        style: AdvantaText.caption.copyWith(
                          color: isDark
                              ? color.withAlpha(204)
                              : color.withAlpha(220),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                  if (!hasData) ...[
                    const SizedBox(height: 4),
                    Text(
                      hasProgress
                          ? 'Audit PSP vegetative masih berjalan'
                          : 'Belum ada data inspeksi',
                      style: AdvantaText.caption
                          .copyWith(color: AdvantaColors.mutedGrey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseIsoExportRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool busy;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onPicture;
  final VoidCallback onPdf;

  const _PhaseIsoExportRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.busy,
    required this.theme,
    required this.isDark,
    required this.onPicture,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? theme.colorScheme.onSurface
        : (isDark ? Colors.white38 : AdvantaColors.mutedGrey);
    final subColor = enabled
        ? (isDark ? Colors.white60 : AdvantaColors.mutedGrey)
        : (isDark ? Colors.white30 : AdvantaColors.mutedGrey.withAlpha(150));

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? color.withAlpha(36) : Colors.black.withAlpha(8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? color : subColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AdvantaText.bodyBold.copyWith(color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                enabled
                    ? 'Data audit tersedia'
                    : 'Belum ada data audit fase ini',
                style: AdvantaText.caption.copyWith(color: subColor),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Download Picture',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: enabled && !busy ? onPicture : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            color: color,
          ),
        ),
        Tooltip(
          message: 'Download PDF',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: enabled && !busy ? onPdf : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PhaseActionButton extends StatelessWidget {
  final IconData icon;
  final String phaseKey;
  final String label;
  final Color color;
  final Color phaseColor;
  final String badge;
  final Color badgeColor;
  final bool isAudited;
  final bool isRecommended;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _PhaseActionButton({
    required this.icon,
    required this.phaseKey,
    required this.label,
    required this.color,
    required this.phaseColor,
    required this.badge,
    required this.badgeColor,
    required this.isAudited,
    required this.isRecommended,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: isRecommended
              ? color.withAlpha(30)
              : (isDark ? Colors.white.withAlpha(8) : AdvantaColors.softGrey),
          borderRadius: AdvantaRadius.cardRadius,
          border: Border.all(
            color: isRecommended
                ? color.withAlpha(115)
                : (isDark ? Colors.white12 : Colors.black12),
            width: isRecommended ? 1.5 : 1.0,
          ),
          boxShadow: isRecommended
              ? [BoxShadow(color: color.withAlpha(38), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Center(
                child: PhaseAssetIcon(
                  phaseKey: phaseKey,
                  fallbackIcon: icon,
                  fallbackColor: isAudited ? color : phaseColor,
                  size: 30,
                  completed: isAudited,
                ),
              ),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AdvantaText.bodyBold
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AdvantaColors.successLight.withAlpha(40)
                                : AdvantaColors.paleGreen,
                            borderRadius: AdvantaRadius.chipRadius,
                            border: Border.all(
                                color: AdvantaColors.lightGreen.withAlpha(100)),
                          ),
                          child: Text(
                            '★ Rekomendasi',
                            style: AdvantaText.caption.copyWith(
                              color: AdvantaColors.lightGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge,
                    style: AdvantaText.caption.copyWith(
                        color: badgeColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.black38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DAP CALCULATION / SIMULATION BOX (DENGAN LOGIKA AUDIT)
// ─────────────────────────────────────────────────────────────
class _DapCalculationBox extends StatelessWidget {
  final String? plantingDate;
  final int dap;
  final String phaseKey;
  final String? hybrid;
  final bool isAudited;
  final bool isDark;
  final DateTime referenceDate;
  final bool isRevisied; // <-- Tambahan

  const _DapCalculationBox({
    required this.plantingDate,
    required this.dap,
    required this.phaseKey,
    this.hybrid,
    required this.isAudited,
    required this.isDark,
    required this.referenceDate,
    this.isRevisied = false, // <-- Tambahan (Default false)
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  String _translateBadge(String rawBadge) {
    switch (rawBadge.toLowerCase()) {
      case 'overdue':
        return 'Terlambat';
      case 'upcoming':
        return 'Akan Datang';
      case 'on going':
        return 'Sedang Berjalan';
      default:
        return rawBadge;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (plantingDate == null || plantingDate!.isEmpty) {
      return const SizedBox.shrink();
    }

    final dateStr = _formatDate(plantingDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final referenceOnly =
        DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final referenceStr =
        DateFormat('dd MMM yyyy', 'id_ID').format(referenceOnly);
    final referenceLabel =
        referenceOnly == today ? 'Hari Ini' : 'Tanggal Acuan';

    String translatedBadge;
    Color badgeColor;

    if (isAudited) {
      translatedBadge = 'Selesai';
      badgeColor = AdvantaColors.success;
    } else {
      final rawBadge =
          DapHelper.getDapBadgeLabel(dap, phaseKey, hybrid: hybrid);
      badgeColor = DapHelper.getDapBadgeColor(rawBadge);
      translatedBadge = _translateBadge(rawBadge);
    }

    return Container(
      margin: const EdgeInsets.only(top: 14.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AdvantaColors.deepForest.withAlpha(100)
            : AdvantaColors.softGrey,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(color: badgeColor.withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isAudited
                      ? Icons.check_circle_outline
                      : Icons.calculate_outlined,
                  size: 14,
                  color: badgeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAudited ? 'STATUS FASE REKOMENDASI' : 'SIMULASI UMUR (DAP)',
                  style: AdvantaText.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withAlpha(100)),
                ),
                child: Text(
                  translatedBadge.toUpperCase(),
                  style: AdvantaText.caption.copyWith(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── BAGIAN INI YANG BERUBAH ──
              _buildNode(
                  Icons.eco_rounded,
                  isRevisied
                      ? 'Tgl Tanam (Rev)'
                      : 'Tgl Tanam', // Ganti label jika direvisi
                  dateStr,
                  themeColor: isRevisied
                      ? AdvantaColors.gold
                      : (isDark ? Colors.white : Colors.black87)),
              _buildMath('+ $dap Hari', badgeColor),
              _buildNode(
                  Icons.event_available_rounded, referenceLabel, referenceStr,
                  themeColor: isDark ? Colors.white : Colors.black87),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 12, color: AdvantaColors.mutedGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAudited
                      ? 'Inspeksi untuk fase rekomendasi ini sudah diselesaikan. Status aman.'
                      : 'Lahan dihitung Terlewat (Overdue) jika umur melampaui batas maksimal tanpa ada riwayat audit.',
                  style: AdvantaText.caption.copyWith(
                      color: AdvantaColors.mutedGrey, fontSize: 9, height: 1.3),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNode(IconData icon, String title, String value,
      {required Color themeColor}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AdvantaColors.mutedGrey),
        const SizedBox(height: 4),
        Text(title,
            style: AdvantaText.caption
                .copyWith(color: AdvantaColors.mutedGrey, fontSize: 10)),
        Text(value,
            style:
                AdvantaText.bodyBold.copyWith(fontSize: 12, color: themeColor)),
      ],
    );
  }

  Widget _buildMath(String mathText, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withAlpha(80)),
      ),
      child: Text(
        mathText,
        style: AdvantaText.label.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
