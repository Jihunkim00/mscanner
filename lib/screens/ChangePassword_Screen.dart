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
        _successMessage = AppLocalizations.of(context)?.passwordResetEmailSent ?? 'Password reset email sent. Please check your inbox.';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.passwordResetError ?? 'An error occurred while sending the password reset email.';
        _successMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoNavigationBarBackButton(
          color: isDarkMode ? Colors.white : Colors.black,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: isDarkMode ? Colors.black : Color(0xFFEFEFF4),
      ),
      backgroundColor: isDarkMode ? Colors.black : Color(0xFFEFEFF4),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations?.enterYourEmailtoResetPassword ?? 'Enter your email to reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'SFPro',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDarkMode ? Colors.white : Colors.black,
                  decoration: TextDecoration.none, // 노란 밑줄 없애기
                ),
              ),
              SizedBox(height: spacingBetweenTextAndInput), // 빈 공간 추가
              CupertinoTextField(
                controller: _emailController,
                placeholder: localizations?.email ?? 'Email',
                placeholderStyle: TextStyle(fontFamily: 'SFPro',color: isDarkMode ? Colors.white54 : Colors.grey),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                style: TextStyle(fontFamily: 'SFPro', color: isDarkMode ? Colors.white : Colors.black),
              ),
              SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: Colors.red,
                      fontSize: 14,
                      decoration: TextDecoration.none, // 오류 메시지 밑줄 없애기
                    ),
                  ),
                ),
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    _successMessage!,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      color: Colors.lightBlue,
                      fontSize: 14,
                      decoration: TextDecoration.none, // 성공 메시지 밑줄 없애기
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _sendPasswordResetEmail,
                child: Container(
                  width: double.infinity, // 버튼의 너비를 조절합니다.
                  height: 50, // 버튼의 높이를 조절합니다.
                  decoration: BoxDecoration(
                    color: Colors.blue, // 버튼의 배경색을 조절합니다.
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    localizations?.sendResetLink ?? 'Send Reset Link',
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 16,
                      color: Colors.white,
                      decoration: TextDecoration.none, // 글씨 밑줄 없애기
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
