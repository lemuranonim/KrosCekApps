import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart'; // Import HomeScreen

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  SuccessScreenState createState() => SuccessScreenState();
}

class SuccessScreenState extends State<SuccessScreen> {
  int _countdown = 5; // Inisialisasi hitung mundur 5 detik

  @override
  void initState() {
    super.initState();
    _startCountdown(); // Mulai hitung mundur ketika layar dibuka
  }

  // Fungsi untuk memulai hitung mundur dan kembali ke halaman home setelah 5 detik
  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        // Arahkan ke halaman HomeScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
        );
      } else {
        setState(() {
          _countdown--; // Kurangi hitungan mundur
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sukses', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Data berhasil disimpan!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Kembali ke halaman utama dalam $_countdown detik...',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
