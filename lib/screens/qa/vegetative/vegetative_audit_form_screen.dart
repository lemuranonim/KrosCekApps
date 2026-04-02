import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/audit_vegetative_provider.dart';
import '../../../providers/master_fields_provider.dart';

class VegetativeAuditFormScreen extends ConsumerStatefulWidget {
  final String fieldNumber;
  const VegetativeAuditFormScreen({super.key, required this.fieldNumber});

  @override
  ConsumerState<VegetativeAuditFormScreen> createState() => _VegetativeAuditFormScreenState();
}

class _VegetativeAuditFormScreenState extends ConsumerState<VegetativeAuditFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers for Audit Fields
  final TextEditingController _qaFiController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String? _cropUniformity;

  @override
  void dispose() {
    _qaFiController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _saveAudit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final auditData = {
        'field_number': widget.fieldNumber,
        'qa_fi': _qaFiController.text,
        'crop_uniformity': _cropUniformity,
        'remarks': _remarksController.text,
        'date_of_audit': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };

      await ref.read(supabaseServiceProvider).upsertVegetativeAudit(auditData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit Berhasil Disimpan')),
        );
        Navigator.pop(context);
        ref.invalidate(vegetativeAuditProvider(widget.fieldNumber));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(vegetativeAuditProvider(widget.fieldNumber));

    return Scaffold(
      appBar: AppBar(title: Text('Audit: ${widget.fieldNumber}')),
      body: auditAsync.when(
        data: (audit) {
          // Pre-fill controllers if data exists
          if (audit != null) {
            _qaFiController.text = audit['qa_fi'] ?? '';
            _remarksController.text = audit['remarks'] ?? '';
            _cropUniformity ??= audit['crop_uniformity'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _qaFiController,
                    decoration: const InputDecoration(labelText: 'QA FI Name'),
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _cropUniformity,
                    decoration: const InputDecoration(labelText: 'Crop Uniformity'),
                    items: ['Uniform', 'Not Uniform'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _cropUniformity = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                  ),
                  const SizedBox(height: 30),
                  _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _saveAudit,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                          child: const Text('SIMPAN AUDIT'),
                        ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
