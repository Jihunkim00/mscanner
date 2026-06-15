import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;

  // 빈 공간 크기를 조절할 변수 추가
  final double spacingBetweenTextAndInput = 20.0;

  Future<void> _sendPasswordResetEmail() async {
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text);
      setState(() {
        _successMessage = AppLocalizations.of(context)?.passwordResetEmailSent ??
            'Password reset email sent. Please check your inbox.';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.passwordResetError ??
            'An error occurred while sending the password reset email.';
        _successMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    const primaryOrange = Color(0xFFD8753B);
    final bgColor = isDarkMode ? const Color(0xFF0B0B0B) : const Color(0xFFEFEFF4);
    final cardColor = isDarkMode ? const Color(0xFF141414) : Colors.white;
    final fieldFill = isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF2F4F7);

    InputDecoration _fieldDecoration({
      required String label,
      required IconData icon,
      String? hint,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.45 : 0.18),
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
                      // 상단 이미지 + 닫기
                      Stack(
                        children: [
                          SizedBox(
                            height: 130,
                            width: double.infinity,
                            child: Image.asset(
                              'assets/images/login_header.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: fieldFill),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            top: 10,
                            child: Material(
                              color: Colors.black.withOpacity(0.25),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Material(
                              color: Colors.black.withOpacity(0.25),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Reset password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDarkMode ? Colors.white : const Color(0xFF111827),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              localizations?.enterYourEmailtoResetPassword ??
                                  'Enter your email to reset your password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                height: 1.35,
                                fontSize: 14,
                                color: isDarkMode ? Colors.white70 : const Color(0xFF6B7280),
                                decoration: TextDecoration.none,
                              ),
                            ),

                            SizedBox(height: spacingBetweenTextAndInput),

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: TextStyle(
                                fontFamily: 'SFPro',
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Email Address',
                                icon: Icons.mail_outline,
                                hint: 'name@example.com',
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'SFPro',
                                    color: Colors.red,
                                    fontSize: 14,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            if (_successMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Text(
                                  _successMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'SFPro',
                                    color: primaryOrange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),

                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _sendPasswordResetEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  localizations?.sendResetLink ?? 'Send Reset Link',
                                  style: const TextStyle(
                                    fontFamily: 'SFPro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}