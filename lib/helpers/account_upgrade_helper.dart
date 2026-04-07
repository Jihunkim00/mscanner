import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mscanner/services/account_upgrade_service.dart';

class AccountUpgradeHelper {
  static Future<AccountUpgradeResult?> showUpgradeFlow(
      BuildContext context, {
        bool shouldContinueToPurchase = false,
      }) async {
    final action = await showCupertinoModalPopup<_UpgradeAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Upgrade account'),
        message: const Text('Sign in or create an account to keep your guest data.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_UpgradeAction.signInEmail),
            child: const Text('Sign in with email'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_UpgradeAction.createEmail),
            child: const Text('Create account with email'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_UpgradeAction.google),
            child: const Text('Continue with Google'),
          ),
          if (Platform.isIOS || Platform.isMacOS)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(_UpgradeAction.apple),
              child: const Text('Continue with Apple'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == null) return null;

    switch (action) {
      case _UpgradeAction.signInEmail:
        return _showEmailDialog(context, createMode: false, shouldContinueToPurchase: shouldContinueToPurchase);
      case _UpgradeAction.createEmail:
        return _showEmailDialog(context, createMode: true, shouldContinueToPurchase: shouldContinueToPurchase);
      case _UpgradeAction.google:
        return AccountUpgradeService.continueWithGoogle();
      case _UpgradeAction.apple:
        return AccountUpgradeService.continueWithApple();
    }
  }

  static Future<AccountUpgradeResult?> _showEmailDialog(
      BuildContext context, {
        required bool createMode,
        required bool shouldContinueToPurchase,
      }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final data = await showCupertinoDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(createMode ? 'Create account' : 'Sign in'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'Email',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: passwordController,
              obscureText: true,
              placeholder: 'Password',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(ctx).pop({
                'email': emailController.text.trim(),
                'password': passwordController.text,
              });
            },
            child: Text(createMode ? 'Create' : 'Sign in'),
          ),
        ],
      ),
    );

    if (data == null) return null;
    final email = data['email'] ?? '';
    final password = data['password'] ?? '';
    if (email.isEmpty || password.isEmpty) {
      return AccountUpgradeResult.failure('Please enter both email and password.');
    }

    final result = createMode
        ? await AccountUpgradeService.createEmailAccountAndUpgrade(email: email, password: password)
        : await AccountUpgradeService.signInExistingEmailAccount(email: email, password: password);

    if (!shouldContinueToPurchase || !result.success) return result;
    return AccountUpgradeResult(
      success: result.success,
      user: result.user,
      migrationPerformed: result.migrationPerformed,
      shouldContinueToPurchase: true,
      message: result.message,
      errorCode: result.errorCode,
    );
  }
}

enum _UpgradeAction { signInEmail, createEmail, google, apple }