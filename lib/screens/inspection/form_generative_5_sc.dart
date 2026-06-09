// lib/screens/inspection/form_generative_5_sc.dart
//
// GENERATIVE AUDIT 5 — Final Audit
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../services/detasseling_iso_export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/advanta_loading_state.dart';
import '../../utils/guest_guard.dart';
import 'sc_form_widgets.dart';

const Color kGen5Color = Color(0xFFE53935); // Merah karena ini Final Audit

class FormGenerative5SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative5SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative5SC> createState() => _FormGenerative5SCState();
}

class _FormGenerative5SCState extends ConsumerState<FormGenerative5SC> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isExportingIso = false;
  bool _dataLoaded = false;
  ActiveSession? _session;

  // Controllers
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _actualTkdCtrl = TextEditingController();
  final _auditHelperCtrl = TextEditingController();
  final _discardAreaCtrl = TextEditingController();
  final _discardReasonCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // Dates
  DateTime _auditDate = DateTime.now();
  DateTime _actualDtDate = DateTime.now();
  DateTime _auditFiDate = DateTime.now();
  DateTime _auditHelperDate = DateTime.now();
  DateTime? _closedOutDate;

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _detasseling;
  String? _isolationProblem;
  String? _affectedOther;
  String? _finalFlagging;
  String? _finalDecision;

  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isDiscard => genIsDiscardDecision(_finalDecision);

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
    _actualTkdCtrl.dispose();
    _auditHelperCtrl.dispose();
    _discardAreaCtrl.dispose();
    _discardReasonCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  DateTime? _readAuditDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  void _setAuditDate(DateTime date) {
    setState(() {
      _auditDate = date;
      _actualDtDate = date;
      _auditFiDate = date;
      _auditHelperDate = date;
    });
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text = audit['qa_fi_5'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv'] ?? '';
    _actualTkdCtrl.text = audit['actual_tkd_5']?.toString() ?? '';
    _auditHelperCtrl.text = audit['audit_helper_5'] ?? '';
    _discardAreaCtrl.text = audit['pld_area_ha_5']?.toString() ?? '';
    _discardReasonCtrl.text = audit['pld_reason_5'] ?? '';
    _remarksCtrl.text = audit['remarks_5'] ?? '';

    if (audit['date_of_audit_5'] != null) {
      try {
        _auditDate = DateTime.parse(audit['date_of_audit_5']);
      } catch (_) {}
    }
    _actualDtDate = _readAuditDate(audit['actual_dt_date_5']) ?? _auditDate;
    _auditFiDate = _readAuditDate(audit['audit_fi_date_5']) ?? _auditDate;
    _auditHelperDate =
        _readAuditDate(audit['audit_helper_date_5']) ?? _auditDate;
    if (audit['closed_out_date_5'] != null) {
      try {
        _closedOutDate = DateTime.parse(audit['closed_out_date_5']);
      } catch (_) {}
    }

    setState(() {
      _femaleShed = audit['female_shedding_5'];
      _offtypeM = audit['offtype_m_5'];
      _offtypeF = audit['offtype_f_5'];
      _lsv = audit['lsv_status_5'];
      _cropUniformity = audit['crop_uniformity_5'];
      _cropHealth = audit['crop_health_5'];
      _detasseling = audit['detasseling_assesment_5'];
      _isolationProblem = audit['isolation_problem_5'];
      _affectedOther = audit['affected_other_field_5'];
      _finalFlagging = audit['final_flagging_5'];
      _finalDecision = audit['final_decision_5'];
    });
  }

  Future<void> _pickAuditDate() async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final p = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: genDatePickerTheme(ctx, kGen5Color),
        child: child!,
      ),
    );
    if (p != null) _setAuditDate(p);
  }

  Future<void> _pickClosedDate() async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final p = await showDatePicker(
      context: context,
      initialDate: _closedOutDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: genDatePickerTheme(ctx, kGen5Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => _closedOutDate = p);
  }

  Future<void> _pickDetasselingDate(
    DateTime currentDate,
    ValueChanged<DateTime> onPicked,
  ) async {
    if (_isGuest) {
      GuestGuard.blockIfGuest(context, _session);
      return;
    }
    final p = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: genDatePickerTheme(ctx, kGen5Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => onPicked(p));
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (_closedOutDate == null) {
      _snack('Closed Out Date wajib diisi', err: true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final data = {
        'field_number': widget.fieldNumber,
        'date_of_audit_5': DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_5': calcAuditWeek(_auditDate),
        'female_shedding_5': _femaleShed,
        'offtype_m_5': _offtypeM,
        'offtype_f_5': _offtypeF,
        'lsv_status_5': _lsv,
        'crop_uniformity_5': _cropUniformity,
        'crop_health_5': _cropHealth,
        'detasseling_assesment_5': _detasseling,
        'isolation_problem_5': _isolationProblem,
        'affected_other_field_5': _affectedOther,
        'closed_out_date_5': _closedOutDate != null
            ? DateFormat('yyyy-MM-dd').format(_closedOutDate!)
            : null,
        'final_flagging_5': _finalFlagging,
        'final_decision_5': _finalDecision,
        'pld_area_ha_5': _isDiscard
            ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.'))
            : null,
        'pld_reason_5': _isDiscard ? _discardReasonCtrl.text.trim() : null,
        'remarks_5': _remarksCtrl.text.trim(),
        'qa_fi_5': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'actual_tkd_5': int.tryParse(_actualTkdCtrl.text.trim()),
        'audit_helper_5': _auditHelperCtrl.text.trim(),
        'actual_dt_date_5': DateFormat('yyyy-MM-dd').format(_actualDtDate),
        'audit_fi_date_5': DateFormat('yyyy-MM-dd').format(_auditFiDate),
        'audit_helper_date_5': _auditHelperCtrl.text.trim().isEmpty
            ? null
            : DateFormat('yyyy-MM-dd').format(_auditHelperDate),
        'submitted_at_5': now.toIso8601String(),
        'fase': 'generative_5',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint: 5,
        data: data,
      );

      // Activity Logging
      double lat = 0, lng = 0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final att = ref.read(attendanceProvider);
      if (att.isCheckedIn && att.attendanceId != null) {
        await svc.logActivity(
          attendanceId: att.attendanceId!,
          userId: _qaFiCtrl.text.trim().isNotEmpty
              ? _qaFiCtrl.text.trim()
              : 'unknown',
          fieldNumber: widget.fieldNumber,
          phase: 'generative_5',
          actionType: 'single_submit',
          lat: lat,
          lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldDetailProvider(widget.fieldNumber));
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 5 (Final) berhasil disimpan ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _isoAuditPayload(Map<String, dynamic> audit) {
    return {
      ...audit,
      'field_number': widget.fieldNumber,
      'date_of_audit_5': DateFormat('yyyy-MM-dd').format(_auditDate),
      'week_of_audit_5': calcAuditWeek(_auditDate),
      'female_shedding_5': _femaleShed,
      'offtype_m_5': _offtypeM,
      'offtype_f_5': _offtypeF,
      'lsv_status_5': _lsv,
      'crop_uniformity_5': _cropUniformity,
      'crop_health_5': _cropHealth,
      'detasseling_assesment_5': _detasseling,
      'isolation_problem_5': _isolationProblem,
      'affected_other_field_5': _affectedOther,
      'final_flagging_5': _finalFlagging,
      'final_decision_5': _finalDecision,
      'remarks_5': _remarksCtrl.text.trim(),
      'qa_fi_5': _qaFiCtrl.text.trim(),
      'qa_spv': _qaSpvCtrl.text.trim(),
      'actual_tkd_5': int.tryParse(_actualTkdCtrl.text.trim()),
      'audit_helper_5': _auditHelperCtrl.text.trim(),
      'actual_dt_date_5': DateFormat('yyyy-MM-dd').format(_actualDtDate),
      'audit_fi_date_5': DateFormat('yyyy-MM-dd').format(_auditFiDate),
      'audit_helper_date_5': _auditHelperCtrl.text.trim().isEmpty
          ? null
          : DateFormat('yyyy-MM-dd').format(_auditHelperDate),
    };
  }

  Future<void> _downloadIsoForm(
    Map<String, dynamic> fieldData,
    Map<String, dynamic> audit, {
    required bool asPdf,
  }) async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (fieldData.isEmpty) {
      _snack('Data lahan belum tersedia untuk ISO Form', err: true);
      return;
    }

    setState(() => _isExportingIso = true);
    try {
      final payload = DetasselingIsoFormData(
        fieldData: fieldData,
        auditData: _isoAuditPayload(audit),
        passNumber: 5,
        cropLabel: 'SC',
      );
      final path = asPdf
          ? await DetasselingIsoExportService.downloadPdf(payload)
          : await DetasselingIsoExportService.downloadPicture(payload);
      if (mounted) _snack('ISO Form tersimpan: $path');
    } catch (e) {
      if (mounted) _snack('Gagal generate ISO Form: $e', err: true);
    } finally {
      if (mounted) setState(() => _isExportingIso = false);
    }
  }

  void _snack(String msg, {bool err = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(generativeAuditProvider(widget.fieldNumber));
    final fieldData =
        ref.watch(masterFieldDetailProvider(widget.fieldNumber)).value ??
            const <String, dynamic>{};

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Audit 5 (SC) – Final Audit',
        fieldNumber: widget.fieldNumber,
        isDiscard: _isDiscard,
        accentColor: kGen5Color,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => AdvantaLoadingState(
            title: 'Memuat form audit',
            subtitle: 'Mengambil data inspeksi',
            accentColor: kGen5Color,
            icon: Icons.assignment_rounded),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fieldData, audit ?? const {});
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> fd, Map<String, dynamic> audit) {
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
                  GenFieldCard(fieldData: fd, accentColor: kGen5Color),
                  const SizedBox(height: 8),

                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: kGen5Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date: _auditDate,
                          onTap: _pickAuditDate),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaFiCtrl,
                        label: 'QA FI',
                        hint: 'Nama QA Field Inspector',
                        column: 'qa_fi',
                        required: !_isGuest,
                        icon: Icons.person_outline,
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _actualTkdCtrl,
                        label: 'Aktual TKD',
                        hint: 'Jumlah tenaga kerja aktual',
                        keyboardType: TextInputType.number,
                        icon: Icons.engineering_outlined,
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _auditHelperCtrl,
                        label: 'Audit Helper',
                        hint: 'Nama helper audit',
                        column: 'qa_fi',
                        icon: Icons.group_add_outlined,
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 12),
                      GenDateTile(
                        label: 'Aktual DT Date',
                        date: _actualDtDate,
                        required: false,
                        onTap: () => _pickDetasselingDate(
                          _actualDtDate,
                          (date) => _actualDtDate = date,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GenDateTile(
                        label: 'Audit Date FI',
                        date: _auditFiDate,
                        required: false,
                        onTap: () => _pickDetasselingDate(
                          _auditFiDate,
                          (date) => _auditFiDate = date,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GenDateTile(
                        label: 'Audit Date Helper',
                        date: _auditHelperDate,
                        required: false,
                        onTap: () => _pickDetasselingDate(
                          _auditHelperDate,
                          (date) => _auditHelperDate = date,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian Process ──
                  GenSection(
                    title: 'Penilaian Process',
                    icon: Icons.grass_outlined,
                    color: kGen5Color,
                    children: [
                      // Female Shedding
                      GenOptionPicker(
                        label: 'Female Shedding',
                        required: !_isDiscard && !_isGuest,
                        options: genFemaleShedOpts,
                        value: _femaleShed,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _femaleShed = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 14),

                      // Offtype M & F
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Offtype M',
                              required: !_isDiscard && !_isGuest,
                              options: genOfftypeOpts,
                              value: _offtypeM,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _offtypeM = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: kGen5Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Offtype F',
                              required: !_isDiscard && !_isGuest,
                              options: genOfftypeOpts,
                              value: _offtypeF,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _offtypeF = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: kGen5Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // LSV Status
                      GenOptionPicker(
                        label: 'LSV Status',
                        required: !_isDiscard && !_isGuest,
                        options: genLsvOpts,
                        value: _lsv,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _lsv = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 14),

                      // Crop Uniformity
                      GenOptionPicker(
                        label: 'Crop Uniformity',
                        required: !_isDiscard && !_isGuest,
                        options: genCropUniformityOpts,
                        value: _cropUniformity,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropUniformity = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen5Color,
                      ),
                      const SizedBox(height: 14),

                      // Crop Health
                      GenOptionPicker(
                        label: 'Crop Health (Bulai, Hawar) % dari Populasi',
                        required: !_isDiscard && !_isGuest,
                        options: genCropHealthOpts,
                        value: _cropHealth,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropHealth = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen5Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Detasseling & Isolasi ──
                  GenSection(
                    title: 'Detasseling & Isolasi',
                    icon: Icons.agriculture_outlined,
                    color: const Color(0xFFAB47BC),
                    children: [
                      GenOptionPicker(
                        label: 'Detasseling Assessment',
                        required: !_isGuest,
                        options: genDetasselingOpts,
                        value: _detasseling,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _detasseling = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: const Color(0xFFAB47BC),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Isolation Problem',
                              required: !_isGuest,
                              options: genAffectedOpts,
                              value: _isolationProblem,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _isolationProblem = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Affected Other Field',
                              required: !_isGuest,
                              options: genAffectedOpts,
                              value: _affectedOther,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _affectedOther = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: const Color(0xFFAB47BC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GenDateTileNullable(
                        label: 'Closed Out Date *',
                        date: _closedOutDate,
                        onTap: _pickClosedDate,
                        onClear: _isGuest
                            ? () => GuestGuard.blockIfGuest(context, _session)
                            : () => setState(() => _closedOutDate = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Keputusan Final ──
                  GenSection(
                    title: 'Keputusan Final',
                    icon: Icons.gavel_outlined,
                    color: kGen5Color,
                    children: [
                      GenOptionPicker(
                        label: 'Final Flagging',
                        required: !_isGuest,
                        options: genFlaggingOpts,
                        value: _finalFlagging,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _finalFlagging = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: const Color(0xFF42A5F5),
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Final Decision',
                        required: !_isGuest,
                        options: genFinalDecisionOpts,
                        value: _finalDecision,
                        onChanged: (v) {
                          if (_isGuest) {
                            GuestGuard.blockIfGuest(context, _session);
                            return;
                          }
                          setState(() {
                            _finalDecision = v;
                            if (!genIsDiscardDecision(v)) {
                              _discardAreaCtrl.clear();
                              _discardReasonCtrl.clear();
                            }
                          });
                        },
                        accentColor: kGen5Color,
                      ),
                      if (_isDiscard && !_isGuest) ...[
                        const SizedBox(height: 14),
                        const GenDiscardBanner(
                          message:
                              'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenTextField(
                          controller: _discardAreaCtrl,
                          label: 'Discard Area (Ha)',
                          hint: 'Luas area discard',
                          required: true,
                          keyboardType: TextInputType.number,
                          icon: Icons.crop_landscape_outlined,
                          accentColor: kGen5Color,
                        ),
                        const SizedBox(height: 12),
                        GenTextField(
                          controller: _discardReasonCtrl,
                          label: 'Discard Reason',
                          hint: 'Alasan discard...',
                          required: true,
                          maxLines: 3,
                          icon: Icons.notes_outlined,
                          accentColor: kGen5Color,
                        ),
                      ],
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        hint: 'Catatan tambahan...',
                        maxLines: 2,
                        icon: Icons.comment_outlined,
                        accentColor: kGen5Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  GenSection(
                    title: 'ISO Output',
                    icon: Icons.description_outlined,
                    color: AdvantaColors.primaryGreen,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _IsoExportButton(
                            icon: Icons.image_outlined,
                            label: 'Generate ISO Picture',
                            busy: _isExportingIso,
                            onTap: () => _downloadIsoForm(
                              fd,
                              audit,
                              asPdf: false,
                            ),
                          ),
                          _IsoExportButton(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'Generate ISO PDF',
                            busy: _isExportingIso,
                            onTap: () => _downloadIsoForm(
                              fd,
                              audit,
                              asPdf: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GenSaveBar(
            isSaving: _isSaving,
            isDiscard: _isDiscard && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY'
                : (_isDiscard ? 'SIMPAN — DISCARD' : 'SIMPAN GEN-5 (FINAL)'),
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _save,
          ),
        ],
      ),
    );
  }
}

class _IsoExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _IsoExportButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AdvantaColors.primaryGreen,
          side: BorderSide(color: AdvantaColors.primaryGreen.withAlpha(130)),
          textStyle: AdvantaText.button.copyWith(fontSize: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: AdvantaRadius.buttonRadius,
          ),
        ),
      ),
    );
  }
}
