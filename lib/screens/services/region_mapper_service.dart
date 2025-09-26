import 'package:cloud_firestore/cloud_firestore.dart';

// Service ini bertanggung jawab KHUSUS untuk memuat dan menyediakan
// pemetaan [Nama Region] -> [ID Dokumen Firestore] berdasarkan peran (qa, psp, hsp).
class RegionMapperService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variabel untuk menyimpan pemetaan dinamis dari Firestore
  // Contoh: { "qa": {"Region 1": "region 1"}, "psp": {"PSP": "psp"} }
  static Map<String, dynamic> _roleBasedRegionMappings = {};

  // Memuat konfigurasi pemetaan dari dokumen 'config/region_mappings'.
  static Future<void> loadMappings() async {
    try {
      // Memuat pemetaan Region -> ID Dokumen berdasarkan peran
      DocumentSnapshot mappingsSnapshot =
      await _firestore.collection('config').doc('region_mappings').get();

      if (mappingsSnapshot.exists && mappingsSnapshot.data() != null) {
        _roleBasedRegionMappings = mappingsSnapshot.data() as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error loading region mappings: $e");
    }
  }

  // Mengambil Map pemetaan [Region] -> [ID Dokumen] untuk peran tertentu.
  // @param role String peran ('qa', 'psp', atau 'hsp').
  // @return Map<String, String> yang sesuai dengan peran, atau map kosong jika tidak ada.
  static Map<String, String> getRegionDocumentIdsForRole(String role) {
    if (_roleBasedRegionMappings.containsKey(role)) {
      // Konversi Map<String, dynamic> dari Firestore ke Map<String, String>
      return Map<String, String>.from(_roleBasedRegionMappings[role]);
    }
    // Kembalikan map kosong jika peran tidak ditemukan untuk mencegah error
    return {};
  }
}