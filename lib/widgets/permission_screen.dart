import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    checkPermissions(); // Memeriksa izin saat widget dibuat
  }

  Future<void> checkPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    // 'const' dihapus dari baris ini
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: const Center(
        child: Text('Izin telah diperiksa!'),
      ),
    );
  }
}