// lib/screens/inspection/form_generative_3.dart
//
// GENERATIVE AUDIT 3 — Final Audit
// Kolom: Audit Date · Audit Week · Female Shedding · Offtype M · Offtype F
//        LSV Status · Crop Condition · Detasseling Assessment ·
//        Isolation Status · Affected Other Field · Closed Out Date ·
//        Flagging · Final Decision · Discard Area (Ha) · Discard Reason
// DB table: audit_generative — suffix _3 columns
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import 'generative_form_widgets.dart';

class FormGenerative3 extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative3({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative3> createState() => _FormGenerative3State();
}

class _FormGenerative3State extends ConsumerState<FormGenerative3> {
  final _formKey   = GlobalKey<FormState>();
  bool _isSaving   = false;
  bool _dataLoaded = false;

  // Controllers
  final _qaFiCtrl       = TextEditingController();
  final _qaSpvCtrl      = TextEditingController();
  final _discardAreaCtrl = TextEditingController();
  final _discardReasonCtrl = TextEditingController();

  // Dates
  DateTime  _auditDate    = DateTime.now();
  DateTime? _closedOutDate;

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _lsv;
  String? _cropCond;
  String? _detasseling;
  String? _isolationStatus;
  String? _affectedOther;
  String? _flagging;
  String? _finalDecision;

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    _discardAreaCtrl.dispose();
    _discardReasonCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text = audit['qa_fi_3'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv']  ?? '';
    _discardAreaCtrl.text =
        audit['discard_area_ha_3']?.toString() ?? '';
    _discardReasonCtrl.text = audit['discard_reason_3'] ?? '';

    if (audit['date_of_audit_3'] != null) {
      try { _auditDate = DateTime.parse(audit['date_of_audit_3']); } catch (_) {}
    }
    if (audit['closed_out_date'] != null) {
      try { _closedOutDate = DateTime.parse(audit['closed_out_date']); } catch (_) {}
    }

    setState(() {
      _femaleShed = audit['female_shedding_3'];
      _offtypeM = audit['offtype_m_3'];
      _offtypeF = audit['offtype_f_3'];
      _lsv = audit['lsv_status_3'];
      _cropCond = audit['crop_condition_3'];
      _detasseling = audit['detasseling_assesment_3'];   // note DB typo: assesment
      _isolationStatus = audit['isolation_status_3'];
      _affectedOther = audit['affected_other_field_3'];
      _flagging = audit['flagging'];
      _finalDecision = audit['final_decision_3'];
    });
  }

  Future<void> _pickAuditDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: kGen3Color, surface: kGenSurface),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _pickClosedDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _closedOutDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: kGen3Color, surface: kGenSurface),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _closedOutDate = p);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final isDiscard = _finalDecision == 'D';
      final now  = DateTime.now();
      final data = {
        'field_number'            : widget.fieldNumber,
        'date_of_audit_3'         : DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_3'         : calcAuditWeek(_auditDate),
        'female_shedding_3'       : _femaleShed,
        'offtype_m_3'             : _offtypeM,
        'offtype_f_3'             : _offtypeF,
        'lsv_status_3'            : _lsv,
        'crop_condition_3'        : _cropCond,
        'detasseling_assesment_3' : _detasseling,   // DB column typo preserved
        'isolation_status_3'      : _isolationStatus,
        'affected_other_field_3'  : _affectedOther,
        'closed_out_date'         : _closedOutDate != null
            ? DateFormat('yyyy-MM-dd').format(_closedOutDate!)
            : null,
        'flagging'                : _flagging,
        'final_decision_3'        : _finalDecision,
        'discard_area_ha_3'       : isDiscard
            ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.'))
            : null,
        'discard_reason_3'        : isDiscard
            ? _discardReasonCtrl.text.trim()
            : null,
        'action_needed_3'         : isDiscard ? 'G' : 'A',
        'qa_fi_3'                 : _qaFiCtrl.text.trim(),
        'qa_spv'                  : _qaSpvCtrl.text.trim(),
        'submitted_at_3'          : now.toIso8601String(),
        'fase'                    : 'generative_3',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint : 3,
        data       : data,
      );

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
          phase       : 'generative_3',
          actionType  : 'single_submit',
          lat: lat, lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 3 (Final) berhasil disimpan ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? kGenRed : kGenGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(generativeAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData  = fields.firstWhere(
            (f) => f['field_number'] == widget.fieldNumber, orElse: () => {});

    final isDiscard = _finalDecision == 'D';

    return Scaffold(
      backgroundColor: kGenBg,
      appBar: buildGenAppBar(
        checkpointLabel: 'Audit 3 – Final Audit',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : isDiscard,
        accentColor    : kGen3Color,
        onBack         : () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
        const Center(child: CircularProgressIndicator(color: kGen3Color)),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: kGenSub))),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fieldData, isDiscard);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fd, bool isDiscard) {
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
                  GenFieldCard(fieldData: fd, accentColor: kGen3Color),
                  const SizedBox(height: 14),

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon : Icons.assignment_outlined,
                    color: kGen3Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date : _auditDate,
                          onTap: _pickAuditDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller  : _qaFiCtrl,
                        label       : 'QA FI',
                        hint        : 'Nama QA Field Inspector',
                        required    : true,
                        icon        : Icons.person_outline,
                        accentColor : kGen3Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller  : _qaSpvCtrl,
                        label       : 'QA SPV',
                        hint        : 'Nama QA Supervisor',
                        required    : true,
                        icon        : Icons.supervisor_account_outlined,
                        accentColor : kGen3Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian Tanaman ──
                  GenSection(
                    title: 'Penilaian Tanaman',
                    icon : Icons.grass,
                    color: kGen3Color,
                    children: [
                      GenOptionPicker(
                        label      : 'Female Shedding',
                        required   : !isDiscard,
                        options    : genFemaleShedOpts,
                        value      : _femaleShed,
                        onChanged  : (v) => setState(() => _femaleShed = v),
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype M',
                              required   : !isDiscard,
                              options    : genOfftypeOpts,
                              value      : _offtypeM,
                              onChanged  : (v) => setState(() => _offtypeM = v),
                              accentColor: kGen3Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Offtype F',
                              required   : !isDiscard,
                              options    : genOfftypeOpts,
                              value      : _offtypeF,
                              onChanged  : (v) => setState(() => _offtypeF = v),
                              accentColor: kGen3Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'LSV Status',
                        required   : !isDiscard,
                        options    : genLsvOpts,
                        value      : _lsv,
                        onChanged  : (v) => setState(() => _lsv = v),
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Crop Condition',
                        required   : !isDiscard,
                        options    : genCropCondOpts,
                        value      : _cropCond,
                        onChanged  : (v) => setState(() => _cropCond = v),
                        accentColor: kGen3Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Detasseling & Isolasi ──
                  GenSection(
                    title: 'Detasseling & Isolasi',
                    icon : Icons.agriculture_outlined,
                    color: const Color(0xFFAB47BC),
                    children: [
                      GenOptionPicker(
                        label      : 'Detasseling Assessment',
                        required   : !isDiscard,
                        options    : genDetasselingOpts,
                        value      : _detasseling,
                        onChanged  : (v) => setState(() => _detasseling = v),
                        accentColor: const Color(0xFFAB47BC),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Isolation Status',
                              options    : genIsolationOpts,
                              value      : _isolationStatus,
                              onChanged  : (v) =>
                                  setState(() => _isolationStatus = v),
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label      : 'Affected Other Field',
                              options    : genAffectedOpts,
                              value      : _affectedOther,
                              onChanged  : (v) =>
                                  setState(() => _affectedOther = v),
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Closed Out Date
                      GenDateTileNullable(
                        label  : 'Closed Out Date (Opsional)',
                        date   : _closedOutDate,
                        onTap  : _pickClosedDate,
                        onClear: () => setState(() => _closedOutDate = null),
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
                        label      : 'Flagging',
                        options    : genFlaggingOpts,
                        value      : _flagging,
                        onChanged  : (v) => setState(() => _flagging = v),
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
                        options    : genFinalDecisionOpts,
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

                      // Discard fields (hanya jika Final Decision = D)
                      if (isDiscard) ...[
                        const SizedBox(height: 14),
                        const GenDiscardBanner(
                          message:
                          'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenTextField(
                          controller  : _discardAreaCtrl,
                          label       : 'Discard Area (Ha)',
                          hint        : 'Luas area discard',
                          required    : true,
                          keyboardType: TextInputType.number,
                          icon        : Icons.crop_landscape_outlined,
                          accentColor : kGenRed,
                        ),
                        const SizedBox(height: 12),
                        GenTextField(
                          controller  : _discardReasonCtrl,
                          label       : 'Discard Reason',
                          hint        : 'Alasan discard...',
                          required    : true,
                          maxLines    : 3,
                          icon        : Icons.notes_outlined,
                          accentColor : kGenRed,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving  : _isSaving,
            isDiscard : isDiscard,
            saveLabel : isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN GEN-3 (FINAL)',
            onSave    : _save,
          ),
        ],
      ),
    );
  }
}