import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  final bool initialIsLogin;
  const LoginScreen({super.key, this.initialIsLogin = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isLogin;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controllers for the Sign Up fields
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _isLoading = false;

  // Colors matched exactly to your screenshots
  final Color _bgColor = const Color(0xFF2C3931);
  final Color _fieldColor = const Color(0xFF3F4D45);
  final Color _primaryGreen = const Color(0xFF92D050);

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // 👇 Custom function to show a beautiful, themed error popup
  void _showErrorDialog(String title, String message) {
    // Safety check: Don't try to show a dialog if the screen is already closing
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _fieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "OK",
                style: TextStyle(
                  color: _primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _authenticate() async {
    // 1. Quick Validation: Make sure fields aren't empty first!
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showErrorDialog(
        "Missing Info",
        "Please enter both your email and password.",
      );
      return;
    }
    if (!_isLogin &&
        (_nameController.text.trim().isEmpty ||
            _mobileController.text.trim().isEmpty)) {
      _showErrorDialog(
        "Missing Info",
        "Please fill out all fields to create an account.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Logging in
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Signing up (Saving Name and Mobile to Supabase)
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': _nameController.text.trim(),
            'mobile': _mobileController.text.trim(),
            'role': 'USER',
          },
        );
      }

      // 👇 THE CRITICAL ROUTING UPDATE 👇
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.email != null) {
        // Ask Supabase what role this user is
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('email', user.email!.trim().toLowerCase())
            .maybeSingle();

        final role =
            profileResponse?['role']?.toString().toUpperCase() ?? 'USER';

        // Route perfectly based on role!
        if (mounted) {
          if (role == 'ADMIN') {
            context.go('/admin-home');
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      // 👇 BULLETPROOF ERROR CATCHING
      if (mounted) {
        String title = "Authentication Failed";
        String friendlyMessage = "Something went wrong. Please try again.";

        if (e is AuthException) {
          final errorMessage = e.message.toLowerCase();

          if (errorMessage.contains("invalid login credentials")) {
            friendlyMessage =
                "The email or password you entered is incorrect. Please double-check and try again.";
          } else if (errorMessage.contains("already registered")) {
            friendlyMessage =
                "An account with this email already exists. Please log in instead.";
          } else if (errorMessage.contains("password should be at least")) {
            friendlyMessage =
                "Your password is too weak. Please use at least 6 characters.";
          } else {
            friendlyMessage = e.message;
          }
        } else {
          title = "Oops!";
          friendlyMessage = e.toString();
        }

        _showErrorDialog(title, friendlyMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eco Leaf Logo
              Icon(Icons.eco, color: _primaryGreen, size: 60),
              const SizedBox(height: 16),

              // Title
              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 40),

              // Show Full Name and Mobile only if Sign Up mode
              if (!_isLogin) ...[
                _buildTextField(
                  controller: _nameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _mobileController,
                  hint: 'Mobile Number',
                  icon: Icons.phone_android,
                  isPhone: true,
                ),
                const SizedBox(height: 16),
              ],

              // Email Field
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.mail_outline,
                isEmail: true,
              ),
              const SizedBox(height: 16),

              // Password Field
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 32),

              // Login / Sign Up Button
              _isLoading
                  ? CircularProgressIndicator(color: _primaryGreen)
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isLogin ? "Log In" : "Sign Up",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              // Toggle Text
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _passwordController.clear();
                    if (_isLogin) {
                      _nameController.clear();
                      _mobileController.clear();
                    }
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: _isLogin
                            ? "New to GardenRich? "
                            : "Already have an account? ",
                      ),
                      TextSpan(
                        text: _isLogin ? "Sign Up" : "Log In",
                        style: TextStyle(
                          color: _primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to keep the form code clean and perfectly rounded
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : (isPhone ? TextInputType.phone : TextInputType.text),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Icon(icon, color: Colors.white),
        ),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
