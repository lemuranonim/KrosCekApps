// lib/screens/inspection/form_pre_harvest_sc.dart
//
// PRE-HARVEST AUDIT — Premium redesign (SC Version)
// Kolom: Audit Date · Audit Week · Male Chopping Rows ·
//        Final Flagging · Final Decision · Crop Uniformity ·
//        Crop Health · Discard Area (Ha) · Discard Reason · Remarks
// DB table: audit_pre_harvest
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/audit_pre_harvest_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/guest_guard.dart';
import 'sc_form_widgets.dart';

// ─── Phase accent color ───────────────────────────────────
const _kPhase = Color(0xFF26C6DA); // Cyan — Pre-Harvest

// ─── Option lists ─────────────────────────────────────────
const _maleChoppingOpts = [
  GenOpt('Complete', 'A – Complete'),
  GenOpt('Not Complete', 'B – Not Complete'),
];

const _cropCondOpts = [
  GenOpt('Very Poor', '1 – Very Poor'),
  GenOpt('Poor', '2 – Poor'),
  GenOpt('Fair', '3 – Fair'),
  GenOpt('Good', '4 – Good'),
  GenOpt('Best', '5 – Best'),
];

const _cropHealthOpts = [
  GenOpt('0% serangan', '0 – 0% serangan'),
  GenOpt('1%', '1 – 1%'),
  GenOpt('2%', '2 – 2%'),
  GenOpt('3%', '3 – 3%'),
  GenOpt('4%', '4 – 4%'),
  GenOpt('5%', '5 – 5%'),
];

const _finalFlaggingOpts = [
  GenOpt('GF', 'GF'),
  GenOpt('RFI', 'RFI'),
  GenOpt('RFD', 'RFD'),
  GenOpt('BF', 'BF'),
  GenOpt('PLD', 'PLD'),
];

const _finalDecisionOpts = [
  GenOpt('Pass', 'A – Pass'),
  GenOpt('Pass w/ Note', 'B – Pass w/ Note'),
  GenOpt('Hold', 'C – Hold'),
  GenOpt('Discard', 'D – Discard'),
];

// ─────────────────────────────────────────────────────────
class FormPreHarvestSC extends ConsumerStatefulWidget {
  final String fieldNumber;
  const FormPreHarvestSC({super.key, required this.fieldNumber});

  @override
  ConsumerState<FormPreHarvestSC> createState() => _FormPreHarvestSCState();
}

class _FormPreHarvestSCState extends ConsumerState<FormPreHarvestSC> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _dataLoaded = false;

  // ── NEW: session untuk GuestGuard ────────────────────────
  ActiveSession? _session;
  bool get _isGuest => GuestGuard.isGuest(_session);

  // Controllers
  final _qaFiCtrl = TextEditingController();
  final _qaSpvCtrl = TextEditingController();
  final _discardAreaCtrl = TextEditingController();
  final _discardReasonCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // Date
  DateTime _auditDate = DateTime.now();

  // Dropdowns
  String? _maleChopping;
  String? _finalFlagging;
  String? _finalDecision;
  String? _cropUniformity;
  String? _cropHealth;

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
    _discardAreaCtrl.dispose();
    _discardReasonCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _loadAudit(Map<String, dynamic> a) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _qaFiCtrl.text = a['qa_fi'] ?? '';
    _qaSpvCtrl.text = a['qa_spv'] ?? '';
    _discardAreaCtrl.text = a['discard_area_ha']?.toString() ?? '';
    _discardReasonCtrl.text = a['discard_reason'] ?? '';
    _remarksCtrl.text = a['remarks'] ?? '';
    if (a['audit_date'] != null) {
      try {
        _auditDate = DateTime.parse(a['audit_date']);
      } catch (_) {}
    }
    setState(() {
      _maleChopping = a['male_chopping_rows'];
      _finalFlagging = a['final_flagging'];
      _finalDecision = a['final_decision'];
      _cropUniformity = a['crop_uniformity'];
      _cropHealth = a['crop_health'];
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
        data: genDatePickerTheme(ctx, _kPhase),
        child: child!,
      ),
    );
    if (p != null) setState(() => _auditDate = p);
  }

  Future<void> _save() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali isian form', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = {
        'field_number': widget.fieldNumber,
        'audit_date': DateFormat('yyyy-MM-dd').format(_auditDate),
        'audit_week': calcAuditWeek(_auditDate),
        'male_chopping_rows': _maleChopping,
        'final_flagging': _finalFlagging,
        'final_decision': _finalDecision,
        'crop_uniformity': _cropUniformity,
        'crop_health': _cropHealth,
        'discard_area_ha': _isDiscard
            ? double.tryParse(_discardAreaCtrl.text.replaceAll(',', '.'))
            : null,
        'discard_reason': _isDiscard ? _discardReasonCtrl.text.trim() : null,
        'remarks': _remarksCtrl.text.trim(),
        'qa_fi': _qaFiCtrl.text.trim(),
        'qa_spv': _qaSpvCtrl.text.trim(),
        'fase': 'Pre-Harvest',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final svc = ref.read(supabaseServiceProvider);
      await svc.upsertPreHarvestAudit(data);

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
          phase: 'pre_harvest',
          actionType: 'single_submit',
          lat: lat,
          lng: lng,
        );
      }

      if (mounted) {
        ref.invalidate(masterFieldDetailProvider(widget.fieldNumber));
        ref.invalidate(preharvestAuditProvider(widget.fieldNumber));
        _snack('Pre-Harvest Audit berhasil disimpan ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
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
      content:
          Text(msg, style: AdvantaText.body2.copyWith(color: Colors.white)),
      backgroundColor: err ? theme.colorScheme.error : AdvantaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(preharvestAuditProvider(widget.fieldNumber));
    final fd = ref.watch(masterFieldDetailProvider(widget.fieldNumber)).value ??
        const <String, dynamic>{};

    return Scaffold(
      appBar: GenAppBar(
        checkpointLabel: 'Pre-Harvest Audit (SC)',
        fieldNumber: widget.fieldNumber,
        isDiscard: _isDiscard,
        accentColor: _kPhase,
        onBack: () => Navigator.pop(context),
      ),
      body: auditAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPhase)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AdvantaText.body2
                    .copyWith(color: Theme.of(context).colorScheme.error))),
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

                  // ── NEW: Guest read-only banner ──────────────
                  if (_isGuest) ...[
                    GuestGuard.banner(),
                    const SizedBox(height: 8),
                  ],

                  // ── Section: Audit Info ──
                  GenSection(
                    title: 'Informasi Audit',
                    icon: Icons.assignment_outlined,
                    color: _kPhase,
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
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 12),
                      GenQaAutocomplete(
                        controller: _qaSpvCtrl,
                        label: 'QA SPV',
                        hint: 'Nama QA Supervisor',
                        column: 'qa_spv',
                        required: !_isGuest,
                        icon: Icons.supervisor_account_outlined,
                        accentColor: _kPhase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Penilaian ──
                  GenSection(
                    title: 'Penilaian Pre-Harvest',
                    icon: Icons.checklist_outlined,
                    color: _kPhase,
                    children: [
                      GenOptionPicker(
                        label: 'Male Chopping (Rows)',
                        required: !_isDiscard && !_isGuest,
                        options: _maleChoppingOpts,
                        value: _maleChopping,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _maleChopping = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Uniformity',
                        required: !_isDiscard && !_isGuest,
                        options: _cropCondOpts,
                        value: _cropUniformity,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropUniformity = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: _kPhase,
                      ),
                      const SizedBox(height: 14),
                      GenOptionPicker(
                        label: 'Crop Health (Bulai, Hawar) % dari Populasi',
                        required: !_isDiscard && !_isGuest,
                        options: _cropHealthOpts,
                        value: _cropHealth,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() => _cropHealth = v);
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: _kPhase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Flagging ──
                  GenSection(
                    title: 'Flagging',
                    icon: Icons.flag_outlined,
                    color: const Color(0xFF42A5F5),
                    children: [
                      GenOptionPicker(
                        label: 'Final Flagging',
                        required: !_isGuest,
                        options: _finalFlaggingOpts,
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
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Keputusan Final ──
                  GenSection(
                    title: 'Keputusan Final',
                    icon: Icons.gavel_outlined,
                    color: AdvantaColors.error,
                    children: [
                      GenOptionPicker(
                        label: 'Final Decision',
                        required: !_isGuest,
                        options: _finalDecisionOpts,
                        value: _finalDecision,
                        onChanged: (v) {
                          if (!_isGuest) {
                            setState(() {
                              _finalDecision = v;
                              if (!genIsDiscardDecision(v)) {
                                _discardAreaCtrl.clear();
                                _discardReasonCtrl.clear();
                              }
                            });
                          } else {
                            GuestGuard.blockIfGuest(context, _session);
                          }
                        },
                        accentColor: AdvantaColors.error,
                      ),
                      if (_isDiscard) ...[
                        const SizedBox(height: 12),
                        const GenDiscardBanner(
                          message:
                              'Final Decision Discard — isi Discard Area & Reason sebelum menyimpan.',
                        ),
                        const SizedBox(height: 14),
                        GenTextField(
                          controller: _discardAreaCtrl,
                          label: 'Discard Area (Ha)',
                          hint: 'Luas area discard',
                          required: !_isGuest,
                          keyboardType: TextInputType.number,
                          icon: Icons.crop_landscape_outlined,
                          accentColor: AdvantaColors.error,
                        ),
                        const SizedBox(height: 12),
                        GenTextField(
                          controller: _discardReasonCtrl,
                          label: 'Discard Reason',
                          hint: 'Alasan discard...',
                          required: !_isGuest,
                          maxLines: 3,
                          icon: Icons.notes_outlined,
                          accentColor: AdvantaColors.error,
                        ),
                      ],
                      const SizedBox(height: 12),
                      GenTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        hint: 'Catatan tambahan...',
                        maxLines: 2,
                        icon: Icons.comment_outlined,
                        accentColor: _kPhase,
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
                ? 'READ-ONLY — TIDAK DAPAT MENYIMPAN'
                : (_isDiscard
                    ? 'SIMPAN — DISCARD PRE-HARVEST'
                    : 'SIMPAN PRE-HARVEST'),
            onSave: _isGuest
                ? () => GuestGuard.blockIfGuest(context, _session)
                : _save,
          ),
        ],
      ),
    );
  }
}
