// lib/screens/login_screen.dart
// ── PERUBAHAN: tambah routing 'guest' → '/qa' (read-only, dihandle di /qa)
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/supabase_auth_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';

import '../providers/master_fields_provider.dart';
import '../providers/filter_data_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/qa_mapping_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final SupabaseAuthService _auth = SupabaseAuthService();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool   _isPasswordHidden = true;
  bool   _isLoading        = false;
  String _errorMessage     = '';

  late AnimationController _entranceController;
  late AnimationController _shimmerController;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _headerFade;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this)
      ..repeat();

    _cardSlide = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic)));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut)));
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.linear));

    _entranceController.forward();
    _tryAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Auto-login ────────────────────────────────────────────
  Future<void> _tryAutoLogin() async {
    final supabaseUser = _auth.currentUser;
    if (supabaseUser == null) return;

    final session = await SessionManager.instance.getActiveSession();
    if (session == null) return;

    if (session.userId != supabaseUser.id) {
      await SessionManager.instance.nukeStaleSession(
          incomingUserId: supabaseUser.id);
      _invalidateProviders();
      return;
    }

    final appUser = await _auth.restoreSession();
    if (appUser != null && mounted) _navigateByRole(appUser);
  }

  void _invalidateProviders() {
    ref.invalidate(currentSessionProvider);
    ref.invalidate(masterFieldsProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(uniqueRegionsProvider);
    ref.invalidate(attendanceProvider);
    ref.invalidate(qaMappingProvider);
  }

  // ── Login ─────────────────────────────────────────────────
  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() =>
      _errorMessage = 'Email dan password tidak boleh kosong.');
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = '';
    });

    final appUser = await _auth.signInWithEmail(email, password);
    if (!mounted) return;

    if (appUser == null) {
      setState(() {
        _errorMessage =
        'Login gagal! Periksa kembali email dan password Anda.';
        _isLoading = false;
      });
      return;
    }

    await SessionManager.instance.nukeStaleSession(
        incomingUserId: appUser.id);

    _invalidateProviders();

    if (!mounted) return;
    _navigateByRole(appUser);
  }

  // ── Routing berdasarkan role ──────────────────────────────
  void _navigateByRole(AppUser user) {
    setState(() => _isLoading = false);
    switch (user.role.toLowerCase()) {
      case 'admin':
        context.go('/admin');
        break;
    // ── BARU: Guest → /qa (read-only, enforced oleh GuestGuard) ──
      case 'guest':
        context.go('/qa');
        break;
    // FI, SPV, Dev, Manager, QA → /qa
      default:
        context.go('/qa');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                    AdvantaColors.deepForest,
                    const Color(0xFF112E20),
                    const Color(0xFF0A2318)
                  ]
                      : [
                    AdvantaColors.primaryGreen,
                    AdvantaColors.midGreen,
                    AdvantaColors.lightGreen
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60, left: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AdvantaColors.goldLight : Colors.white)
                        .withAlpha(25),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (_, __) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: size.height -
                            MediaQuery.of(context).padding.top),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          Opacity(
                            opacity: _headerFade.value,
                            child: _buildHeader(isDark),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Opacity(
                              opacity: _cardFade.value,
                              child: Transform.translate(
                                offset:
                                Offset(0, _cardSlide.value.dy * 60),
                                child: _buildLoginCard(theme, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => SweepGradient(
                      startAngle: 0,
                      endAngle: 6.283,
                      colors: [
                        Colors.transparent,
                        AdvantaColors.gold.withAlpha(80),
                        AdvantaColors.goldLight.withAlpha(140),
                        AdvantaColors.gold.withAlpha(80),
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        0.3,
                        _shimmer.value.clamp(0.0, 1.0),
                        0.7,
                        1.0
                      ],
                    ).createShader(bounds),
                    child: Container(
                      width: 100, height: 100,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                  Container(
                    width: 94, height: 94,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        AdvantaColors.primaryGreen,
                        AdvantaColors.deepForest
                      ]),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: SvgPicture.asset('assets/logo_kc.svg',
                          placeholderBuilder: (_) => const Icon(
                              Icons.agriculture_rounded,
                              color: Colors.white,
                              size: 36)),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('KROSCEK',
              style: AdvantaText.display.copyWith(
                  color: Colors.white, letterSpacing: 5, fontSize: 28)),
          const SizedBox(height: 6),
          Text('Crop Inspection and Check Result',
              style: AdvantaText.body2.copyWith(
                  color: Colors.white.withAlpha(150), letterSpacing: 2.5)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLoginCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AdvantaColors.deepForest
                    : AdvantaColors.primaryGreen.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.secondary.withAlpha(60)),
              ),
              child: Text('QA',
                  style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Selamat Datang',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text('Masuk dengan akun yang diberikan oleh Admin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined,
                  color: theme.colorScheme.secondary),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _isPasswordHidden,
            style: theme.textTheme.bodyLarge,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: theme.colorScheme.secondary),
              suffixIcon: GestureDetector(
                onTap: () => setState(
                        () => _isPasswordHidden = !_isPasswordHidden),
                child: Icon(
                  _isPasswordHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            AdvantaBanner.error(message: _errorMessage),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('MASUK'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    return Container(
      color: Colors.black.withAlpha(150),
      child: Center(
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              Text('Memverifikasi...', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
