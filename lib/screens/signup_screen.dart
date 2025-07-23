import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/screens/PresetSelectionScreen.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _errorMessage;
  bool _emailValid = true;
  bool _passwordValid = true;
  bool _confirmPasswordValid = true;

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // PresetSelectionScreen으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PresetSelectionScreen()), // PresetSelectionScreen으로 변경
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
      _emailValid = value.isNotEmpty && RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value);
    });
  }

  void _validatePassword(String value) {
    setState(() {
      _passwordValid = value.isNotEmpty;
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      _confirmPasswordValid = value == _passwordController.text && value.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Color(0xFFEFEFF4),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 50),
                Text(
                  localizations?.createAccount ?? 'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'SFPro',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 50),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                CupertinoTextField(
                  controller: _emailController,
                  placeholder: localizations?.email ?? 'Email',
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: _emailValid ? Colors.grey : Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  placeholderStyle: TextStyle(fontFamily: 'SFPro', color: isDarkMode ? Colors.white54 : Colors.grey),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  onChanged: _validateEmail,
                ),
                if (!_emailValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      localizations?.pleaseEnterValidEmail ?? 'Please enter a valid email',
                      style: TextStyle(fontFamily: 'SFPro', color: Colors.red),
                    ),
                  ),
                SizedBox(height: 20),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: localizations?.password ?? 'Password',
                  padding: EdgeInsets.all(16),
                  obscureText: true,
                  decoration: BoxDecoration(
                    border: Border.all(color: _passwordValid ? Colors.grey : Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  placeholderStyle: TextStyle(fontFamily: 'SFPro', color: isDarkMode ? Colors.white54 : Colors.grey),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  onChanged: _validatePassword,
                ),
                if (!_passwordValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      localizations?.pleaseEnterPassword ?? 'Please enter your password',
                      style: TextStyle(fontFamily: 'SFPro', color: Colors.red),
                    ),
                  ),
                SizedBox(height: 20),
                CupertinoTextField(
                  controller: _confirmPasswordController,
                  placeholder: localizations?.confirmPassword ?? 'Confirm Password',
                  padding: EdgeInsets.all(16),
                  obscureText: true,
                  decoration: BoxDecoration(
                    border: Border.all(color: _confirmPasswordValid ? Colors.grey : Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  placeholderStyle: TextStyle(fontFamily: 'SFPro', color: isDarkMode ? Colors.white54 : Colors.grey),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  onChanged: _validateConfirmPassword,
                ),
                if (!_confirmPasswordValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      localizations?.passwordsDoNotMatch ?? 'Passwords do not match',
                      style: TextStyle(fontFamily: 'SFPro', color: Colors.red),
                    ),
                  ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _createAccount,
                  child: Text(
                    localizations?.signUp ?? 'Sign Up',
                    style: TextStyle(fontFamily: 'SFPro', fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 로그인 페이지로 돌아가기
                  },
                  child: Text.rich(
                    TextSpan(
                      text: localizations?.alreadyHaveAccount ?? 'Already have an account? ',
                      children: [
                        TextSpan(
                          text: localizations?.logIn ?? 'Log in',
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
