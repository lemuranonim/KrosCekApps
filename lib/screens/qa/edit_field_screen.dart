import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Tambahan untuk refresh data
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Tambahan untuk akses database
import '../../../theme/app_theme.dart';
import '../../../providers/master_fields_provider.dart'; // Import provider untuk di-refresh
import '../../../services/session_manager.dart';
import '../../../utils/guest_guard.dart';

// 1. Ubah menjadi ConsumerStatefulWidget agar bisa akses ref
class EditFieldScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> fieldData;

  const EditFieldScreen({super.key, required this.fieldData});

  @override
  ConsumerState<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends ConsumerState<EditFieldScreen> {
  late TextEditingController _provCtrl;
  late TextEditingController _kabCtrl;
  late TextEditingController _kecCtrl;
  late TextEditingController _desaCtrl;
  late TextEditingController _dusunCtrl;

  bool _isLoading = false; // Indikator loading saat menyimpan
  ActiveSession? _session;
  bool get _isGuest => GuestGuard.isGuest(_session);

  @override
  void initState() {
    super.initState();
    _provCtrl = TextEditingController(text: widget.fieldData['prov']?.toString() ?? '');
    _kabCtrl = TextEditingController(text: widget.fieldData['district_kab']?.toString() ?? '');
    _kecCtrl = TextEditingController(text: widget.fieldData['sub_district_kec']?.toString() ?? '');
    _desaCtrl = TextEditingController(text: widget.fieldData['village_desa']?.toString() ?? '');
    _dusunCtrl = TextEditingController(text: widget.fieldData['hamlet_dusun']?.toString() ?? '');
    SessionManager.instance.getActiveSession().then((session) {
      if (mounted) setState(() => _session = session);
    });
  }

  @override
  void dispose() {
    _provCtrl.dispose();
    _kabCtrl.dispose();
    _kecCtrl.dispose();
    _desaCtrl.dispose();
    _dusunCtrl.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil saran data dari Supabase
  Future<Iterable<String>> _fetchLocation(String table, String query) async {
    if (query.isEmpty) {
      return const Iterable<String>.empty();
    }
    try {
      final response = await Supabase.instance.client
          .from(table)
          .select('nama')
          .ilike('nama', '%$query%')
          .limit(5);

      final List<dynamic> data = response;
      return data.map((e) => e['nama'].toString().toUpperCase());
    } catch (e) {
      debugPrint('Error fetching $table: $e');
      return const Iterable<String>.empty();
    }
  }

  // 2. FUNGSI SIMPAN REAL (UPDATE KE SUPABASE)
  Future<void> _saveData() async {
    if (GuestGuard.blockIfGuest(context, _session)) return;

    final fieldNumber = widget.fieldData['field_number']?.toString();

    // Validasi No Lahan
    if (fieldNumber == null || fieldNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menyimpan: No. Lahan tidak ditemukan.'),
          backgroundColor: AdvantaColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updatedData = {
      'prov': _provCtrl.text,
      'district_kab': _kabCtrl.text,
      'sub_district_kec': _kecCtrl.text,
      'village_desa': _desaCtrl.text,
      'hamlet_dusun': _dusunCtrl.text,
    };

    try {
      // Mengirim perintah UPDATE ke Supabase
      // Asumsi: identifier unik lahan kamu di tabel master_fields adalah 'field_number'
      await Supabase.instance.client
          .from('master_fields')
          .update(updatedData)
          .eq('field_number', fieldNumber);

      if (!mounted) return;

      // Me-refresh (invalidate) provider agar Peta dan List mengambil data terbaru
      ref.invalidate(masterFieldsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data lokasi berhasil diperbarui!'),
          backgroundColor: AdvantaColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Tutup halaman edit kembali ke Map
      context.pop();
    } catch (e) {
      debugPrint('Error updating data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan sistem: $e'),
          backgroundColor: AdvantaColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldNumber = widget.fieldData['field_number']?.toString() ?? 'Unknown';

    return Scaffold(
      backgroundColor: AdvantaColors.deepForest,
      appBar: AppBar(
        backgroundColor: AdvantaColors.deepForest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Lahan #$fieldNumber',
          style: AdvantaText.heading3.copyWith(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isGuest) ...[
              GuestGuard.banner(),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AdvantaColors.gold.withAlpha(20),
                borderRadius: AdvantaRadius.cardRadius,
                border: Border.all(color: AdvantaColors.gold.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AdvantaColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perubahan data lokasi akan langsung tersimpan di database.',
                      style: AdvantaText.caption.copyWith(color: AdvantaColors.goldLight),
                    ),
                  ),
                ],
              ),
            ),

            Text('INFORMASI LOKASI', style: AdvantaText.label.copyWith(color: AdvantaColors.mutedGrey)),
            const SizedBox(height: 12),

            _buildAsyncAutocomplete(label: 'Provinsi', table: 'provinsi', controller: _provCtrl, icon: Icons.map_outlined),
            const SizedBox(height: 16),
            _buildAsyncAutocomplete(label: 'Kabupaten', table: 'kabupaten', controller: _kabCtrl, icon: Icons.location_city_outlined),
            const SizedBox(height: 16),
            _buildAsyncAutocomplete(label: 'Kecamatan', table: 'kecamatan', controller: _kecCtrl, icon: Icons.holiday_village_outlined),
            const SizedBox(height: 16),
            _buildAsyncAutocomplete(label: 'Desa', table: 'desa', controller: _desaCtrl, icon: Icons.home_work_outlined),
            const SizedBox(height: 16),
            _buildTextField(label: 'Dusun', controller: _dusunCtrl, icon: Icons.signpost_outlined),
            const SizedBox(height: 16),

            _buildReadOnlyField(
              label: 'Koordinat',
              value: widget.fieldData['coordinate']?.toString() ?? 'Belum ada',
              icon: Icons.pin_drop_outlined,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : _isGuest
                    ? () => GuestGuard.blockIfGuest(context, _session)
                    : _saveData, // Tombol nonaktif kalau sedang loading
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.primaryGreen,
              disabledBackgroundColor: AdvantaColors.primaryGreen.withAlpha(100),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: AdvantaRadius.buttonRadius),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : Text(
              _isGuest ? 'MODE READ-ONLY' : 'SIMPAN PERUBAHAN',
              style: AdvantaText.button.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAsyncAutocomplete({
    required String label,
    required String table,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (_isGuest) return const Iterable<String>.empty();
        return await _fetchLocation(table, textEditingValue.text);
      },
      onSelected: (String selection) {
        if (_isGuest) return;
        controller.text = selection;
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.text = fieldController.text;
          }
        });

        return TextField(
          enabled: !_isGuest,
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          style: AdvantaText.body2.copyWith(color: Colors.white),
          cursorColor: AdvantaColors.lightGreen,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AdvantaText.caption.copyWith(color: Colors.white54),
            prefixIcon: Icon(icon, color: AdvantaColors.lightGreen, size: 20),
            filled: true,
            fillColor: Colors.white.withAlpha(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdvantaColors.lightGreen),
            ),
            suffixIcon: fieldController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
              onPressed: _isGuest ? null : () {
                fieldController.clear();
                controller.clear();
              },
            )
                : null,
          ),
          onSubmitted: (v) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AdvantaColors.deepForest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withAlpha(10)),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(
                        option,
                        style: AdvantaText.body2.copyWith(color: AdvantaColors.lightGreen, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      enabled: !_isGuest,
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      style: AdvantaText.body2.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AdvantaText.caption.copyWith(color: Colors.white54),
        prefixIcon: Icon(icon, color: AdvantaColors.lightGreen, size: 20),
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdvantaColors.lightGreen),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AdvantaText.caption.copyWith(color: Colors.white38)),
                const SizedBox(height: 2),
                Text(value, style: AdvantaText.body2.copyWith(color: Colors.white54)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
