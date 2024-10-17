import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Untuk ListResult dan Reference
import 'package:shared_preferences/shared_preferences.dart'; // Tambahkan import untuk SharedPreferences
import 'admin_storage_service.dart';
import 'login_screen.dart'; // Import halaman login

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  final AdminStorageService storageService = AdminStorageService();
  late Future<ListResult> futureFiles;

  @override
  void initState() {
    super.initState();
    // Mendapatkan daftar file saat inisialisasi
    futureFiles = storageService.listFiles();
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userRole');

    if (!mounted) return;

    if (mounted) {
      await _showNotificationDialog('Logout Berhasil', 'Anda telah berhasil logout.');
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _showNotificationDialog(String title, String content) async {
    // Fungsi untuk menampilkan notifikasi berupa dialog
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      await storageService.deleteFile(fileName);

      // Tampilkan notifikasi setelah file berhasil dihapus
      _showNotificationDialog('File Dihapus', 'File "$fileName" telah berhasil dihapus.');

      // Refresh daftar file
      setState(() {
        futureFiles = storageService.listFiles();
      });
    } catch (e) {
      _showNotificationDialog('Error', 'Gagal menghapus file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome, Admin!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await storageService.uploadExcelFile(context);

                // Tampilkan notifikasi setelah file berhasil di-upload
                _showNotificationDialog('Upload Berhasil', 'File telah berhasil di-upload.');

                // Refresh daftar file
                setState(() {
                  futureFiles = storageService.listFiles();
                });
              },
              child: const Text('Upload Excel File'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<ListResult>(
                future: futureFiles,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
                    return const Text('No files found.');
                  } else {
                    return ListView.builder(
                      itemCount: snapshot.data!.items.length,
                      itemBuilder: (context, index) {
                        final file = snapshot.data!.items[index];
                        return ListTile(
                          title: Text(file.name),
                          onTap: () {
                            _showFileDetailDialog(file);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteFile(file.name),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFileDetailDialog(Reference file) async {
    // Fungsi untuk menampilkan detail file dalam dialog
    final metadata = await file.getMetadata();
    final createdTime = metadata.timeCreated?.toLocal().toString() ?? 'Unknown';
    final fileSize = metadata.size?.toString() ?? 'Unknown';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Detail File: ${file.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nama: ${file.name}'),
              Text('Tanggal Dibuat: $createdTime'),
              Text('Ukuran File: $fileSize bytes'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
