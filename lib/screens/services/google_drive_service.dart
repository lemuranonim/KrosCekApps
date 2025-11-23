import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import '/utils/authenticated_client.dart'; // Pastikan import helper di atas

class GoogleDriveService {
  // ID Folder Admin yang Anda berikan
  final String _targetFolderId = '1Qo1sa3aqHr3PNh-_BpnVEs0-8rQQGpPI';

  // Scopes yang dibutuhkan (Wajib ditambahkan juga saat init GoogleSignIn di main/login screen)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  Future<String?> uploadImage(File imageFile, String userName, String region, {String? targetFolderId}) async {
    try {
      // 1. Cek User Login
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      if (googleUser == null) {
        // Coba login silent jika user null (atau throw error agar user login ulang)
        await _googleSignIn.signInSilently();
        if (_googleSignIn.currentUser == null) {
          throw Exception("User belum login Google Sign-In");
        }
      }

      // 2. Ambil Header Auth dari User
      final authHeaders = await _googleSignIn.currentUser!.authHeaders;

      // 3. Buat Client HTTP Authenticated
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      // 4. Siapkan Metadata File
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}";
      final fileName = "${userName.replaceAll(' ', '_')}_${region}_$dateStr${p.extension(imageFile.path)}";

      var driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = [targetFolderId ?? _targetFolderId]; // 🎯 TARGET KE FOLDER ADMIN

      // 5. Upload File
      final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());
      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, webViewLink',
      );

      debugPrint("✅ Upload Berhasil ke Folder Admin: ${result.webViewLink}");
      return result.webViewLink;

    } catch (e) {
      debugPrint("❌ Error Upload Drive User: $e");
      // Filter error umum untuk pesan lebih jelas
      if (e.toString().contains("404")) {
        throw Exception("Folder Admin tidak ditemukan atau User tidak punya akses Edit ke sana.");
      } else if (e.toString().contains("403")) {
        throw Exception("Izin ditolak. Pastikan Admin sudah share folder ke email ini.");
      }
      throw Exception("Gagal upload: $e");
    }
  }
}