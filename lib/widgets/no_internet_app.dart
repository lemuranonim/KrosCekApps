import 'package:flutter/material.dart';

class NoInternetApp extends StatelessWidget {
  const NoInternetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 'const' dihapus dari baris ini
    return MaterialApp(
      title: 'No Internet Connection',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('No Connection'),
        ),
        body: const Center(
          child: Text('Tidak ada koneksi internet. Harap periksa koneksi Anda.'),
        ),
      ),
    );
  }
}