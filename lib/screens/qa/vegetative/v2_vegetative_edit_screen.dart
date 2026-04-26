import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/master_fields_provider.dart';

class V2VegetativeEditScreen extends ConsumerStatefulWidget {
  final String fieldNumber;
  final Map<String, dynamic>? initialAuditData; // Membawa data baku dari database

  const V2VegetativeEditScreen({
    super.key,
    required this.fieldNumber,
    this.initialAuditData,
  });

  @override
  ConsumerState<V2VegetativeEditScreen> createState() => _V2VegetativeEditScreenState();
}

class _V2VegetativeEditScreenState extends ConsumerState<V2VegetativeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // --- CONTROLLER UNTUK DATA INSPEKSI ---
  late TextEditingController _dateAuditController;
  late TextEditingController _coDetasselingController; // 🌟 Field inspeksi pertamamu
  late TextEditingController _remarksController;
  // TODO: Tambahkan controller lain di sini untuk field setelah co_detasseling jika ada

  // Dropdown values
  String? _cropUniformity;
  String? _cropHealth;

  // Pilihan Dropdown
  final List<String> _uniformityOptions = ['Uniform', 'Not Uniform'];
  final List<String> _healthOptions = ['Healthy', 'Pest/Disease', 'Nutrient Deficiency'];

  @override
  void initState() {
    super.initState();
    final data = widget.initialAuditData ?? {};

    // Isi form dengan data lama JIKA sudah pernah diisi sebagian
    _dateAuditController = TextEditingController(
        text: data['date_of_audit']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now())
    );
    _coDetasselingController = TextEditingController(text: data['co_detasseling']?.toString() ?? '');
    _remarksController = TextEditingController(text: data['remarks']?.toString() ?? '');

    _cropUniformity = data['crop_uniformity']?.toString();
    _cropHealth = data['crop_health']?.toString();

    // Cegah error UI jika data lama null/tidak ada di daftar
    if (!_uniformityOptions.contains(_cropUniformity)) _cropUniformity = null;
    if (!_healthOptions.contains(_cropHealth)) _cropHealth = null;
  }

  @override
  void dispose() {
    _dateAuditController.dispose();
    _coDetasselingController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateAuditController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dataBaku = widget.initialAuditData ?? {};

      // 1. Siapkan payload data untuk Supabase
      final dataToSave = {
        // --- DATA BAKU (Dipertahankan agar tidak hilang) ---
        'field_number': widget.fieldNumber,
        'fase': 'Vegetative',
        'veg_audit_est_30_dap': dataBaku['veg_audit_est_30_dap'],
        'week_of_vegetative': dataBaku['week_of_vegetative'],
        'qa_spv': dataBaku['qa_spv'],
        'qa_fi': dataBaku['qa_fi'],

        // --- DATA HASIL INSPEKSI (Di-update) ---
        'date_of_audit': _dateAuditController.text,
        'co_detasseling': _coDetasselingController.text, // Field pertamamu
        'crop_uniformity': _cropUniformity,
        'crop_health': _cropHealth,
        'remarks': _remarksController.text,
        // TODO: Tambahkan variabel kolom lainnya di sini
      };

      // 2. Kirim ke Supabase
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.upsertVegetativeAudit(dataToSave);

      // 3. Refresh Data Global agar Dashboard & Detail terupdate instan
      ref.invalidate(masterFieldsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeksi berhasil disimpan! 🚀'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Kembali ke layar Detail
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataBaku = widget.initialAuditData ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('Inspeksi: ${widget.fieldNumber}'),
        backgroundColor: Colors.green.shade800,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // --- BAGIAN 1: INFO DATA BAKU (READ ONLY) ---
                  Card(
                    color: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Informasi Penugasan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const Divider(),
                          _buildInfoRow('Target DAP (30)', dataBaku['veg_audit_est_30_dap']?.toString() ?? 'Belum diset'),
                          const SizedBox(height: 4),
                          _buildInfoRow('Minggu Ke', dataBaku['week_of_vegetative']?.toString() ?? '-'),
                          const SizedBox(height: 4),
                          _buildInfoRow('QA SPV', dataBaku['qa_spv']?.toString() ?? '-'),
                          const SizedBox(height: 4),
                          _buildInfoRow('QA FI', dataBaku['qa_fi']?.toString() ?? '-'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- BAGIAN 2: FORM INSPEKSI QA ---
                  const Text('Form Hasil Inspeksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Tanggal Audit
                  TextFormField(
                    controller: _dateAuditController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Tanggal Aktual Audit', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 16),

                  // CO Detasseling (Field pertama berdasarkan infomu)
                  TextFormField(
                    controller: _coDetasselingController,
                    decoration: const InputDecoration(labelText: 'CO Detasseling', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  // Dropdowns
                  DropdownButtonFormField<String>(
                    initialValue: _cropUniformity,
                    decoration: const InputDecoration(labelText: 'Crop Uniformity', border: OutlineInputBorder()),
                    items: _uniformityOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _cropUniformity = val),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _cropHealth,
                    decoration: const InputDecoration(labelText: 'Crop Health', border: OutlineInputBorder()),
                    items: _healthOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _cropHealth = val),
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  TextFormField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Remarks / Catatan', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 32),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      onPressed: _isSaving ? null : _saveData,
                      child: const Text('Simpan Data Inspeksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.green),
                        SizedBox(height: 16),
                        Text('Menyimpan ke Database...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget helper untuk merapikan text di kotak biru
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}