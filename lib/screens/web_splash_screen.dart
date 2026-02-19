import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'web_admin_dashboard.dart';

class WebSplashScreen extends StatefulWidget {
  const WebSplashScreen({super.key});

  @override
  State<WebSplashScreen> createState() => _WebSplashScreenState();
}

class _WebSplashScreenState extends State<WebSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();

    // 1. Setup Animasi
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    // Animasi Slide (Perbaikan: Variabel ini sekarang akan dipakai di build)
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
    _fetchVersion();

    // 2. Timer pindah halaman
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WebAdminDashboard()),
        );
      }
    });
  }

  Future<void> _fetchVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = packageInfo.version);
    } catch (e) {
      if (mounted) setState(() => _version = 'Web');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.green.shade800,
              Colors.green.shade900,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO (Perbaikan: Menggunakan SlideTransition) ---
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: SlideTransition( // <-- Menggunakan _slideAnimation
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Ganti withOpacity(0.1) -> withAlpha(26)
                            color: Colors.white.withAlpha(26),
                            boxShadow: [
                              BoxShadow(
                                // Ganti withOpacity(0.3) -> withAlpha(77)
                                color: Colors.black.withAlpha(77),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.green.shade100,
                            backgroundImage: const AssetImage('assets/logo.png'),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),

                  // --- TITLE ---
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: SlideTransition( // <-- Menggunakan _slideAnimation
                      position: _slideAnimation,
                      child: const Text(
                        'ADMIN DASHBOARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          letterSpacing: 1.2,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 10)],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- SUBTITLE (Versi + Info) ---
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: SlideTransition( // <-- Menggunakan _slideAnimation
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          // Ganti withOpacity(0.15) -> withAlpha(38)
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          // Perbaikan: Menggunakan variabel _version
                          'Webview Version $_version',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.15),

                  // --- LOADING ---
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ngrantos sekedap...',
                          style: TextStyle(
                            // Ganti withOpacity(0.8) -> withAlpha(204)
                            color: Colors.white.withAlpha(204),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}