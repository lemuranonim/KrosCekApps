import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/region_model.dart'; // Pastikan import ini ada

class RegionDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Region> fetchRegionData(String regionId) async {
    try {
      final doc = await _firestore.collection('regions').doc(regionId).get();
      if (!doc.exists) {
        throw Exception('Region tidak ditemukan');
      }
      return Region.fromFirestore(doc);
    } catch (e) {
      throw Exception('Gagal memuat data region: $e');
    }
  }

  Future<List<String>> fetchAllRegionNames() async {
    try {
      final snapshot = await _firestore.collection('regions').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      throw Exception('Gagal memuat daftar region: $e');
    }
  }

  Future<void> addDistrict(String regionId, String qaSpvId, String districtName) async {
    try {
      await _firestore.collection('regions').doc(regionId).update({
        'qa_spv.$qaSpvId.districts': FieldValue.arrayUnion([districtName])
      });
    } catch (e) {
      throw Exception('Gagal menambahkan district: $e');
    }
  }

  Future<void> removeDistrict(String regionId, String qaSpvId, String districtName) async {
    try {
      await _firestore.collection('regions').doc(regionId).update({
        'qa_spv.$qaSpvId.districts': FieldValue.arrayRemove([districtName])
      });
    } catch (e) {
      throw Exception('Gagal menghapus district: $e');
    }
  }

  Future<void> addQaSpv(String regionId, String qaSpvId, String qaSpvName) async {
    try {
      await _firestore.collection('regions').doc(regionId).update({
        'qa_spv.$qaSpvId': {
          'name': qaSpvName,
          'districts': [],
        }
      });
    } catch (e) {
      throw Exception('Gagal menambahkan QA SPV: $e');
    }
  }

  Future<void> removeQaSpv(String regionId, String qaSpvId) async {
    try {
      await _firestore.collection('regions').doc(regionId).update({
        'qa_spv.$qaSpvId': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Gagal menghapus QA SPV: $e');
    }
  }
}