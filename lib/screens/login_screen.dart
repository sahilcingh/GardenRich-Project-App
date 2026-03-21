import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter/services.dart';

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
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _isLoading = false;

  Timer? _debounce;
  bool _emailExistsError = false;

  final Color _bgColor = const Color(0xFF2C3931);
  final Color _fieldColor = const Color(0xFF3F4D45);
  final Color _primaryGreen = const Color(0xFF16a34a);

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    if (_isLogin) return;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      if (_emailExistsError) setState(() => _emailExistsError = false);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('email', email.toLowerCase())
            .maybeSingle();

        if (mounted) {
          setState(() {
            _emailExistsError = res != null;
          });
        }
      } catch (e) {
        // Fails silently if table is empty or RLS blocks it
      }
    });
  }

  void _showErrorDialog(String title, String message) {
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
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
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

  // =====================================================================
  // 🌟 Sign Up OTP Verification Popup (Saves to Profiles Table!)
  // =====================================================================
  void _showSignUpOtpPopup(
    BuildContext context,
    String email,
    String name,
    String mobile,
  ) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _fieldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: _primaryGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Verify Email",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "We just sent a 6-digit code to:\n$email\n\nPlease note: The code will only arrive if you entered a valid, active email address.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "000000",
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        letterSpacing: 8,
                      ),
                      filled: true,
                      fillColor: _bgColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Enter the full 6-digit code"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          setState(() => isVerifying = true);
                          try {
                            final AuthResponse verifyRes = await Supabase
                                .instance
                                .client
                                .auth
                                .verifyOTP(
                                  email: email,
                                  token: otp,
                                  type: OtpType.signup,
                                );

                            if (verifyRes.user != null) {
                              await Supabase.instance.client
                                  .from('profiles')
                                  .upsert({
                                    'id': verifyRes.user!.id,
                                    'name': name,
                                    'email': email,
                                    'mobile': mobile,
                                    'role': 'USER',
                                  });
                            }

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              await _routeUserAfterLogin();
                            }
                          } catch (e) {
                            setState(() => isVerifying = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Invalid or expired code"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Verify & Login",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordPopup(BuildContext context) {
    int step = 1;
    bool isProcessing = false;

    final resetEmailController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();

    if (_emailController.text.isNotEmpty &&
        _emailController.text.contains('@')) {
      resetEmailController.text = _emailController.text;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _fieldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: _primaryGreen, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    step == 1
                        ? "Reset Password"
                        : step == 2
                        ? "Enter OTP Code"
                        : "Create New Password",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 1) ...[
                    Text(
                      "Enter your registered email. We will send you a 6-digit verification code.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "Email Address",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: _bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (step == 2) ...[
                    Text(
                      "Enter the 6-digit code we just sent to:\n${resetEmailController.text}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "000000",
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: _bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (step == 3) ...[
                    Text(
                      "Code verified! Please enter your new password below.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('new_password_field'),
                      controller: newPasswordController,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "New Password",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: _bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (step == 1) {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) return;
                            setState(() => isProcessing = true);
                            try {
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(email);
                              setState(() {
                                step = 2;
                                isProcessing = false;
                              });
                            } catch (e) {
                              setState(() => isProcessing = false);
                              Navigator.pop(context);
                              _showErrorDialog(
                                "Email Failed",
                                e.toString().replaceAll('Exception: ', ''),
                              );
                            }
                          } else if (step == 2) {
                            final otp = otpController.text.trim();
                            if (otp.length != 6) return;
                            setState(() => isProcessing = true);
                            try {
                              await Supabase.instance.client.auth.verifyOTP(
                                email: resetEmailController.text.trim(),
                                token: otp,
                                type: OtpType.recovery,
                              );
                              setState(() {
                                step = 3;
                                isProcessing = false;
                              });
                            } catch (e) {
                              setState(() => isProcessing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Invalid or expired code"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } else if (step == 3) {
                            final newPass = newPasswordController.text.trim();
                            if (newPass.length < 6) return;
                            setState(() => isProcessing = true);
                            try {
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(password: newPass),
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      "Password updated successfully!",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: _primaryGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() => isProcessing = false);
                              Navigator.pop(context);
                              _showErrorDialog(
                                "Update Failed",
                                e.toString().replaceAll('Exception: ', ''),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          step == 1
                              ? "Send Code"
                              : step == 2
                              ? "Verify"
                              : "Update Password",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _routeUserAfterLogin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('email', user.email!.trim().toLowerCase())
          .maybeSingle();

      final role = profileResponse?['role']?.toString().toUpperCase() ?? 'USER';

      if (mounted) {
        if (role == 'ADMIN') {
          context.go('/admin-home');
        } else {
          context.go('/home');
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showErrorDialog(
        "Missing Info",
        "Please enter both your email and password.",
      );
      return;
    }

    if (!_isLogin && _emailExistsError) {
      _showErrorDialog(
        "Email Taken",
        "This email is already registered. Please log in instead.",
      );
      return;
    }

    if (!_isLogin) {
      if (_nameController.text.trim().isEmpty ||
          _mobileController.text.trim().isEmpty) {
        _showErrorDialog(
          "Missing Info",
          "Please fill out all fields to create an account.",
        );
        return;
      }
      if (_mobileController.text.trim().length != 10) {
        _showErrorDialog(
          "Invalid Mobile",
          "Please enter exactly 10 digits for your mobile number.",
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _routeUserAfterLogin();
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.session == null && res.user != null) {
          if (mounted) {
            _showSignUpOtpPopup(
              context,
              _emailController.text.trim(),
              _nameController.text.trim(),
              _mobileController.text.trim(),
            );
          }
        } else if (res.user != null) {
          await Supabase.instance.client.from('profiles').upsert({
            'id': res.user!.id,
            'name': _nameController.text.trim(),
            'email': res.user!.email,
            'mobile': _mobileController.text.trim(),
            'role': 'USER',
          });
          await _routeUserAfterLogin();
        }
      }
    } catch (e) {
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
          } else if (errorMessage.contains("email not confirmed")) {
            friendlyMessage =
                "You haven't verified your email yet. Please check your inbox for the OTP code.";
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
              Icon(Icons.eco, color: _primaryGreen, size: 60),
              const SizedBox(height: 16),

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

              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.mail_outline,
                isEmail: true,
              ),

              if (!_isLogin && _emailExistsError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "This email is already registered. Please log in.",
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPasswordPopup(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(
                        top: 12,
                        bottom: 24,
                        right: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 32),

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

              GestureDetector(
                onTap: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _passwordController.clear();
                    _emailExistsError = false;
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

      inputFormatters: isPhone
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,

      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
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
