// lib/screens/inspection/form_generative_3.dart
//
// GENERATIVE AUDIT 3 — Final Audit
// PERUBAHAN: Guest role → read-only, tombol Save diblokir
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';   // ← NEW
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';           // ← NEW
import 'sc_form_widgets.dart';

class FormGenerative3SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative3SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative3SC> createState() => _FormGenerative3SCState();
}

class _FormGenerative3SCState extends ConsumerState<FormGenerative3SC> {
  final _formKey           = GlobalKey<FormState>();
  bool _isSaving           = false;
  bool _dataLoaded         = false;

  // ── NEW: session untuk GuestGuard ────────────────────────
  ActiveSession? _session;

  // Controllers
  final _qaFiCtrl          = TextEditingController();
  final _qaSpvCtrl         = TextEditingController();
  final _discardAreaCtrl   = TextEditingController();
  final _discardReasonCtrl = TextEditingController();

  // Dates
  DateTime  _auditDate    = DateTime.now();
  DateTime? _closedOutDate;

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _roguingStatus;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _detasseling;
  String? _isolationStatus;
  String? _affectedOther;
  String? _flagging;
  String? _actionNeeded;
  String? _finalDecision;

  // ── NEW ──────────────────────────────────────────────────
  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isDiscard => _finalDecision == 'D';

  @override
  void initState() {
    super.initState();
    SessionManager.instance.getActiveSession().then((s) {
      if (mounted) setState(() => _session = s);
    });
  }

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
    _qaFiCtrl.text           = audit['qa_fi_3'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text          = audit['qa_spv']  ?? '';
    _discardAreaCtrl.text    = audit['discard_area_ha_3']?.toString() ?? '';
    _discardReasonCtrl.text  = audit['discard_reason_3'] ?? '';

    if (audit['date_of_audit_3'] != null) {
      try { _auditDate = DateTime.parse(audit['date_of_audit_3']); } catch (_) {}
    }
    if (audit['closed_out_date'] != null) {
      try { _closedOutDate = DateTime.parse(audit['closed_out_date']); } catch (_) {}
    }

    setState(() {
      _femaleShed      = audit['female_shedding_3'];
      _offtypeM        = audit['offtype_m_3'];
      _offtypeF        = audit['offtype_f_3'];
      _roguingStatus   = audit['roguing_status_3'];
      _lsv             = audit['lsv_status_3'];
      _cropUniformity  = audit['crop_uniformity_3'];
      _cropHealth      = audit['crop_health_3'];
      _detasseling     = audit['detasseling_assesment_3']; // DB column typo preserved
      _isolationStatus = audit['isolation_status_3'];
      _affectedOther   = audit['affected_other_field_3'];
      _flagging        = audit['flagging'];
      _actionNeeded    = audit['action_needed_3'];
      _finalDecision   = audit['final_decision_3'];
    });
  }

  Future<void> _pickAuditDate() async {
    if (_isGuest) { GuestGuard.blockIfGuest(context, _session); return; }
    final p = await showDatePicker(
      context:     context,
      initialDate: _auditDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder:     (ctx, child) => Theme(
        data:  genDatePickerTheme(ctx, kGen3Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _pickClosedDate() async {
    if (_isGuest) { GuestGuard.blockIfGuest(context, _session); return; }
    final p = await showDatePicker(
      context:     context,
      initialDate: _closedOutDate ?? DateTime.now(),
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2100),
      builder:     (ctx, child) => Theme(
        data:  genDatePickerTheme(ctx, kGen3Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => _closedOutDate = p);
  }

  Future<void> _save() async {
    // ── GUARD ────────────────────────────────────────────
    if (GuestGuard.blockIfGuest(context, _session)) return;

    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now  = DateTime.now();
      final data = {
        'field_number'            : widget.fieldNumber,
        'date_of_audit_3'         : DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_3'         : calcAuditWeek(_auditDate),
        'female_shedding_3'       : _femaleShed,
        'offtype_m_3'             : _offtypeM,
        'offtype_f_3'             : _offtypeF,
        'roguing_status_3'        : _roguingStatus,
        'lsv_status_3'            : _lsv,
        'crop_uniformity_3'       : _cropUniformity,
        'crop_health_3'           : _cropHealth,
        'detasseling_assesment_3' : _detasseling, // DB column typo preserved
        'isolation_status_3'      : _isolationStatus,
        'affected_other_field_3'  : _affectedOther,
        'closed_out_date'         : _closedOutDate != null
            ? DateFormat('yyyy-MM-dd').format(_closedOutDate!)
            : null,
        'flagging'                : _flagging,
        'final_decision_3'        : _finalDecision,
        'discard_area_ha_3'       : _isDiscard
            ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.'))
            : null,
        'discard_reason_3'        : _isDiscard
            ? _discardReasonCtrl.text.trim()
            : null,
        'action_needed_3'         : _actionNeeded,
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
              accuracy:  LocationAccuracy.high,
              timeLimit: Duration(seconds: 5)),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final att = ref.read(attendanceProvider);
      if (att.isCheckedIn && att.attendanceId != null) {
        await svc.logActivity(
          attendanceId: att.attendanceId!,
          userId:       _qaFiCtrl.text.trim().isNotEmpty
              ? _qaFiCtrl.text.trim() : 'unknown',
          fieldNumber:  widget.fieldNumber,
          phase:        'generative_3',
          actionType:   'single_submit',
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
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg,
          style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin:          const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(generativeAuditProvider(widget.fieldNumber));
    final fields     = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData  = fields.firstWhere(
            (f) => f['field_number'] == widget.fieldNumber,
        orElse: () => {});

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Audit 3 (SC) – Process Check',
        fieldNumber:     widget.fieldNumber,
        isDiscard:       _isDiscard,
        accentColor:     kGen3Color,
        onBack:          () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: kGen3Color)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AdvantaText.body2.copyWith(
                    color: Theme.of(context).colorScheme.error))),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fieldData);
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
                  GenFieldCard(fieldData: fd, accentColor: kGen3Color),
                  const SizedBox(height: 8),

                  // ── Guest banner ──────────────────────────
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon:  Icons.assignment_outlined,
                    color: kGen3Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date:  _auditDate,
                          onTap: _pickAuditDate),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller:  _qaFiCtrl,
                        label:       'QA FI',
                        hint:        'Nama QA Field Inspector',
                        required:    !_isGuest,
                        icon:        Icons.person_outline,
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller:  _qaSpvCtrl,
                        label:       'QA SPV',
                        hint:        'Nama QA Supervisor',
                        required:    !_isGuest,
                        icon:        Icons.supervisor_account_outlined,
                        accentColor: kGen3Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian Process ──
                  GenSection(
                    title: 'Penilaian Process',
                    icon:  Icons.grass_outlined,
                    color: kGen3Color,
                    children: [
                      // Female Shedding
                      GenOptionPicker(
                        label:       'Female Shedding',
                        required:    !_isDiscard && !_isGuest,
                        options:     genFemaleShedOpts,
                        value:       _femaleShed,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _femaleShed = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),

                      // Offtype M & F
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label:       'Offtype M',
                              required:    !_isDiscard && !_isGuest,
                              options:     genOfftypeOpts,
                              value:       _offtypeM,
                              onChanged:   (v) { if (!_isGuest) {
                                setState(() => _offtypeM = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: kGen3Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label:       'Offtype F',
                              required:    !_isDiscard && !_isGuest,
                              options:     genOfftypeOpts,
                              value:       _offtypeF,
                              onChanged:   (v) { if (!_isGuest) {
                                setState(() => _offtypeF = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: kGen3Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Roguing Status
                      GenOptionPicker(
                        label: 'Roguing Status',
                        required: !_isDiscard && !_isGuest,
                        options: genRoguingStatusOpts,
                        value: _roguingStatus,
                        onChanged: (v) { if (!_isGuest) {
                          setState(() => _roguingStatus = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),

                      // LSV Status
                      GenOptionPicker(
                        label:       'LSV Status',
                        required:    !_isDiscard && !_isGuest,
                        options:     genLsvOpts,
                        value:       _lsv,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _lsv = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),

                      // Crop Uniformity
                      GenOptionPicker(
                        label:       'Crop Uniformity',
                        required:    !_isDiscard && !_isGuest,
                        options:     genCropUniformityOpts,
                        value:       _cropUniformity,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _cropUniformity = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                      const SizedBox(height: 14),

                      // Crop Health
                      GenOptionPicker(
                        label:       'Crop Health',
                        required:    !_isDiscard && !_isGuest,
                        options:     genCropHealthOpts,
                        value:       _cropHealth,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _cropHealth = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Detasseling & Isolasi ──
                  GenSection(
                    title: 'Detasseling & Isolasi',
                    icon:  Icons.agriculture_outlined,
                    color: const Color(0xFFAB47BC),
                    children: [
                      GenOptionPicker(
                        label:       'Detasseling Assessment',
                        required:    !_isGuest,
                        options:     genDetasselingOpts,
                        value:       _detasseling,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _detasseling = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFFAB47BC),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label:      'Isolation Status',
                              options:    genIsolationOpts,
                              value:      _isolationStatus,
                              onChanged:  (v) { if (!_isGuest) {
                                setState(() => _isolationStatus = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label:      'Affected Other Field',
                              options:    genAffectedOpts,
                              value:      _affectedOther,
                              onChanged:  (v) { if (!_isGuest) {
                                setState(() => _affectedOther = v);
                              } else {
                                GuestGuard.blockIfGuest(context, _session);
                              } },
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      GenDateTileNullable(
                        label:   'Closed Out Date (Opsional)',
                        date:    _closedOutDate,
                        onTap:   _pickClosedDate,
                        onClear: _isGuest
                            ? () => GuestGuard.blockIfGuest(context, _session)
                            : () => setState(() => _closedOutDate = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Action Needed ──
                  GenSection(
                    title: 'Action Needed',
                    icon:  Icons.notification_important_outlined,
                    color: kGen3Color,
                    children: [
                      GenOptionPickerLong(
                        label:       'Action Needed',
                        required:    !_isGuest,
                        options:     genActionNeededOpts,
                        value:       _actionNeeded,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _actionNeeded = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: kGen3Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Flagging ──
                  GenSection(
                    title: 'Flagging',
                    icon:  Icons.flag_outlined,
                    color: const Color(0xFF42A5F5),
                    children: [
                      GenOptionPicker(
                        label:       'Flagging',
                        required:    !_isGuest,
                        options:     genFlaggingOpts,
                        value:       _flagging,
                        onChanged:   (v) { if (!_isGuest) {
                          setState(() => _flagging = v);
                        } else {
                          GuestGuard.blockIfGuest(context, _session);
                        } },
                        accentColor: const Color(0xFF42A5F5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Keputusan Final ──
                  GenSection(
                    title: 'Keputusan Final',
                    icon:  Icons.gavel_outlined,
                    color: AdvantaColors.error,
                    children: [
                      GenOptionPicker(
                        label:       'Final Decision',
                        required:    !_isGuest,
                        options:     genFinalDecisionOpts,
                        value:       _finalDecision,
                        onChanged:   (v) {
                          if (_isGuest) {
                            GuestGuard.blockIfGuest(context, _session);
                            return;
                          }
                          setState(() {
                            _finalDecision = v;
                            if (v != 'D') {
                              _discardAreaCtrl.clear();
                              _discardReasonCtrl.clear();
                            }
                          });
                        },
                        accentColor: AdvantaColors.error,
                      ),

                      if (_isDiscard && !_isGuest) ...[
                        const SizedBox(height: 14),
                        const GenDiscardBanner(
                          message:
                          'Final Decision Discard — isi Discard Area & '
                              'Reason sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenTextField(
                          controller:   _discardAreaCtrl,
                          label:        'Discard Area (Ha)',
                          hint:         'Luas area discard',
                          required:     true,
                          keyboardType: TextInputType.number,
                          icon:         Icons.crop_landscape_outlined,
                          accentColor:  AdvantaColors.error,
                        ),
                        const SizedBox(height: 12),
                        GenTextField(
                          controller:  _discardReasonCtrl,
                          label:       'Discard Reason',
                          hint:        'Alasan discard...',
                          required:    true,
                          maxLines:    3,
                          icon:        Icons.notes_outlined,
                          accentColor: AdvantaColors.error,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving:  _isSaving,
            isDiscard: _isDiscard && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY — TIDAK DAPAT MENYIMPAN'
                : (_isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN GEN-3 (FINAL)'),
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _save,
          ),
        ],
      ),
    );
  }
}