// import 'dart:io';
// import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Future<void> uploadExcelFile(BuildContext context) async {
  //   try {
  //     FilePickerResult? result = await FilePicker.platform.pickFiles(
  //       type: FileType.custom,
  //       allowedExtensions: ['xlsx', 'xls'],
  //     );
  //
  //     if (result != null && result.files.isNotEmpty) {
  //       final file = result.files.first;
  //
  //       Uint8List? fileBytes;
  //
  //       if (file.bytes != null) {
  //         fileBytes = file.bytes;
  //       } else if (file.path != null) {
  //         fileBytes = await File(file.path!).readAsBytes();
  //       }
  //
  //       if (fileBytes != null) {
  //         Reference ref = _storage.ref().child('excel_files/${file.name}');
  //         await ref.putData(fileBytes);
  //
  //         // Pastikan widget masih mounted sebelum memanggil BuildContext
  //         if (!context.mounted) return;
  //
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('File uploaded successfully!')),
  //         );
  //       } else {
  //         if (!context.mounted) return;
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Selected file has no data.')),
  //         );
  //       }
  //     } else {
  //       if (!context.mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('No file selected.')),
  //       );
  //     }
  //   } catch (e) {
  //     if (!context.mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to upload file: $e')),
  //     );
  //   }
  // }

  Future<void> downloadExcelFile(BuildContext context, String fileName) async {
    try {
      Reference ref = _storage.ref().child('excel_files/$fileName');
      final String downloadURL = await ref.getDownloadURL();

      // Pastikan widget masih mounted sebelum memanggil BuildContext
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download URL: $downloadURL')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file: $e')),
      );
    }
  }

  Future<ListResult> listFiles() async {
    try {
      Reference ref = _storage.ref().child('excel_files');
      ListResult result = await ref.listAll();
      return result;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  Future<void> deleteFile(String fileName) async {
    try {
      // Menghapus file dari Firebase Storage
      await _storage.ref().child('excel_files/$fileName').delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
