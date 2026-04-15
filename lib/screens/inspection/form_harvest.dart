// lib/screens/inspection/form_harvest.dart
//
// HARVEST AUDIT — Premium redesign
// Kolom: Audit Date · Audit Week · Ear Condition (Maturity) ·
//        Crop Condition · Downgrade Flagging · Reason Downgrade ·
//        Flagging Downgrade · Final Flagging
// DB table: audit_harvest
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_harvest_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import 'generative_form_widgets.dart';

// ─── Phase accent color ───────────────────────────────────
const _kPhase = Color(0xFFFF7043); // Deep Orange — Harvest

// ─── Option lists ─────────────────────────────────────────
const _earConditionOpts = [
  GenOpt('2', 'Stage 2'),
  GenOpt('3', 'Stage 3'),
  GenOpt('4', 'Stage 4'),
];

const _cropCondOpts = [
  GenOpt('1', '1 – Very Poor'),
  GenOpt('2', '2 – Poor'),
  GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'),
  GenOpt('5', '5 – Best'),
];

const _reasonDowngradeOpts = [
  GenOpt('A', 'A – Suspect Mix Material'),
  GenOpt('B', 'B – Not Accessible during Detasseling'),
  GenOpt('C', 'C – Not Sure during Harvest'),
];

const _statusDowngradeOpts = [
  GenOpt('A', 'A – Yes'),
  GenOpt('B', 'B – No'),
];

const _downgradeFlaggingOpts = [
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
];

const _finalFlaggingOpts = [
  GenOpt('GF',  'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF',  'BF'),
];

// ─────────────────────────────────────────────────────────
class FormHarvest extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormHarvest({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormHarvest> createState() => _FormHarvestState();
}

class _FormHarvestState extends ConsumerState<FormHarvest> {
  final _formKey  = GlobalKey<FormState>();
  bool _isSaving  = false;
  bool _dataLoaded = false;

  // Controllers
  final _qaFiCtrl  = TextEditingController();
  final _qaSpvCtrl = TextEditingController();

  // Date
  DateTime  _auditDate         = DateTime.now();
  DateTime? _downgradeFlagDate;

  // Dropdowns
  String? _earCondition;
  String? _cropCondition;
  String? _statusDowngrade;    // status_downgrade (A=Yes/B=No)
  String? _reasonDowngrade;    // reason_downgrade (A/B/C)
  String? _downgradeFlagging;  // downgrade_flagging (RFI/RFD)
  String? _finalFlagging;

  // Downgrade section expand
  bool _showDowngrade = false;

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> a) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text  = a['qa_fi']  ?? '';
    _qaSpvCtrl.text = a['qa_spv'] ?? '';
    if (a['date_of_audit'] != null) {
      try { _auditDate = DateTime.parse(a['date_of_audit']); } catch (_) {}
    }
    if (a['date_of_downgrade_flagging'] != null) {
      try {
        _downgradeFlagDate =
            DateTime.parse(a['date_of_downgrade_flagging']);
      } catch (_) {}
    }
    setState(() {
      _earCondition     = a['ear_condition_observation']?.toString();
      _cropCondition    = a['crop_condition'];
      _statusDowngrade  = a['status_downgrade'];
      _reasonDowngrade  = a['reason_downgrade'];
      _downgradeFlagging = a['downgrade_flagging'];
      _finalFlagging    = a['final_flagging'];
      if (_statusDowngrade != null || _reasonDowngrade != null ||
          _downgradeFlagging != null || _downgradeFlagDate != null) {
        _showDowngrade = true;
      }
    });
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _kPhase, surface: kGenSurface),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _pickDowngradeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _downgradeFlagDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _kPhase, surface: kGenSurface),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _downgradeFlagDate = p);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now  = DateTime.now();
      final data = {
        'field_number'               : widget.fieldNumber,
        'date_of_audit'              : DateFormat('yyyy-MM-dd').format(_auditDate),
        'audit_week'                 : calcAuditWeek(_auditDate),
        'ear_condition_observation'  : _earCondition,
        'crop_condition'             : _cropCondition,
        'status_downgrade'           : _showDowngrade ? _statusDowngrade : null,
        'reason_downgrade'           : _showDowngrade ? _reasonDowngrade : null,
        'downgrade_flagging'         : _showDowngrade ? _downgradeFlagging : null,
        'date_of_downgrade_flagging' : _showDowngrade && _downgradeFlagDate != null
            ? DateFormat('yyyy-MM-dd').format(_downgradeFlagDate!)
            : null,
        'final_flagging'             : _finalFlagging,
        'qa_fi'                      : _qaFiCtrl.text.trim(),
        'qa_spv'                     : _qaSpvCtrl.text.trim(),
        'fase'                       : 'Harvest',
        'updated_at'                 : now.toIso8601String(),
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertHarvestAudit(data);

      double lat = 0, lng = 0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5)),
        );
        lat = pos.latitude; lng = pos.longitude;
      } catch (_) {}

      final att = ref.read(attendanceProvider);
      if (att.isCheckedIn && att.attendanceId != null) {
        await svc.logActivity(
          attendanceId: att.attendanceId!,
          userId      : _qaFiCtrl.text.trim().isNotEmpty
              ? _qaFiCtrl.text.trim() : 'unknown',
          fieldNumber : widget.fieldNumber,
          phase       : 'harvest',
          actionType  : 'single_submit',
          lat: lat, lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(harvestAuditProvider(widget.fieldNumber));
        _snack('Harvest Audit berhasil disimpan ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? kGenRed : kGenGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(harvestAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fd         = fields.firstWhere(
            (f) => f['field_number'] == widget.fieldNumber, orElse: () => {});

    return Scaffold(
      backgroundColor: kGenBg,
      appBar: buildGenAppBar(
        checkpointLabel: 'Harvest Audit',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : false,
        accentColor    : _kPhase,
        onBack         : () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
        const Center(child: CircularProgressIndicator(color: _kPhase)),
        error: (e, _) =>
            Center(child: Text('Error: $e',
                style: const TextStyle(color: kGenSub))),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fd);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fd) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GenFieldCard(fieldData: fd, accentColor: _kPhase),
                  const SizedBox(height: 14),

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon : Icons.assignment_outlined,
                    color: _kPhase,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date : _auditDate,
                          onTap: _pickDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller : _qaFiCtrl,
                        label      : 'QA FI',
                        hint       : 'Nama QA Field Inspector',
                        required   : true,
                        icon       : Icons.person_outline,
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller : _qaSpvCtrl,
                        label      : 'QA SPV',
                        hint       : 'Nama QA Supervisor',
                        required   : true,
                        icon       : Icons.supervisor_account_outlined,
                        accentColor: _kPhase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian Harvest ──
                  GenSection(
                    title: 'Penilaian Harvest',
                    icon : Icons.agriculture_outlined,
                    color: _kPhase,
                    children: [
                      GenOptionPicker(
                        label      : 'Ear Condition (Maturity)',
                        required   : true,
                        options    : _earConditionOpts,
                        value      : _earCondition,
                        onChanged  : (v) => setState(() => _earCondition = v),
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Crop Condition',
                        required   : true,
                        options    : _cropCondOpts,
                        value      : _cropCondition,
                        onChanged  : (v) => setState(() => _cropCondition = v),
                        accentColor: _kPhase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Downgrade Flagging (collapsible) ──
                  _buildDowngradeSection(),
                  const SizedBox(height: 12),

                  // ── Section: Final Flagging ──
                  GenSection(
                    title: 'Final Flagging',
                    icon : Icons.flag_outlined,
                    color: const Color(0xFF42A5F5),
                    children: [
                      GenOptionPicker(
                        label      : 'Final Flagging',
                        required   : true,
                        options    : _finalFlaggingOpts,
                        value      : _finalFlagging,
                        onChanged  : (v) => setState(() => _finalFlagging = v),
                        accentColor: const Color(0xFF42A5F5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving : _isSaving,
            isDiscard: false,
            saveLabel: 'SIMPAN HARVEST AUDIT',
            onSave   : _save,
          ),
        ],
      ),
    );
  }

  // ── Downgrade Flagging (collapsible section) ──────────────
  Widget _buildDowngradeSection() {
    return Container(
      decoration: BoxDecoration(
        color: kGenSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _showDowngrade
              ? const Color(0xFFAB47BC).withValues(alpha: 0.60)
              : kGenBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (tapable toggle) ──
          InkWell(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _showDowngrade = !_showDowngrade),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.swap_vert_outlined,
                      color: _showDowngrade
                          ? const Color(0xFFCE93D8)
                          : kGenSub,
                      size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'DOWNGRADE FLAGGING',
                    style: TextStyle(
                      color: _showDowngrade
                          ? const Color(0xFFCE93D8)
                          : kGenSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _showDowngrade
                          ? const Color(0xFFAB47BC).withValues(alpha: 0.15)
                          : kGenBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _showDowngrade
                            ? const Color(0xFFAB47BC).withValues(alpha: 0.50)
                            : kGenBorder,
                      ),
                    ),
                    child: Text(
                      'Opsional',
                      style: TextStyle(
                        color: _showDowngrade
                            ? const Color(0xFFCE93D8)
                            : kGenSub,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _showDowngrade
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kGenSub,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_showDowngrade) ...[
            Container(height: 1, color: kGenBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Downgrade date
                  GenDateTileNullable(
                    label  : 'Tanggal Downgrade Flagging',
                    date   : _downgradeFlagDate,
                    onTap  : _pickDowngradeDate,
                    onClear: () =>
                        setState(() => _downgradeFlagDate = null),
                  ),
                  const SizedBox(height: 14),

                  // Status downgrade (Yes/No)
                  GenOptionPicker(
                    label      : 'Status Downgrade',
                    options    : _statusDowngradeOpts,
                    value      : _statusDowngrade,
                    onChanged  : (v) =>
                        setState(() => _statusDowngrade = v),
                    accentColor: const Color(0xFFAB47BC),
                  ),
                  const SizedBox(height: 14),

                  // Reason downgrade
                  GenOptionPickerLong(
                    label      : 'Reason Downgrade',
                    options    : _reasonDowngradeOpts,
                    value      : _reasonDowngrade,
                    onChanged  : (v) =>
                        setState(() => _reasonDowngrade = v),
                    accentColor: const Color(0xFFAB47BC),
                  ),
                  const SizedBox(height: 14),

                  // Downgrade flagging (RFI/RFD)
                  GenOptionPicker(
                    label      : 'Downgrade Flagging',
                    options    : _downgradeFlaggingOpts,
                    value      : _downgradeFlagging,
                    onChanged  : (v) =>
                        setState(() => _downgradeFlagging = v),
                    accentColor: const Color(0xFFAB47BC),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}