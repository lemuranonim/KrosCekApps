// lib/screens/inspection/form_generative_1.dart
//
// GENERATIVE AUDIT 1 — Readiness Check
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
import 'sc_form_widgets.dart';

class FormGenerative1SC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormGenerative1SC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormGenerative1SC> createState() => _FormGenerative1SCState();
}

class _FormGenerative1SCState extends ConsumerState<FormGenerative1SC> {
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
  String? _readiness;
  String? _roguing;
  String? _lsv;
  String? _cropUniformity;
  String? _cropHealth;
  String? _actionNeeded;

  // ── NEW ──────────────────────────────────────────────────
  bool get _isGuest => GuestGuard.isGuest(_session);

  @override
  void initState() {
    super.initState();
    // Load session untuk cek role Guest
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
    _qaFiCtrl.text = audit['qa_fi_1'] ?? audit['qa_fi'] ?? '';
    _qaSpvCtrl.text = audit['qa_spv'] ?? '';
    _remarksCtrl.text = audit['remarks_1'] ?? '';
    if (audit['date_of_audit_1'] != null) {
      try {
        _auditDate = DateTime.parse(audit['date_of_audit_1']);
      } catch (_) {}
    }
    setState(() {
      _readiness = audit['readiness_status_1'];
      _roguing = audit['roguing_status_1'];
      _lsv = audit['lsv_status_1'];
      _cropUniformity = audit['crop_uniformity_1'];
      _cropHealth = audit['crop_health_1'];
      _actionNeeded = audit['action_needed_1'];
    });
  }

  Future<void> _pickDate() async {
    // Guest tidak bisa mengubah tanggal
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
        data: genDatePickerTheme(ctx, kGen1Color),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _save() async {
    // ── GUARD: blokir Guest ──────────────────────────────
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
        'date_of_audit_1': DateFormat('yyyy-MM-dd').format(_auditDate),
        'week_of_audit_1': calcAuditWeek(_auditDate),
        'readiness_status_1': _readiness,
        'roguing_status_1': _roguing,
        'lsv_status_1': _lsv,
        'crop_uniformity_1': _cropUniformity,
        'crop_health_1': _cropHealth,
        'action_needed_1': _actionNeeded,
        'remarks_1': _remarksCtrl.text.trim(),
        'qa_fi_1': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'submitted_at_1': now.toIso8601String(),
        'fase': 'generative_1',
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertGenerativeCheckpoint(
        fieldNumber: widget.fieldNumber,
        checkpoint: 1,
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
          phase: 'generative_1',
          actionType: 'single_submit',
          lat: lat,
          lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldsProvider);
        ref.invalidate(generativeAuditProvider(widget.fieldNumber));
        _snack('Generative Audit 1 berhasil disimpan ✓');
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
      'date_of_audit_1': DateFormat('yyyy-MM-dd').format(_auditDate),
      'week_of_audit_1': calcAuditWeek(_auditDate),
      'readiness_status_1': _readiness,
      'roguing_status_1': _roguing,
      'lsv_status_1': _lsv,
      'crop_uniformity_1': _cropUniformity,
      'crop_health_1': _cropHealth,
      'action_needed_1': _actionNeeded,
      'remarks_1': _remarksCtrl.text.trim(),
      'qa_fi_1': _qaFiCtrl.text.trim(),
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
        passNumber: 1,
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
    final fields = ref.watch(masterFieldsProvider).value ?? [];
    final fieldData = fields.firstWhere(
        (f) => f['field_number'] == widget.fieldNumber,
        orElse: () => {});

    final isDiscard = genIsDiscardFull(_actionNeeded);

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Audit 1 (SC) – Readiness Check',
        fieldNumber: widget.fieldNumber,
        isDiscard: isDiscard,
        accentColor: kGen1Color,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: kGen1Color)),
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
                  GenFieldCard(fieldData: fd, accentColor: kGen1Color),
                  const SizedBox(height: 8),

                  // ── NEW: Guest read-only banner ──────────────
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: kGen1Color,
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
                        accentColor: kGen1Color,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: kGen1Color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian ──
                  GenSection(
                    title: 'Penilaian Readiness',
                    icon: Icons.checklist_outlined,
                    color: kGen1Color,
                    children: [
                      GenOptionPicker(
                        label: 'Readiness Status',
                        required: !isDiscard && !_isGuest,
                        options: genReadinessOpts,
                        value: _readiness,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _readiness = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen1Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Roguing Status',
                        required: !isDiscard && !_isGuest,
                        options: genRoguingOpts,
                        value: _roguing,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _roguing = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: kGen1Color,
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
                        accentColor: kGen1Color,
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
                        accentColor: kGen1Color,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Health (Bulai, Hawar) % dari Populasi',
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
                        accentColor: kGen1Color,
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

          // ── Save Bar — disabled + label berubah untuk Guest ──
          GenSaveBar(
            isSaving: _isSaving,
            isDiscard: isDiscard && !_isGuest,
            saveLabel: _isGuest
                ? 'READ-ONLY — TIDAK DAPAT MENYIMPAN'
                : (isDiscard
                    ? 'SIMPAN — DISCARD FULL'
                    : 'SIMPAN GEN-1 READINESS'),
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
