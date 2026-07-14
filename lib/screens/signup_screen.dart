import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/screens/preset_selection_screen.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _errorMessage;

  bool _emailValid = true;
  bool _passwordValid = true;
  bool _confirmPasswordValid = true;

  Future<void> _createAccount() async {
    // 기존 validate는 유지하되, 아래 onChanged 기반 에러도 함께 사용
    if (_formKey.currentState!.validate() &&
        _emailValid &&
        _passwordValid &&
        _confirmPasswordValid) {
      try {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PresetSelectionScreen()),
        );
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _validateEmail(String value) {
    setState(() {
      _emailValid =
          value.isNotEmpty && RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value);
    });
  }

  void _validatePassword(String value) {
    setState(() {
      _passwordValid = value.isNotEmpty;
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      _confirmPasswordValid =
          value == _passwordController.text && value.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    // UI tokens (Login/ChangePassword와 통일)
    const primaryOrange = Color(0xFFD8753B);
    final bgColor =
        isDarkMode ? const Color(0xFF0B0B0B) : const Color(0xFFEFEFF4);
    final cardColor = isDarkMode ? const Color(0xFF141414) : Colors.white;
    final fieldFill =
        isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF2F4F7);

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? hint,
      bool isError = false,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.45 : 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 상단 이미지 + 뒤로/닫기
                        Stack(
                          children: [
                            SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/images/login_header.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: fieldFill),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 10,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.25),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.25),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                localizations?.createAccount ??
                                    'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                localizations?.signup_subtitle ??
                                    'Create an account to save scans, manage presets, and access premium features.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  height: 1.35,
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: fieldDecoration(
                                  label: localizations?.signup_emailLabel ??
                                      'Email Address',
                                  icon: Icons.mail_outline,
                                  hint: localizations?.signup_emailHint ??
                                      'name@example.com',
                                ),
                                onChanged: _validateEmail,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) {
                                    return localizations
                                            ?.pleaseEnterValidEmail ??
                                        'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              if (!_emailValid)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    localizations?.pleaseEnterValidEmail ??
                                        'Please enter a valid email',
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: fieldDecoration(
                                  label: localizations?.password ?? 'Password',
                                  icon: Icons.lock_outline,
                                ),
                                onChanged: _validatePassword,
                                validator: (v) {
                                  final value = (v ?? '');
                                  if (value.isEmpty) {
                                    return localizations?.pleaseEnterPassword ??
                                        'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              if (!_passwordValid)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    localizations?.pleaseEnterPassword ??
                                        'Please enter your password',
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                style: TextStyle(
                                  fontFamily: 'SFPro',
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: fieldDecoration(
                                  label: localizations?.confirmPassword ??
                                      'Confirm Password',
                                  icon: Icons.lock_reset_outlined,
                                ),
                                onChanged: _validateConfirmPassword,
                                validator: (v) {
                                  final value = (v ?? '');
                                  if (value.isEmpty) {
                                    return localizations?.passwordsDoNotMatch ??
                                        'Passwords do not match';
                                  }
                                  if (value != _passwordController.text) {
                                    return localizations?.passwordsDoNotMatch ??
                                        'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              if (!_confirmPasswordValid)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    localizations?.passwordsDoNotMatch ??
                                        'Passwords do not match',
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      color: Colors.red,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Sign Up Button
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _createAccount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    localizations?.signUp ?? 'Sign Up',
                                    style: const TextStyle(
                                      fontFamily: 'SFPro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Already have account
                              Center(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text.rich(
                                    TextSpan(
                                      text: localizations?.alreadyHaveAccount ??
                                          'Already have an account? ',
                                      style: TextStyle(
                                        fontFamily: 'SFPro',
                                        color: isDarkMode
                                            ? Colors.white70
                                            : const Color(0xFF6B7280),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: localizations?.signup_logIn ??
                                              'Log in',
                                          style: TextStyle(
                                            fontFamily: 'SFPro',
                                            fontWeight: FontWeight.w800,
                                            color: primaryOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
