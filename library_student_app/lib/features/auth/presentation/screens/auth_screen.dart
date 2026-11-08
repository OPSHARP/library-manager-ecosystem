import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

enum _AuthMode { signIn, signUp }

/// Native iOS-styled authentication screen (email/password + Google).
///
/// Uses the iOS form-group look: fields stacked in a rounded card with hairline
/// separators, a segmented control to switch between sign in / create account,
/// and a full-width filled primary button.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _submitted = false;
  bool _isGoogleLoading = false;

  int _cooldownSecondsRemaining = 0;
  Timer? _cooldownTimer;
  int _failedAttempts = 0;

  static const String _failedAttemptsKey = 'auth_failed_attempts_student';
  static const String _cooldownUntilKey = 'auth_cooldown_until_student';

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
      final cooldownUntil = prefs.getInt(_cooldownUntilKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (cooldownUntil > now) {
        final remaining = ((cooldownUntil - now) / 1000).ceil();
        if (remaining > 0 && mounted) {
          _startCooldownTimer(remaining);
        }
      }
    } catch (_) {}
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSecondsRemaining = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSecondsRemaining = 0;
          _failedAttempts = 0;
        });
        _clearCooldownPrefs();
      } else {
        setState(() => _cooldownSecondsRemaining--);
      }
    });
  }

  Future<void> _recordFailedAttempt() async {
    _failedAttempts++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_failedAttemptsKey, _failedAttempts);
      if (_failedAttempts >= 5) {
        final cooldownUntil = DateTime.now().millisecondsSinceEpoch + 60000;
        await prefs.setInt(_cooldownUntilKey, cooldownUntil);
        _startCooldownTimer(60);
      }
    } catch (_) {}
  }

  Future<void> _clearCooldownPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_failedAttemptsKey);
      await prefs.remove(_cooldownUntilKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _emailError() {
    final v = _emailCtrl.text.trim();
    if (!_submitted) return null;
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
    return null;
  }

  String? _passwordError() {
    final v = _passwordCtrl.text;
    if (!_submitted) return null;
    if (v.isEmpty) return 'Password is required';
    if (_mode == _AuthMode.signUp && v.length < 6) return 'Minimum 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (_cooldownSecondsRemaining > 0) {
      _showMessage(
        context,
        'Too Many Attempts',
        'Please wait $_cooldownSecondsRemaining seconds before trying again.',
      );
      return;
    }

    setState(() => _submitted = true);
    if (_emailError() != null || _passwordError() != null) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final notifier = ref.read(authProvider.notifier);

    final String? error = _mode == _AuthMode.signIn
        ? await notifier.signInWithEmail(email, password)
        : await notifier.signUpWithEmail(email, password);

    if (error != null && mounted) {
      await _recordFailedAttempt();
      if (!mounted) return;
      _showMessage(
        context,
        _cooldownSecondsRemaining > 0 ? 'Account Locked' : 'Error',
        _cooldownSecondsRemaining > 0
            ? 'Too many failed attempts. Login locked for 60 seconds.'
            : error,
      );
    } else {
      await _clearCooldownPrefs();
    }
    // On success the router redirect takes over navigation automatically.
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final notifier = ref.read(authProvider.notifier);
    final error = await notifier.signInWithGoogle();
    if (mounted) {
      setState(() => _isGoogleLoading = false);
      if (error != null && !error.toLowerCase().contains('cancel')) {
        _showMessage(context, 'Google Sign-In', error);
      }
    }
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset Password'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'Email address',
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final email = ctrl.text.trim();
              if (email.isEmpty) {
                _showMessage(context, 'Error', 'Enter your email address');
                return;
              }
              final error =
                  await ref.read(authProvider.notifier).resetPassword(email);
              if (error != null && mounted) {
                _showMessage(context, 'Error', error);
              } else if (mounted) {
                _showMessage(context, 'Password Reset',
                    'If an account exists for $email, a reset link has been sent.');
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _fieldError(String? error) {
    if (error == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          error,
          style: const TextStyle(color: AppColors.error, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller, {
    required String placeholder,
    required IconData prefixIcon,
    required TextInputType keyboardType,
    required bool obscure,
    required TextInputAction action,
    required ValueChanged<String> onChanged,
    VoidCallback? onToggleObscure,
    VoidCallback? onSubmitted,
  }) {
    return CupertinoTextField(
      controller: controller,
      keyboardType: keyboardType,
      placeholder: placeholder,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const BoxDecoration(color: AppColors.systemGray6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 6, right: 12),
        child: Icon(prefixIcon, color: AppColors.secondaryLabel, size: 20),
      ),
      suffix: onToggleObscure != null
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onToggleObscure,
              child: Icon(
                obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                color: AppColors.secondaryLabel,
                size: 20,
              ),
            )
          : null,
      textInputAction: action,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.systemBlue, AppColors.systemIndigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.book_circle_fill,
                    color: CupertinoColors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Library Portal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to your student account',
                  style: TextStyle(fontSize: 15, color: AppColors.secondaryLabel),
                ),
                const SizedBox(height: 28),
                CupertinoSlidingSegmentedControl<_AuthMode>(
                  thumbColor: AppColors.systemGray5,
                  backgroundColor: AppColors.systemGray6,
                  groupValue: _mode,
                  onValueChanged: (value) {
                    if (value != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _mode = value;
                        _submitted = false;
                      });
                    }
                  },
                  children: const {
                    _AuthMode.signIn: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.label,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _AuthMode.signUp: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: AppColors.label,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  },
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
                      _buildField(
                        _emailCtrl,
                        placeholder: 'Email',
                        prefixIcon: CupertinoIcons.mail_solid,
                        keyboardType: TextInputType.emailAddress,
                        obscure: false,
                        action: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      Container(height: 0.5, color: AppColors.separator),
                      _buildField(
                        _passwordCtrl,
                        placeholder: 'Password',
                        prefixIcon: CupertinoIcons.lock_fill,
                        keyboardType: TextInputType.text,
                        obscure: _obscurePassword,
                        action: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onToggleObscure: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        onSubmitted: _submit,
                      ),
                    ],
                  ),
                ),
                _fieldError(_emailError()),
                _fieldError(_passwordError()),
                if (_cooldownSecondsRemaining > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.systemRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.systemRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.shield_lefthalf_fill, color: AppColors.systemRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Too many failed attempts. Try again in ${_cooldownSecondsRemaining}s',
                            style: const TextStyle(
                              color: AppColors.systemRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: (authState.isLoading || _isGoogleLoading || _cooldownSecondsRemaining > 0)
                        ? null
                        : _submit,
                    child: (authState.isLoading && !_isGoogleLoading)
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : Text(
                            _cooldownSecondsRemaining > 0
                                ? 'Locked (${_cooldownSecondsRemaining}s)'
                                : (_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                  ),
                ),
                if (_mode == _AuthMode.signIn) ...[
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showForgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppColors.systemBlue,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: Container(height: 0.5, color: AppColors.separator)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: AppColors.tertiaryLabel,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 0.5, color: AppColors.separator)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: (authState.isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.systemGray6,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _isGoogleLoading
                          ? const CupertinoActivityIndicator()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: CupertinoColors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: AppColors.systemBlue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    color: AppColors.label,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
