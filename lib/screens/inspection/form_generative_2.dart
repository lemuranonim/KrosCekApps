// lib/screens/inspection/form_generative_2.dart
//
// GENERATIVE AUDIT 2 — Process Check
// PERUBAHAN: Guest role → read-only, tombol Save diblokir
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_generative_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart'; // ← NEW
import '../../services/detasseling_iso_export_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart'; // ← NEW
import 'fc_form_widgets.dart';

class FormGenerative2 extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative2({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative2> createState() => _FormGenerative2State();
}

class _FormGenerative2State extends ConsumerState<FormGenerative2> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isExportingIso = false;
  bool _dataLoaded = false;

  // ── NEW: session untuk GuestGuard ────────────────────────
  ActiveSession? _session;

  // Controllers
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // Date
  DateTime _auditDate = DateTime.now();

  // Dropdowns
  String? _femaleShed;
  String? _offtypeM;
  String? _offtypeF;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _actionNeeded;

  // ── NEW ──────────────────────────────────────────────────
  bool get _isGuest => GuestGuard.isGuest(_session);

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
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> audit) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text = audit['qa_fi_2'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv'] ?? '';
    _remarksCtrl.text = audit['remarks_2'] ?? '';
    if (audit['date_of_audit_2'] != null) {
      try {
        _auditDate = DateTime.parse(audit['date_of_audit_2']);
      } catch (_) {}
    }
    setState(() {
      _femaleShed = audit['female_shedding_2'];
      _offtypeM = audit['offtype_m_2'];
      _offtypeF = audit['offtype_f_2'];
      _lsv = audit['lsv_status_2'];
      _cropUniformity = audit['crop_uniformity_2'];
      _cropHealth = audit['crop_health_2'];
      _actionNeeded = audit['action_needed_2'];
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
        data: genDatePickerTheme(ctx, kGen2Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
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
      final now = DateTime.now();
      final data = {
        'field_number': widget.fieldNumber,
        'date_of_audit_2': DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_2': calcAuditWeek(_auditDate),
        'female_shedding_2': _femaleShed,
        'offtype_m_2': _offtypeM,
        'offtype_f_2': _offtypeF,
        'lsv_status_2': _lsv,
        'crop_uniformity_2': _cropUniformity,
        'crop_health_2': _cropHealth,
        'action_needed_2': _actionNeeded,
        'remarks_2': _remarksCtrl.text.trim(),
        'qa_fi_2': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'submitted_at_2': now.toIso8601String(),
        'fase': 'generative_2',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint: 2,
        data: data,
      );

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
          phase: 'generative_2',
          actionType: 'single_submit',
          lat: lat,
          lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 2 berhasil disimpan ✓');
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
      'date_of_audit_2': DateFormat('yyyy-MM-dd').format(_auditDate),
      'week_of_audit_2': calcAuditWeek(_auditDate),
      'female_shedding_2': _femaleShed,
      'offtype_m_2': _offtypeM,
      'offtype_f_2': _offtypeF,
      'lsv_status_2': _lsv,
      'crop_uniformity_2': _cropUniformity,
      'crop_health_2': _cropHealth,
      'action_needed_2': _actionNeeded,
      'remarks_2': _remarksCtrl.text.trim(),
      'qa_fi_2': _qaFiCtrl.text.trim(),
      'qa_spv': _qaSpvCtrl.text.trim(),
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
        passNumber: 2,
        cropLabel: 'FC',
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
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
        (f) => f['field_number'] == widget.fieldNumber,
        orElse: () => {});

    final isDiscard = genIsDiscardFull(_actionNeeded);

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Audit 2 – Process Check',
        fieldNumber: widget.fieldNumber,
        isDiscard: isDiscard,
        accentColor: kGen2Color,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: kGen2Color)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AdvantaText.body2
                    .copyWith(color: Theme.of(context).colorScheme.error))),
        data: (audit) {
          if (audit != null) _loadAudit(audit);
          return _buildBody(fieldData, isDiscard, audit ?? const {});
        },
      ),
    );
  }

  Widget _buildBody(
      Map<String, dynamic> fd, bool isDiscard, Map<String, dynamic> audit) {
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
                  const SizedBox(height: 8),

                  // ── Guest banner ──────────────────────────
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: kGen2Color,
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
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: kGen2Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian Process ──
                  GenSection(
                    title: 'Penilaian Process',
                    icon: Icons.grass_outlined,
                    color: kGen2Color,
                    children: [
                      GenOptionPicker(
                        label: 'Female Shedding',
                        required: !isDiscard && !_isGuest,
                        options: genFemaleShedOpts,
                        value: _femaleShed,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _femaleShed = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Offtype M',
                              required: !isDiscard && !_isGuest,
                              options: genOfftypeOpts,
                              value: _offtypeM,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _offtypeM = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: kGen2Color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GenOptionPicker(
                              label: 'Offtype F',
                              required: !isDiscard && !_isGuest,
                              options: genOfftypeOpts,
                              value: _offtypeF,
                              onChanged: (v) {
                                if (!_isGuest) {
                                  setState(() => _offtypeF = v);
                                } else {
                                  GuestGuard.blockIfGuest(context, _session);
                                }
                              },
                              accentColor: kGen2Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'LSV Status',
                        required: !isDiscard && !_isGuest,
                        options: genLsvOpts,
                        value: _lsv,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _lsv = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Uniformity',
                        required: !isDiscard && !_isGuest,
                        options: genCropUniformityOpts,
                        value: _cropUniformity,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropUniformity = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen2Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Health',
                        required: !isDiscard && !_isGuest,
                        options: genCropHealthOpts,
                        value: _cropHealth,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropHealth = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen2Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Action Needed ──
                  GenSection(
                    title: 'Action Needed',
                    icon: Icons.gavel_outlined,
                    color: AdvantaColors.error,
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
                        accentColor: AdvantaColors.error,
                      ),
                      if (isDiscard && !_isGuest) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message:
                              'Action Discard Full dipilih — hanya field wajib '
                              '(QA FI, SPV, Tanggal) yang harus diisi.',
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
                        accentColor: AdvantaColors.error,
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
            isDiscard: isDiscard && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY — TIDAK DAPAT MENYIMPAN'
                : (isDiscard
                    ? 'SIMPAN — DISCARD FULL'
                    : 'SIMPAN GEN-2 PROCESS'),
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
