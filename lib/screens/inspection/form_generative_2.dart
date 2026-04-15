// lib/screens/inspection/form_generative_2.dart
//
// GENERATIVE AUDIT 2 — Process Check
// Kolom: Audit Date · Audit Week · Female Shedding · Offtype M · Offtype F
//        LSV Status · Crop Condition · Action Needed
// DB table: audit_generative — suffix _2 columns
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import 'generative_form_widgets.dart';

class FormGenerative2 extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative2({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative2> createState() => _FormGenerative2State();
}

class _FormGenerative2State extends ConsumerState<FormGenerative2> {
  final _formKey  = GlobalKey<FormState>();
  bool _isSaving  = false;
  bool _dataLoaded = false;

  // Controllers
  final _qaFiCtrl  = TextEditingController();
  final _qaSpvCtrl = TextEditingController();

  // Date
  DateTime _auditDate = DateTime.now();

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _lsv;
  String? _cropCond;
  String? _actionNeeded;

  @override
  void dispose() {
    _qaFiCtrl.dispose();
    _qaSpvCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text  = audit['qa_fi_2'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv']  ?? '';
    if (audit['date_of_audit_2'] != null) {
      try { _auditDate = DateTime.parse(audit['date_of_audit_2']); } catch (_) {}
    }
    setState(() {
      _femaleShed   = audit['female_shedding_2'];
      _offtypeM     = audit['offtype_m_2'];
      _offtypeF     = audit['offtype_f_2'];
      _lsv          = audit['lsv_status_2'];
      _cropCond     = audit['crop_condition_2'];
      _actionNeeded = audit['action_needed_2'];
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
              primary: kGen2Color, surface: kGenSurface),
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
      final now  = DateTime.now();
      final data = {
        'field_number'      : widget.fieldNumber,
        'date_of_audit_2'   : DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_2'   : calcAuditWeek(_auditDate),
        'female_shedding_2' : _femaleShed,
        'offtype_m_2'       : _offtypeM,
        'offtype_f_2'       : _offtypeF,
        'lsv_status_2'      : _lsv,
        'crop_condition_2'  : _cropCond,
        'action_needed_2'   : _actionNeeded,
        'qa_fi_2'           : _qaFiCtrl.text.trim(),
        'qa_spv'            : _qaSpvCtrl.text.trim(),
        'submitted_at_2'    : now.toIso8601String(),
        'fase'              : 'generative_2',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint : 2,
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
          phase       : 'generative_2',
          actionType  : 'single_submit',
          lat: lat, lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 2 berhasil disimpan ✓');
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

    final isDiscard = _actionNeeded == 'G';

    return Scaffold(
      backgroundColor: kGenBg,
      appBar: buildGenAppBar(
        checkpointLabel: 'Audit 2 – Process Check',
        fieldNumber    : widget.fieldNumber,
        isDiscard      : isDiscard,
        accentColor    : kGen2Color,
        onBack         : () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
        const Center(child: CircularProgressIndicator(color: kGen2Color)),
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
                  GenFieldCard(fieldData: fd, accentColor: kGen2Color),
                  const SizedBox(height: 14),

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon : Icons.assignment_outlined,
                    color: kGen2Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date : _auditDate,
                          onTap: _pickDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller  : _qaFiCtrl,
                        label       : 'QA FI',
                        hint        : 'Nama QA Field Inspector',
                        required    : true,
                        icon        : Icons.person_outline,
                        accentColor : kGen2Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller  : _qaSpvCtrl,
                        label       : 'QA SPV',
                        hint        : 'Nama QA Supervisor',
                        required    : true,
                        icon        : Icons.supervisor_account_outlined,
                        accentColor : kGen2Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian ──
                  GenSection(
                    title: 'Penilaian Process',
                    icon : Icons.grass_outlined,
                    color: kGen2Color,
                    children: [
                      GenOptionPicker(
                        label      : 'Female Shedding',
                        required   : !isDiscard,
                        options    : genFemaleShedOpts,
                        value      : _femaleShed,
                        onChanged  : (v) => setState(() => _femaleShed = v),
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 14),

                      // Offtype M & F side by side
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
                              accentColor: kGen2Color,
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
                              accentColor: kGen2Color,
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
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label      : 'Crop Condition',
                        required   : !isDiscard,
                        options    : genCropCondOpts,
                        value      : _cropCond,
                        onChanged  : (v) => setState(() => _cropCond = v),
                        accentColor: kGen2Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Action Needed ──
                  GenSection(
                    title: 'Action Needed',
                    icon : Icons.gavel_outlined,
                    color: kGenRed,
                    children: [
                      GenOptionPickerLong(
                        label      : 'Action Needed',
                        required   : true,
                        options    : genActionNeededOpts,
                        value      : _actionNeeded,
                        onChanged  : (v) => setState(() => _actionNeeded = v),
                        accentColor: kGenRed,
                      ),
                      if (isDiscard) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message:
                          'Action Discard Full dipilih — hanya field wajib (QA FI, SPV, Tanggal) yang harus diisi.',
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
            saveLabel : isDiscard ? 'SIMPAN — DISCARD FULL' : 'SIMPAN GEN-2 PROCESS',
            onSave    : _save,
          ),
        ],
      ),
    );
  }
}