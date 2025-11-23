import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final GoogleSignInService _googleSignInService = GoogleSignInService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isAdmin = false;
  bool _isQa = false;
  bool _isPsp = false;
  bool _isHsp = false;
  bool _isPspHsp = false;
  bool _isPi = false;
  String _errorMessage = '';
  bool _isLoading = false;
  bool _showEmailPasswordFields = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Email and password cannot be empty!";
        _isLoading = false;
      });
      return;
    }

    if (!_isAdmin && !_isQa && !_isHsp && !_isPsp && !_isPspHsp && !_isPi) {
      setState(() {
        _errorMessage = "Please select a role before login.";
        _isLoading = false;
      });
      return;
    }

    final user = await _auth.signInWithEmailAndPassword(email, password);
    if (user != null) {
      String? selectedRole;
      if (_isAdmin) selectedRole = 'admin';
      if (_isPsp) selectedRole = 'psp';
      if (_isQa) selectedRole = 'qa';
      if (_isHsp) selectedRole = 'hsp';
      if (_isPspHsp) selectedRole = 'psphsp';
      if (_isPi) selectedRole = 'pi';

      await _redirectUserBasedOnRole(email, selectedRole!);
    } else {
      setState(() {
        _errorMessage = "Login failed! Please check your credentials.";
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (!_isAdmin && !_isQa && !_isHsp && !_isPsp && !_isPspHsp && !_isPi) {
      setState(() {
        _errorMessage = "Please select a role before login.";
        _isLoading = false;
      });
      return;
    }

    final user = await _googleSignInService.signInWithGoogle(forceSignIn: true);
    if (user != null) {
      String? selectedRole;
      if (_isAdmin) selectedRole = 'admin';
      if (_isPsp) selectedRole = 'psp';
      if (_isQa) selectedRole = 'qa';
      if (_isHsp) selectedRole = 'hsp';
      if (_isPspHsp) selectedRole = 'psphsp';
      if (_isPi) selectedRole = 'pi';

      await _auth.createUserInFirestoreIfNeeded(user.email, role: selectedRole!);
      await _redirectUserBasedOnRole(user.email, selectedRole);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', user.email);
      await prefs.setString('userName', user.email);
    } else {
      setState(() {
        _errorMessage = "Google Sign-In failed!";
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final email = appleCredential.email ?? "unknown@apple.com";
      final fullName = appleCredential.givenName ?? "Apple User";

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully logged in as $fullName ($email)"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Apple Sign-In is only available on iOS devices";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _redirectUserBasedOnRole(String email, String selectedRole) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      final roleData = await FirebaseFirestore.instance.collection('roles').get();
      final adminEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'adminEmails')
          .data()['emails'] as List<dynamic>;
      final pspEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'pspEmails')
          .data()['emails'] as List<dynamic>;
      final userEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'userEmails')
          .data()['emails'] as List<dynamic>;
      final swcEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'swcEmails')
          .data()['emails'] as List<dynamic>;
      final pspHspEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'pspHspEmails')
          .data()['emails'] as List<dynamic>;
      final piEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'piEmails')
          .data()['emails'] as List<dynamic>;

      if (selectedRole == 'admin' && adminEmails.contains(email)) {
        await prefs.setString('userRole', 'admin');
        if (mounted) context.go('/admin');
      } else if (selectedRole == 'psp' && pspEmails.contains(email)) {
        await prefs.setString('userRole', 'psp');
        if (mounted) context.go('/psp');
      } else if (selectedRole == 'qa' && userEmails.contains(email)) {
        await prefs.setString('userRole', 'qa');
        if (mounted) context.go('/qa');
      } else if (selectedRole == 'hsp' && swcEmails.contains(email)) {
        await prefs.setString('userRole', 'hsp');
        if (mounted) context.go('/hsp');
      } else if (selectedRole == 'psphsp' && pspHspEmails.contains(email)) {
        await prefs.setString('userRole', 'psphsp');
        if (mounted) context.go('/psphsp');
      } else if (selectedRole == 'pi' && piEmails.contains(email)) {
        await prefs.setString('userRole', 'pi');
        if (mounted) context.go('/pi');
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Login failed! Email doesn't match selected role.";
          });
        }
        _auth.signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email!";
      });
      return;
    }

    await _auth.resetPassword(email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset email sent'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(51),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_reset, size: 32, color: Colors.green[700]),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reset Password',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your email to receive a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.green[700]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _resetPassword();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Send Link', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleChip({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(
            colors: [Colors.green[700]!, Colors.green[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: value ? null : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.green[700]! : Colors.grey[200]!,
            width: value ? 2 : 1,
          ),
          boxShadow: value
              ? [
            BoxShadow(
              color: Colors.green.withAlpha(76),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: value ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: value ? Colors.white : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _buildRoleChip(
          title: 'Admin',
          value: _isAdmin,
          icon: Icons.admin_panel_settings,
          onChanged: (value) {
            setState(() {
              _isAdmin = value ?? false;
              if (_isAdmin) {
                _isQa = false;
                _isPsp = false;
                _isHsp = false;
                _isPspHsp = false;
                _isPi = false;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        _buildRoleChip(
          title: 'User QA',
          value: _isQa,
          icon: Icons.verified_user,
          onChanged: (value) {
            setState(() {
              _isQa = value ?? false;
              if (_isQa) {
                _isAdmin = false;
                _isPsp = false;
                _isHsp = false;
                _isPspHsp = false;
                _isPi = false;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        _buildRoleChip(
          title: 'User HSP',
          value: _isHsp,
          icon: Icons.health_and_safety,
          onChanged: (value) {
            setState(() {
              _isHsp = value ?? false;
              if (_isHsp) {
                _isAdmin = false;
                _isQa = false;
                _isPsp = false;
                _isPspHsp = false;
                _isPi = false;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        _buildRoleChip(
          title: 'User PSP (QA)',
          value: _isPsp,
          icon: Icons.psychology,
          onChanged: (value) {
            setState(() {
              _isPsp = value ?? false;
              if (_isPsp) {
                _isAdmin = false;
                _isQa = false;
                _isHsp = false;
                _isPspHsp = false;
                _isPi = false;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        _buildRoleChip(
          title: 'PSP (HSP)',
          value: _isPspHsp,
          icon: Icons.person_outline,
          onChanged: (value) {
            setState(() {
              _isPspHsp = value ?? false;
              if (_isPspHsp) {
                _isAdmin = false;
                _isQa = false;
                _isHsp = false;
                _isPsp = false;
                _isPi = false;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        _buildRoleChip(
          title: 'Plant Inspector',
          value: _isPi,
          icon: Icons.factory_rounded,
          onChanged: (value) {
            setState(() {
              _isPi = value ?? false;
              if (_isPi) {
                _isAdmin = false;
                _isQa = false;
                _isHsp = false;
                _isPsp = false;
                _isPspHsp = false;
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Premium gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green[800]!,
                  Colors.green[600]!,
                  Colors.green[700]!,
                ],
              ),
            ),
          ),

          // Pattern overlay
          Opacity(
            opacity: 0.1,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/login_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight - MediaQuery.of(context).padding.top),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo and Welcome
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo.png', // Path ke file gambar Anda
                                width: 60,         // Atur lebar agar sesuai dengan ukuran ikon sebelumnya
                                height: 60,        // Atur tinggi agar sesuai dengan ukuran ikon sebelumnya
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Sugêng Rawuh Lur...',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Monggo login riyen',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withAlpha(229),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Login Form Card
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(33),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Role Selection
                              _buildRoleSelector(),

                              const SizedBox(height: 24),

                              // Error Message
                              if (_errorMessage.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Social Login Buttons
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginWithGoogle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.grey[800],
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    side: BorderSide(color: Colors.grey[300]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset('assets/google_logo.svg', height: 22, width: 22),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginWithApple,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.apple, size: 22),
                                      SizedBox(width: 12),
                                      Text(
                                        'Continue with Apple',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'utowo',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Email/Password Toggle
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Column(
                                  children: [
                                    if (_showEmailPasswordFields) ...[
                                      // Email Field
                                      TextField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: Icon(Icons.email_outlined, color: Colors.green[700]),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: Colors.grey[200]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                                          ),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                      ),
                                      const SizedBox(height: 16),

                                      // Password Field
                                      TextField(
                                        controller: _passwordController,
                                        obscureText: _isPasswordHidden,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: Icon(Icons.lock_outline, color: Colors.green[700]),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey[600],
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordHidden = !_isPasswordHidden;
                                              });
                                            },
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: Colors.grey[200]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                                          ),
                                        ),
                                      ),

                                      // Forgot Password
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _showResetPasswordDialog,
                                          child: Text(
                                            'Passworde supe?',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Login Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[700],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                              : const Text(
                                            'LOGIN',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),
                                    ],

                                    // Toggle Button
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _showEmailPasswordFields = !_showEmailPasswordFields;
                                        });
                                      },
                                      icon: Icon(
                                        _showEmailPasswordFields
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.green[700],
                                      ),
                                      label: Text(
                                        _showEmailPasswordFields ? 'Hide Email Login' : 'Login with Email',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(112),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}