// lib/screens/inspection/form_pre_harvest.dart
//
// PRE-HARVEST AUDIT — Premium redesign
// Kolom: Audit Date · Audit Week · Male Chopping Rows ·
//        Final Flagging · Final Decision · Crop Condition ·
//        Discard Area (Ha) · Discard Reason
// DB table: audit_pre_harvest
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_pre_harvest_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import 'generative_form_widgets.dart';

// ─── Phase accent color ───────────────────────────────────
const _kPhase = Color(0xFF26C6DA); // Cyan — Pre-Harvest

// ─── Option lists ─────────────────────────────────────────
const _maleChoppingOpts = [
  GenOpt('A', 'A – Complete'),
  GenOpt('B', 'B – Not Complete'),
];

const _cropCondOpts = [
  GenOpt('1', '1 – Very Poor'),
  GenOpt('2', '2 – Poor'),
  GenOpt('3', '3 – Fair'),
  GenOpt('4', '4 – Good'),
  GenOpt('5', '5 – Best'),
];

const _finalFlaggingOpts = [
  GenOpt('GF',  'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF',  'BF'),
  GenOpt('PLD', 'PLD'),
];

const _finalDecisionOpts = [
  GenOpt('A', 'A – Pass'),
  GenOpt('B', 'B – Pass w/ Note'),
  GenOpt('C', 'C – Hold'),
  GenOpt('D', 'D – Discard'),
];

// ─────────────────────────────────────────────────────────
class FormPreHarvest extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormPreHarvest({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormPreHarvest> createState() => _FormPreHarvestState();
}

class _FormPreHarvestState extends ConsumerState<FormPreHarvest> {
  final _formKey  = GlobalKey<FormState>();
  bool _isSaving  = false;
  bool _dataLoaded = false;

  // Controllers
  final _qaFiCtrl        = TextEditingController();
  final _qaSpvCtrl       = TextEditingController();
  final _discardAreaCtrl  = TextEditingController();
  final _discardReasonCtrl = TextEditingController();

  // Date
  DateTime _auditDate = DateTime.now();

  // Dropdowns
  String? _maleChopping;
  String? _finalFlagging;
  String? _finalDecision;
  String? _cropCondition;

  bool get _isDiscard => _finalDecision == 'D';

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _discardAreaCtrl.dispose();
    _discardReasonCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> a) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text        = a['qa_fi']  ?? '';
    _qaSpvCtrl.text       = a['qa_spv'] ?? '';
    _discardAreaCtrl.text  = a['discard_area_ha']?.toString() ?? '';
    _discardReasonCtrl.text = a['discard_reason'] ?? '';
    if (a['audit_date'] != null) {
      try { _auditDate = DateTime.parse(a['audit_date']); } catch (_) {}
    }
    setState(() {
      _maleChopping  = a['male_chopping_rows'];
      _finalFlagging = a['final_flagging'];
      _finalDecision = a['final_decision'];
      _cropCondition = a['crop_condition'];
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = {
        'field_number'      : widget.fieldNumber,
        'audit_date'        : DateFormat('yyyy-MM-dd').format(_auditDate),
        'audit_week'        : calcAuditWeek(_auditDate),
        'male_chopping_rows': _maleChopping,
        'final_flagging'    : _finalFlagging,
        'final_decision'    : _finalDecision,
        'crop_condition'    : _cropCondition,
        'discard_area_ha'   : _isDiscard
            ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.'))
            : null,
        'discard_reason'    : _isDiscard
            ? _discardReasonCtrl.text.trim()
            : null,
        'qa_fi'             : _qaFiCtrl.text.trim(),
        'qa_spv'            : _qaSpvCtrl.text.trim(),
        'fase'              : 'Pre-Harvest',
        'updated_at'        : DateTime.now().toIso8601String(),
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertPreHarvestAudit(data);

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
          phase       : 'pre_harvest',
          actionType  : 'single_submit',
          lat: lat, lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(preharvestAuditProvider(widget.fieldNumber));
        _snack('Pre-Harvest Audit berhasil disimpan ✓');
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
    final auditAsync = ref.watch(preharvestAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fd         = fields.firstWhere(
            (f) => f['field_number'] == widget.fieldNumber, orElse: () => {});

    return Scaffold(
      backgroundColor: kGenBg,
      appBar: buildGenAppBar(
        checkpointLabel: 'Pre-Harvest Audit',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : _isDiscard,
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

                  // ── Section: Penilaian ──
                  GenSection(
                    title: 'Penilaian Pre-Harvest',
                    icon : Icons.checklist_outlined,
                    color: _kPhase,
                    children: [
                      GenOptionPicker(
                        label      : 'Male Chopping (Rows)',
                        required   : !_isDiscard,
                        options    : _maleChoppingOpts,
                        value      : _maleChopping,
                        onChanged  : (v) => setState(() => _maleChopping = v),
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Crop Condition',
                        required   : !_isDiscard,
                        options    : _cropCondOpts,
                        value      : _cropCondition,
                        onChanged  : (v) => setState(() => _cropCondition = v),
                        accentColor: _kPhase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Flagging ──
                  GenSection(
                    title: 'Flagging',
                    icon : Icons.flag_outlined,
                    color: const Color(0xFF42A5F5),
                    children: [
                      GenOptionPicker(
                        label      : 'Final Flagging',
                        options    : _finalFlaggingOpts,
                        value      : _finalFlagging,
                        onChanged  : (v) => setState(() => _finalFlagging = v),
                        accentColor: const Color(0xFF42A5F5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Keputusan Final ──
                  GenSection(
                    title: 'Keputusan Final',
                    icon : Icons.gavel_outlined,
                    color: kGenRed,
                    children: [
                      GenOptionPicker(
                        label      : 'Final Decision',
                        required   : true,
                        options    : _finalDecisionOpts,
                        value      : _finalDecision,
                        onChanged  : (v) {
                          setState(() {
                            _finalDecision = v;
                            if (v != 'D') {
                              _discardAreaCtrl.clear();
                              _discardReasonCtrl.clear();
                            }
                          });
                        },
                        accentColor: kGenRed,
                      ),
                      if (_isDiscard) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message:
                          'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenTextField(
                          controller : _discardAreaCtrl,
                          label      : 'Discard Area (Ha)',
                          hint       : 'Luas area discard',
                          required   : true,
                          keyboardType: TextInputType.number,
                          icon       : Icons.crop_landscape_outlined,
                          accentColor: kGenRed,
                        ),
                        const SizedBox(height: 12),
                        GenTextField(
                          controller : _discardReasonCtrl,
                          label      : 'Discard Reason',
                          hint       : 'Alasan discard...',
                          required   : true,
                          maxLines   : 3,
                          icon       : Icons.notes_outlined,
                          accentColor: kGenRed,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving : _isSaving,
            isDiscard: _isDiscard,
            saveLabel: _isDiscard
                ? 'SIMPAN — DISCARD PRE-HARVEST'
                : 'SIMPAN PRE-HARVEST',
            onSave   : _save,
          ),
        ],
      ),
    );
  }
}