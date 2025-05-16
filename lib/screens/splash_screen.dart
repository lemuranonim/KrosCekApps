import 'package:flutter/material.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.decelerate,
      ),
    );

    _controller.forward();
    _fetchVersion();

    Timer(const Duration(seconds: 4), () {
      if (mounted) _checkLoginStatus();
    });
  }

  Future<void> _fetchVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'Updated Version ${packageInfo.version}');
      }
    } catch (e) {
      if (mounted) setState(() => _version = 'Development Version');
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userRole = prefs.getString('userRole');

    if (!mounted) return;

    // Using GoRouter instead of Navigator
    if (isLoggedIn && userRole != null) {
      switch (userRole) {
        case 'admin':
          context.go('/admin');
          break;
        case 'psp':
          context.go('/psp');
          break;
        default:
          context.go('/home');
          break;
      }
    } else {
      context.go('/login');
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
    final theme = Theme.of(context);
    final white200 = Colors.white.withAlpha(200); // 200/255 ≈ 78% opacity
    final white150 = Colors.white.withAlpha(150); // 150/255 ≈ 59% opacity

    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image.asset(
                      //   'assets/icon.png',
                      //   height: size.height * 0.15,
                      //   errorBuilder: (_, __, ___) => Icon(
                      //     Icons.agriculture,
                      //     size: size.height * 0.15,
                      //     color: Colors.white,
                      //   ),
                      // ),
                      const SizedBox(height: 35),
                      Text(
                        'Crop Inspection\nand Check Result',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: size.height * 0.1),
                      Column(
                        children: [
                          Text(
                            '© ${DateTime.now().year} Tim Cengoh, Ahli Huru-Hara',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: white200, // Replaced withAlpha
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _version,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: white150, // Replaced withAlpha
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}