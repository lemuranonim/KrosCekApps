import 'package:flutter/material.dart';
import 'dart:async';
import 'psp_hsp_screen.dart';

class PspSuccessScreen extends StatefulWidget {
  const PspSuccessScreen({super.key});

  @override
  PspSuccessScreenState createState() => PspSuccessScreenState();
}

class PspSuccessScreenState extends State<PspSuccessScreen> {
  int _countdown = 5;
  Timer? _timer; // Tambahkan variabel timer untuk mencegah memory leak

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    // Batalkan timer saat widget dihapus untuk mencegah memory leak
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        // Gunakan mounted check untuk mencegah error jika widget sudah tidak ada
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PspHspScreen()),
                (Route<dynamic> route) => false,
          );
        }
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.orange,
                size: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'Data berhasil disimpan!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Kembali ke halaman utama dalam $_countdown detik...',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}