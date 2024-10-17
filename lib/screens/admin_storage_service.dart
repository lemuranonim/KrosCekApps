import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadExcelFile(BuildContext context) async {
    try {
      // Menggunakan file picker untuk memilih file Excel
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        Uint8List? fileBytes;

        if (file.bytes != null) {
          fileBytes = file.bytes;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null) {
          // Mendapatkan referensi ke Firebase Storage
          Reference ref = _storage.ref().child('excel_files/${file.name}');

          // Mengunggah file ke Firebase Storage
          await ref.putData(fileBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file has no data.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    }
  }

  Future<void> downloadExcelFile(BuildContext context, String fileName) async {
    try {
      // Mendapatkan referensi ke Firebase Storage
      Reference ref = _storage.ref().child('excel_files/$fileName');

      // Mendapatkan URL download
      final String downloadURL = await ref.getDownloadURL();

      // Menampilkan pesan sukses dengan URL file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download URL: $downloadURL')),
      );

      // Di sini, Anda bisa menggunakan URL untuk mengunduh dan menyimpan file
      // atau membukanya langsung di perangkat.

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file: $e')),
      );
    }
  }

  // Fungsi untuk menampilkan daftar file di Firebase Storage
  Future<ListResult> listFiles() async {
    try {
      // Mendapatkan referensi ke folder excel_files di Firebase Storage
      Reference ref = _storage.ref().child('excel_files');

      // Mendapatkan daftar file yang ada di dalam folder tersebut
      ListResult result = await ref.listAll();

      return result;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }
}
