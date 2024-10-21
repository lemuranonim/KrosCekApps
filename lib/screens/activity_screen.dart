import 'dart:async';
import 'package:flutter/material.dart';

// Kelas model NotificationItem
class NotificationItem {
  final String message;
  final DateTime time;

  NotificationItem(this.message, this.time);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();

  // Tambahkan fungsi statis untuk menambah notifikasi dari luar
  static void addNotificationFromOutside(BuildContext context, String message) {
    final state = context.findAncestorStateOfType<ActivityScreenState>();
    if (state != null) {
      state.addNotification(message);
    }
  }
}

class ActivityScreenState extends State<ActivityScreen> {
  // List untuk menyimpan notifikasi atau aktivitas
  List<NotificationItem> notifications = [];

  // Variabel untuk menyimpan filter yang dipilih
  String selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    // Simulasi notifikasi awal untuk contoh
    addNotification("Halaman aktivitas dimuat");
  }

  // Fungsi untuk menambah notifikasi ke dalam list
  void addNotification(String notification) {
    final now = DateTime.now();
    setState(() {
      notifications.add(NotificationItem(notification, now));
    });
  }

  // Fungsi untuk memfilter notifikasi
  void filterNotifications(String filter) {
    setState(() {
      selectedFilter = filter;
    });
  }

  // Fungsi refresh untuk memuat ulang halaman aktivitas
  Future<void> refreshActivity() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi loading
    setState(() {
      addNotification("Halaman aktivitas di-refresh");
    });
  }

  // Fungsi untuk menyaring notifikasi berdasarkan filter yang dipilih
  List<NotificationItem> getFilteredNotifications() {
    if (selectedFilter == 'Semua') {
      return notifications;
    } else if (selectedFilter == 'Hari ini') {
      final today = DateTime.now();
      return notifications.where((notif) {
        return notif.time.day == today.day &&
            notif.time.month == today.month &&
            notif.time.year == today.year;
      }).toList();
    } else if (selectedFilter == 'Minggu ini') {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Hari Senin
      return notifications.where((notif) {
        return notif.time.isAfter(startOfWeek);
      }).toList();
    }
    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    List<NotificationItem> filteredNotifications = getFilteredNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aktivitas',
          style: TextStyle(color: Colors.green),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.green),
        actions: [
          // Tombol refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              refreshActivity();
            },
          ),
          // Dropdown untuk filter
          DropdownButton<String>(
            value: selectedFilter,
            items: <String>['Semua', 'Hari ini', 'Minggu ini'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              filterNotifications(newValue!);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshActivity,
        child: filteredNotifications.isNotEmpty
            ? ListView.builder(
          itemCount: filteredNotifications.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.notifications, color: Colors.green),
              title: Text(filteredNotifications[index].message),
              subtitle: Text(filteredNotifications[index].time.toLocal().toString()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityDetailScreen(
                      notification: filteredNotifications[index],
                    ),
                  ),
                );
              },
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
    );
  }
}

// Halaman untuk detail notifikasi
class ActivityDetailScreen extends StatelessWidget {
  final NotificationItem notification;

  const ActivityDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Aktivitas'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Detail Notifikasi:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(notification.message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text("Waktu: ${notification.time.toLocal().toString()}", style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
