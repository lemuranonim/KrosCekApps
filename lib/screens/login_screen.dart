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

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final GoogleSignInService _googleSignInService = GoogleSignInService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isAdmin = false;
  bool _isUser = false;
  bool _isPsp = false;
  String _errorMessage = '';
  bool _isLoading = false;
  bool _showEmailPasswordFields = false; // Flag to control visibility

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    if (!_isAdmin && !_isUser && !_isPsp) {
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
      if (_isUser) selectedRole = 'user';

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

    if (!_isAdmin && !_isUser && !_isPsp) {
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
      if (_isUser) selectedRole = 'user';

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

      if (selectedRole == 'admin' && adminEmails.contains(email)) {
        await prefs.setString('userRole', 'admin');
        if (mounted) context.go('/admin');
      } else if (selectedRole == 'psp' && pspEmails.contains(email)) {
        await prefs.setString('userRole', 'psp');
        if (mounted) context.go('/psp');
      } else if (selectedRole == 'user' && userEmails.contains(email)) {
        await prefs.setString('userRole', 'user');
        if (mounted) context.go('/home');
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
        const SnackBar(
          content: Text('Password reset email sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reset Password',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enter your email to receive a password reset link.'),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _resetPassword();
                        context.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Send'),
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

  Widget _buildRoleTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Checkbox(
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          activeColor: Colors.green[800],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      children: [
        _buildRoleTile(
          title: 'Admin',
          value: _isAdmin,
          onChanged: (value) {
            setState(() {
              _isAdmin = value ?? false;
              if (_isAdmin) {
                _isUser = false;
                _isPsp = false;
              }
            });
          },
        ),
        _buildRoleTile(
          title: 'User HSP',
          value: _isUser,
          onChanged: (value) {
            setState(() {
              _isUser = value ?? false;
              if (_isUser) {
                _isAdmin = false;
                _isPsp = false;
              }
            });
          },
        ),
        _buildRoleTile(
          title: 'User PSP',
          value: _isPsp,
          onChanged: (value) {
            setState(() {
              _isPsp = value ?? false;
              if (_isPsp) {
                _isAdmin = false;
                _isUser = false;
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
          // Background with gradient overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/login_background.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withAlpha(76),
                  BlendMode.darken,
                ),
              ),
            ),
          ),

          // Content
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Welcome
                    Column(
                      children: [
                        // Image.asset(
                        //   'assets/icon.png',
                        //   height: 80,
                        // ),
                        const SizedBox(height: 16),
                        Text(
                          'Sugêng Rawuh Lur...',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monggo login riyen',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Role Selection
                          _buildRoleSelector(),
                          const SizedBox(height: 20),

                          // Toggle button for email/password login
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showEmailPasswordFields = !_showEmailPasswordFields;
                              });
                            },
                            icon: Icon(
                              _showEmailPasswordFields
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.green[800],
                            ),
                            label: Text(
                              _showEmailPasswordFields
                                  ? 'Hide Email Login'
                                  : 'Show Email Login',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // Email/Password fields (conditionally visible)
                          if (_showEmailPasswordFields) ...[
                            const SizedBox(height: 16),

                            // Email Field
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordHidden = !_isPasswordHidden;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green[800],
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
                                  backgroundColor: Colors.green[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],

                          // Error Message
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red[700],
                                ),
                              ),
                            ),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  _showEmailPasswordFields ? 'utowo' : 'Login dengan',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Social Login Buttons
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _loginWithGoogle,
                                  icon: SvgPicture.asset(
                                    'assets/google_logo.svg',
                                    height: 20,
                                    width: 20,
                                  ),
                                  label: const Text('Continue with Google',
                                    style: TextStyle(
                                        color: Colors.black
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Colors.grey),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _loginWithApple,
                                  icon: const Icon(Icons.apple, color: Colors.black),
                                  label: const Text('Continue with Apple',
                                    style: TextStyle(
                                        color: Colors.black
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Colors.grey),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(76),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}