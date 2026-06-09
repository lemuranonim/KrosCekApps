// lib/screens/inspection/form_generative_4_sc.dart
//
// GENERATIVE AUDIT 4 — Process Check
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

// Gunakan warna ungu untuk CP4
const Color kGen4Color = Color(0xFF8E24AA);

class FormGenerative4SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative4SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative4SC> createState() => _FormGenerative4SCState();
}

class _FormGenerative4SCState extends ConsumerState<FormGenerative4SC> {
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
  final _remarksCtrl = TextEditingController();

  // Date
  DateTime _auditDate = DateTime.now();
  DateTime _actualDtDate = DateTime.now();
  DateTime _auditFiDate = DateTime.now();
  DateTime _auditHelperDate = DateTime.now();

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _roguingStatus;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _actionNeeded;

  bool get _isGuest => GuestGuard.isGuest(_session);
  bool get _isDiscard => genIsDiscardFull(_actionNeeded);

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
    _qaFiCtrl.text = audit['qa_fi_4'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv'] ?? '';
    _actualTkdCtrl.text = audit['actual_tkd_4']?.toString() ?? '';
    _auditHelperCtrl.text = audit['audit_helper_4'] ?? '';
    _remarksCtrl.text = audit['remarks_4'] ?? '';
    if (audit['date_of_audit_4'] != null) {
      try {
        _auditDate = DateTime.parse(audit['date_of_audit_4']);
      } catch (_) {}
    }
    _actualDtDate = _readAuditDate(audit['actual_dt_date_4']) ?? _auditDate;
    _auditFiDate = _readAuditDate(audit['audit_fi_date_4']) ?? _auditDate;
    _auditHelperDate =
        _readAuditDate(audit['audit_helper_date_4']) ?? _auditDate;
    setState(() {
      _femaleShed = audit['female_shedding_4'];
      _offtypeM = audit['offtype_m_4'];
      _offtypeF = audit['offtype_f_4'];
      _roguingStatus = audit['roguing_status_4'];
      _lsv = audit['lsv_status_4'];
      _cropUniformity = audit['crop_uniformity_4'];
      _cropHealth = audit['crop_health_4'];
      _actionNeeded = audit['action_needed_4'];
    });
  }

  Future<void> _pickDate() async {
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
        data: genDatePickerTheme(ctx, kGen4Color),
        child: child!,
      ),
    );
    if (p != null) _setAuditDate(p);
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
        data: genDatePickerTheme(ctx, kGen4Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => onPicked(p));
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final data = {
        'field_number': widget.fieldNumber,
        'date_of_audit_4': DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_4': calcAuditWeek(_auditDate),
        'female_shedding_4': _femaleShed,
        'offtype_m_4': _offtypeM,
        'offtype_f_4': _offtypeF,
        'roguing_status_4': _roguingStatus,
        'lsv_status_4': _lsv,
        'crop_uniformity_4': _cropUniformity,
        'crop_health_4': _cropHealth,
        'action_needed_4': _actionNeeded,
        'remarks_4': _remarksCtrl.text.trim(),
        'qa_fi_4': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'actual_tkd_4': int.tryParse(_actualTkdCtrl.text.trim()),
        'audit_helper_4': _auditHelperCtrl.text.trim(),
        'actual_dt_date_4': DateFormat('yyyy-MM-dd').format(_actualDtDate),
        'audit_fi_date_4': DateFormat('yyyy-MM-dd').format(_auditFiDate),
        'audit_helper_date_4': _auditHelperCtrl.text.trim().isEmpty
            ? null
            : DateFormat('yyyy-MM-dd').format(_auditHelperDate),
        'submitted_at_4': now.toIso8601String(),
        'fase': 'generative_4',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint: 4,
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
          phase: 'generative_4',
          actionType: 'single_submit',
          lat: lat,
          lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldDetailProvider(widget.fieldNumber));
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 4 berhasil disimpan ✓');
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
      'date_of_audit_4': DateFormat('yyyy-MM-dd').format(_auditDate),
      'week_of_audit_4': calcAuditWeek(_auditDate),
      'female_shedding_4': _femaleShed,
      'offtype_m_4': _offtypeM,
      'offtype_f_4': _offtypeF,
      'roguing_status_4': _roguingStatus,
      'lsv_status_4': _lsv,
      'crop_uniformity_4': _cropUniformity,
      'crop_health_4': _cropHealth,
      'action_needed_4': _actionNeeded,
      'remarks_4': _remarksCtrl.text.trim(),
      'qa_fi_4': _qaFiCtrl.text.trim(),
      'qa_spv': _qaSpvCtrl.text.trim(),
      'actual_tkd_4': int.tryParse(_actualTkdCtrl.text.trim()),
      'audit_helper_4': _auditHelperCtrl.text.trim(),
      'actual_dt_date_4': DateFormat('yyyy-MM-dd').format(_actualDtDate),
      'audit_fi_date_4': DateFormat('yyyy-MM-dd').format(_auditFiDate),
      'audit_helper_date_4': _auditHelperCtrl.text.trim().isEmpty
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
        passNumber: 4,
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
        checkpointLabel: 'Audit 4 (SC) – Process Check',
        fieldNumber: widget.fieldNumber,
        isDiscard: _isDiscard,
        accentColor: kGen4Color,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () => AdvantaLoadingState(
            title: 'Memuat form audit',
            subtitle: 'Mengambil data inspeksi',
            accentColor: kGen4Color,
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
                  GenFieldCard(fieldData: fd, accentColor: kGen4Color),
                  const SizedBox(height: 8),

                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: kGen4Color,
                    children: [
                      GenDateTile(
                          label: 'Tanggal Audit',
                          date: _auditDate,
                          onTap: _pickDate),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaFiCtrl,
                        label: 'QA FI',
                        hint: 'Nama QA Field Inspector',
                        column: 'qa_fi',
                        required: !_isGuest,
                        icon: Icons.person_outline,
                        accentColor: kGen4Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: kGen4Color,
                      ),
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _actualTkdCtrl,
                        label: 'Aktual TKD',
                        hint: 'Jumlah tenaga kerja aktual',
                        keyboardType: TextInputType.number,
                        icon: Icons.engineering_outlined,
                        accentColor: kGen4Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _auditHelperCtrl,
                        label: 'Audit Helper',
                        hint: 'Nama helper audit',
                        column: 'qa_fi',
                        icon: Icons.group_add_outlined,
                        accentColor: kGen4Color,
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
                    color: kGen4Color,
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
                        accentColor: kGen4Color,
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
                              accentColor: kGen4Color,
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
                              accentColor: kGen4Color,
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
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _roguingStatus = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen4Color,
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
                        accentColor: kGen4Color,
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
                        accentColor: kGen4Color,
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
                        accentColor: kGen4Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Action Needed ──
                  GenSection(
                    title: 'Action Needed',
                    icon: Icons.notification_important_outlined,
                    color: kGen4Color,
                    children: [
                      GenOptionPickerLong(
                        label: 'Action Needed',
                        required: !_isGuest,
                        options: genActionNeededOpts,
                        value: _actionNeeded,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _actionNeeded = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen4Color,
                      ),
                      if (_isDiscard && !_isGuest) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message:
                              'Action Discard Full dipilih — pastikan semua field wajib telah terisi.',
                        ),
                      ],
                      const SizedBox(height: 14),
                      GenTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        hint: 'Catatan untuk action needed...',
                        required:
                            genActionNeedsRemarks(_actionNeeded) && !_isGuest,
                        maxLines: 3,
                        icon: Icons.edit_note_outlined,
                        accentColor: kGen4Color,
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
                : (_isDiscard
                    ? 'SIMPAN — DISCARD FULL'
                    : 'SIMPAN GEN-4 PROCESS'),
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
