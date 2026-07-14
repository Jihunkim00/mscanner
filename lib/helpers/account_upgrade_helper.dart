import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/services/account_upgrade_service.dart';

class AccountUpgradeHelper {
  static Future<AccountUpgradeResult?> showUpgradeFlow(
    BuildContext context, {
    bool shouldContinueToPurchase = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final List<_UpgradeAction> orderedActions;
    if (Platform.isIOS || Platform.isMacOS) {
      orderedActions = [
        _UpgradeAction.apple,
        _UpgradeAction.google,
        _UpgradeAction.createEmail,
        _UpgradeAction.signInEmail,
      ];
    } else {
      orderedActions = [
        _UpgradeAction.google,
        _UpgradeAction.createEmail,
        _UpgradeAction.signInEmail,
      ];
    }

    final action = await showCupertinoModalPopup<_UpgradeAction>(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          primaryColor: CupertinoColors.systemBlue,
        ),
        child: CupertinoActionSheet(
          title: Text(l10n.premiumGuestSectionTitle),
          message: Text(l10n.premiumGuestSectionMessage),
          actions: orderedActions.map((item) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(item),
              child: Text(_actionLabel(l10n, item)),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.cancel,
              style: const TextStyle(
                color: CupertinoColors.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    if (action == null) return null;
    if (!context.mounted) return null;

    switch (action) {
      case _UpgradeAction.signInEmail:
        return _showEmailDialog(
          context,
          createMode: false,
          shouldContinueToPurchase: shouldContinueToPurchase,
        );
      case _UpgradeAction.createEmail:
        return _showEmailDialog(
          context,
          createMode: true,
          shouldContinueToPurchase: shouldContinueToPurchase,
        );
      case _UpgradeAction.google:
        return AccountUpgradeService.continueWithGoogle();
      case _UpgradeAction.apple:
        return AccountUpgradeService.continueWithApple();
    }
  }

  static String _actionLabel(AppLocalizations l10n, _UpgradeAction action) {
    switch (action) {
      case _UpgradeAction.apple:
        return l10n.continueWithApple;
      case _UpgradeAction.google:
        return l10n.continueWithGoogle;
      case _UpgradeAction.createEmail:
        return '${l10n.createAccount} ${l10n.email}';
      case _UpgradeAction.signInEmail:
        return '${l10n.login} ${l10n.email}';
    }
  }

  static Future<AccountUpgradeResult?> _showEmailDialog(
    BuildContext context, {
    required bool createMode,
    required bool shouldContinueToPurchase,
  }) async {
    final data = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (ctx) => _AccountUpgradeEmailScreen(createMode: createMode),
      ),
    );

    if (data == null) return null;
    final email = data['email'] ?? '';
    final password = data['password'] ?? '';
    if (email.isEmpty || password.isEmpty) {
      return AccountUpgradeResult.failure(
          'Please enter both email and password.');
    }

    final result = createMode
        ? await AccountUpgradeService.createEmailAccountAndUpgrade(
            email: email, password: password)
        : await AccountUpgradeService.signInExistingEmailAccount(
            email: email, password: password);

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

class _AccountUpgradeEmailScreen extends StatefulWidget {
  const _AccountUpgradeEmailScreen({required this.createMode});

  final bool createMode;

  @override
  State<_AccountUpgradeEmailScreen> createState() =>
      _AccountUpgradeEmailScreenState();
}

class _AccountUpgradeEmailScreenState
    extends State<_AccountUpgradeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showValidationError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _showValidationError = true);
      return;
    }
    Navigator.of(context).pop(<String, String>{
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final inputFill =
        isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF2F4F7);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.createMode ? l10n.createAccount : l10n.login),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.createMode
                      ? '${l10n.createAccount} ${l10n.email}'
                      : '${l10n.login} ${l10n.email}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.pleaseEnterValidEmail
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? l10n.pleaseEnterPassword
                      : null,
                ),
                if (_showValidationError) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${l10n.pleaseEnterValidEmail} / ${l10n.pleaseEnterPassword}',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: Text(
                        widget.createMode ? l10n.createAccount : l10n.login),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
