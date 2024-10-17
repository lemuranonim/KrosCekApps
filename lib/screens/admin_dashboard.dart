import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Untuk ListResult dan Reference
import 'package:shared_preferences/shared_preferences.dart'; // Tambahkan import untuk SharedPreferences
import 'admin_storage_service.dart';
import 'login_screen.dart'; // Import halaman login

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
    await prefs.remove('isLoggedIn'); // Hapus status login
    await prefs.remove('userRole'); // Hapus peran pengguna
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()), // Arahkan ke halaman login
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(), // Tambahkan fungsi logout
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
              onPressed: () => storageService.uploadExcelFile(context),
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
                            storageService.downloadExcelFile(context, file.name);
                          },
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
}
