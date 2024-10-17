import 'package:flutter/material.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // List untuk menyimpan notifikasi
  List<String> notifications = [];

  // Fungsi untuk menambah notifikasi baru
  void addNotification(String notification) {
    setState(() {
      notifications.add(notification);
    });
  }

  @override
  void initState() {
    super.initState();

    // Contoh notifikasi saat halaman pertama kali di-load
    addNotification("Aktivitas halaman dimulai");

    // Anda dapat memanggil fungsi ini kapan saja di aplikasi ketika ada aktivitas baru
    // Contoh:
    // addNotification("Pengguna menambah data baru");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aktivitas',
          style: TextStyle(color: Colors.green),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: Column(
        children: [
          Expanded(
            child: notifications.isNotEmpty
                ? ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.green),
                  title: Text(notifications[index]),
                );
              },
            )
                : const Center(
              child: Text(
                "Tidak ada notifikasi",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
