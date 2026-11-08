import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/deep_link_service.dart';
import '../../../../core/theme/app_colors.dart';

/// In-app "set a new password" screen, opened by the Firebase Auth
/// password-reset email link. The link's `oobCode` is captured by
/// [StudentDeepLinkService] and verified via [FirebaseAuth.confirmPasswordReset].
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _invalidLink = false;
  String? _accountEmail;

  @override
  void initState() {
    super.initState();
    _verifyLink();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyLink() async {
    final code = StudentDeepLinkService.instance.pendingResetCode.value;
    if (code == null || code.isEmpty) {
      setState(() => _invalidLink = true);
      return;
    }
    try {
      final info = await FirebaseAuth.instance.checkActionCode(code);
      setState(() => _accountEmail = info.data['email'] as String?);
    } catch (_) {
      setState(() => _invalidLink = true);
    }
  }

  Future<void> _submit() async {
    final code = StudentDeepLinkService.instance.pendingResetCode.value;
    if (code == null || code.isEmpty) {
      setState(() => _invalidLink = true);
      return;
    }
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (password.length < 6) {
      _showMessage('Error', 'New password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showMessage('Error', 'Passwords do not match.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: password,
      );
      StudentDeepLinkService.instance.clear();
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage(
        'Password Updated',
        'Your password has been reset. Please sign in.',
        goToAuth: true,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.code == 'expired-action-code'
          ? 'This reset link has expired. Request a new one.'
          : e.code == 'invalid-action-code'
          ? 'This reset link is invalid or already used.'
          : (e.message ?? 'Something went wrong.');
      _showMessage('Error', msg);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('Error', 'Something went wrong. Please try again.');
    }
  }

  void _showMessage(String title, String message, {bool goToAuth = false}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              if (goToAuth && context.mounted) {
                context.go('/auth');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Reset Password'),
      ),
      child: SafeArea(
        child: _invalidLink
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: AppColors.warning,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This password reset link is invalid or has expired.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryLabel),
                      ),
                      const SizedBox(height: 20),
                      CupertinoButton.filled(
                        onPressed: () => context.go('/auth'),
                        child: const Text('Go to Sign In'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_accountEmail != null) ...[
                      Text(
                        'Reset password for',
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _accountEmail!,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'Enter a new password for your account.',
                      style: TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.systemGray6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          CupertinoTextField(
                            controller: _passwordCtrl,
                            placeholder: 'New password',
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.systemGray6,
                            ),
                          ),
                          Container(height: 0.5, color: AppColors.separator),
                          CupertinoTextField(
                            controller: _confirmCtrl,
                            placeholder: 'Confirm new password',
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.systemGray6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _obscure = !_obscure),
                      child: const Text(
                        'Show password',
                        style: TextStyle(
                          color: AppColors.systemBlue,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Text(
                                'Save New Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
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
