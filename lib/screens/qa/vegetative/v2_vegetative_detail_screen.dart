// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';

import '../../../providers/master_fields_provider.dart';
import 'v2_vegetative_edit_screen.dart';

class V2VegetativeDetailScreen extends ConsumerStatefulWidget {
  final String fieldNumber;
  final String region;

  const V2VegetativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  ConsumerState<V2VegetativeDetailScreen> createState() =>
      _V2VegetativeDetailScreenState();
}

class _V2VegetativeDetailScreenState
    extends ConsumerState<V2VegetativeDetailScreen> {

  // Fungsi helper untuk mem-parsing koordinat string ("lat, lng") ke LatLng
  latlng.LatLng? _parseCoordinate(String? coordinateString) {
    if (coordinateString == null || coordinateString.isEmpty) return null;
    try {
      final parts = coordinateString.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) return latlng.LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint("Error parsing coordinate: $e");
    }
    return null;
  }

  // Fungsi helper untuk memformat angka dengan pemisah ribuan
  String _formatNumber(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      final number = int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      return NumberFormat('#,###', 'id_ID').format(number);
    } catch (e) {
      return value; // Kembalikan nilai asli jika gagal parsing
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterDataAsync = ref.watch(masterFieldsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Detail Kroscek: ${widget.fieldNumber}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: 'Edit Data Kroscek',
            onPressed: () {
              final allFields = ref.read(masterFieldsProvider).value ?? [];
              final fieldData = allFields.firstWhere(
                    (element) => element['field_number'] == widget.fieldNumber,
                orElse: () => {},
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => V2VegetativeEditScreen(
                    fieldNumber: widget.fieldNumber,
                    initialAuditData: fieldData['audit_vegetative'],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: masterDataAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.green)),
        error: (err, stack) => Center(
            child: Text('Gagal memuat data: $err',
                style: const TextStyle(color: Colors.red))),
        data: (allFields) {
          final fieldData = allFields.firstWhere(
                (element) => element['field_number'] == widget.fieldNumber,
            orElse: () => {},
          );

          if (fieldData.isEmpty) {
            return _buildEmptyState('Data lahan tidak ditemukan.');
          }

          final auditData = fieldData['audit_vegetative'];
          final isAudited = auditData != null;
          final coordinate = _parseCoordinate(fieldData['coordinate']?.toString());

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // --- KARTU HEADER: INFORMASI PETANI ---
                _buildFarmerHeaderCard(fieldData),
                const SizedBox(height: 20),

                // --- SECTION 1: INFORMASI DASAR LAHAN ---
                _buildSectionTitle('Informasi Dasar Lahan', Icons.info_outline),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDetailRow('Luas Efektif (Ha)', fieldData['effective_area_ha']?.toString() ?? '0', isHighlight: true),
                        _buildDivider(),
                        _buildDetailRow('Varietas (Hybrid)', fieldData['hybrid']?.toString() ?? '-'),
                        _buildDivider(),
                        _buildDetailRow('Tanggal Tanam', fieldData['planting_date_pdn']?.toString() ?? '-'),
                        _buildDivider(),
                        _buildDetailRow('Fase Saat Ini', fieldData['type']?.toString() ?? '-', isHighlight: true, highlightColor: Colors.blue.shade700),
                        _buildDivider(),
                        _buildDetailRow('Field SPV', fieldData['field_spv']?.toString() ?? '-'),
                        _buildDivider(),
                        _buildDetailRow('Desa/Kecamatan', '${fieldData['village_desa'] ?? '-'} / ${fieldData['sub_district_kec'] ?? '-'}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- MAP LOKASI ---
                if (coordinate != null) ...[
                  _buildSectionTitle('Lokasi Lahan', Icons.location_on_outlined),
                  _buildMapCard(coordinate),
                  const SizedBox(height: 20),
                ],

                // --- STATUS BELUM AUDIT ---
                if (!isAudited)
                  _buildNotAuditedCard()
                else ...[
                  // --- SECTION 2: HASIL KROSCEK AKTUAL ---
                  _buildSectionTitle('Hasil Kroscek Lapangan', Icons.assignment_turned_in_outlined),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow('Tanggal Kroscek', auditData['date_of_audit']?.toString() ?? '-'),
                          _buildDivider(),
                          _buildDetailRow('Audited Area (Ha)', auditData['audited_ha']?.toString() ?? '-', isHighlight: true),
                          _buildDivider(),
                          _buildDetailRow('Estimasi DAP (15)', auditData['veg_est_15_dap']?.toString() ?? '- Hari'),
                          _buildDivider(),
                          // Menyesuaikan parameter lama: Populasi, Pekerja, Pupuk
                          _buildDetailRow('Populasi Tanaman', _formatNumber(auditData['populasi_tanaman']?.toString())),
                          _buildDivider(),
                          _buildDetailRow('Jumlah Pekerja', '${auditData['jumlah_pekerja'] ?? '0'} Orang'),
                          _buildDivider(),
                          _buildDetailRow('Dosis Pupuk (kg/Ha)', auditData['dosis_pupuk']?.toString() ?? '-'),
                          _buildDivider(),
                          _buildDetailRow('CO Detasseling', auditData['co_detasseling']?.toString() ?? '-'),
                          _buildDivider(),
                          _buildDetailRow('Catatan Tambahan', auditData['remarks']?.toString() ?? '-', isLongText: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- SECTION 3: EVALUASI & FLAGGING ---
                  _buildSectionTitle('Evaluasi & Keputusan', Icons.grading_outlined),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow('Keseragaman (Uniformity)', auditData['crop_uniformity']?.toString() ?? '-'),
                          _buildDivider(),
                          _buildDetailRow('Kesehatan (Health)', auditData['crop_health']?.toString() ?? '-'),
                          _buildDivider(),

                          // Final Flagging Badge
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Final Flagging', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                _buildFlaggingBadge(auditData['final_flagging']?.toString()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // WIDGET HELPERS UNTUK UI/UX
  // ==========================================

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerHeaderCard(Map<String, dynamic> fieldData) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nama Petani', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            fieldData['farmer_name']?.toString().toUpperCase() ?? '-',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Grower: ${fieldData['grower']?.toString() ?? '-'}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(latlng.LatLng coordinate) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: coordinate,
            initialZoom: 15.0,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.kroscek',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: coordinate,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAuditedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
            child: Icon(Icons.pending_actions_rounded, color: Colors.orange.shade800, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belum Dikroscek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                SizedBox(height: 4),
                Text('Lahan ini belum memiliki data audit pada fase Vegetative. Klik icon edit di atas untuk mengisi data.',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, Color? highlightColor, bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                color: isHighlight ? (highlightColor ?? Colors.green.shade700) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
    );
  }

  Widget _buildFlaggingBadge(String? flag) {
    if (flag == null || flag.isEmpty) return const Text('-');

    Color bgColor;
    Color textColor = Colors.white;
    String flagText = flag.toUpperCase();

    if (flagText.contains('RED')) {
      bgColor = Colors.red.shade600;
    } else if (flagText.contains('YELLOW')) {
      bgColor = Colors.amber.shade500;
      textColor = Colors.black87;
    } else if (flagText.contains('GREEN')) {
      bgColor = Colors.green.shade600;
    } else {
      bgColor = Colors.grey.shade500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(flagText, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}