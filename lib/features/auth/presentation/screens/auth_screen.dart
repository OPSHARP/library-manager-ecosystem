import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _submitted = false;

  int _cooldownSecondsRemaining = 0;
  Timer? _cooldownTimer;
  int _failedAttempts = 0;

  static const String _failedAttemptsKey = 'auth_failed_attempts_owner';
  static const String _cooldownUntilKey = 'auth_cooldown_until_owner';

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
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _emailError() {
    if (!_submitted) return null;
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
    return null;
  }

  String? _passwordError() {
    if (!_submitted) return null;
    final v = _passwordCtrl.text;
    if (v.isEmpty) return 'Password is required';
    if (_mode == _AuthMode.signUp && v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submitEmailAuth() async {
    if (_cooldownSecondsRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many failed attempts. Please wait $_cooldownSecondsRemaining seconds.',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _submitted = true);
    if (_emailError() != null || _passwordError() != null) return;

    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();
    final auth = ref.read(authProvider.notifier);

    final String? error = _mode == _AuthMode.signIn
        ? await auth.signInWithEmail(email, password)
        : await auth.signUpWithEmail(email, password, displayName: name.isNotEmpty ? name : null);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      await _recordFailedAttempt();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cooldownSecondsRemaining > 0
                ? 'Too many failed attempts. Account locked for 60 seconds.'
                : error,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      await _clearCooldownPrefs();
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final auth = ref.read(authProvider.notifier);
    final error = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (error != null && !error.toLowerCase().contains('cancel')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password', style: AppTypography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address to receive a password reset link.',
              style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'name@example.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                filled: true,
                fillColor: context.scaffoldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              Navigator.pop(ctx);
              final err = await ref.read(authProvider.notifier).sendPasswordResetEmail(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    err ?? 'Password reset email sent. Please check your inbox.',
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                  ),
                  backgroundColor: err != null ? AppColors.error : AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Logo & Brand ───
                _buildHeader(),
                const SizedBox(height: 28),

                // ─── Mode Switcher (Sign In / Sign Up) ───
                _buildModeToggle(),
                const SizedBox(height: 20),

                // ─── Email / Password Form ───
                _buildEmailForm(),
                const SizedBox(height: 16),

                // ─── Submit Button ───
                _buildSubmitButton(),
                const SizedBox(height: 12),

                // ─── Forgot Password (Sign In mode only) ───
                if (_mode == _AuthMode.signIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ─── Divider: OR ───
                Row(
                  children: [
                    Expanded(child: Divider(color: context.borderColor.withValues(alpha: 0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.textTertiaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: context.borderColor.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Google Sign-In ───
                _buildGoogleButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Library Manager',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'and Owner',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: context.textTertiaryColor,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = _AuthMode.signIn;
                _submitted = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == _AuthMode.signIn ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: AppTypography.buttonText.copyWith(
                    color: _mode == _AuthMode.signIn ? Colors.white : context.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = _AuthMode.signUp;
                _submitted = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == _AuthMode.signUp ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: AppTypography.buttonText.copyWith(
                    color: _mode == _AuthMode.signUp ? Colors.white : context.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    final emailErr = _emailError();
    final passErr = _passwordError();

    return Column(
      children: [
        if (_mode == _AuthMode.signUp) ...[
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Library Name or Your Name',
              prefixIcon: const Icon(Icons.business_rounded, size: 20),
              filled: true,
              fillColor: context.cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'owner@example.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            errorText: emailErr,
            filled: true,
            fillColor: context.cardBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: _mode == _AuthMode.signUp ? 'Create password (min 6 chars)' : 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            errorText: passErr,
            filled: true,
            fillColor: context.cardBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isLocked = _cooldownSecondsRemaining > 0;
    return Column(
      children: [
        if (isLocked) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Too many attempts. Try again in ${_cooldownSecondsRemaining}s',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isLoading || isLocked) ? null : _submitEmailAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLocked ? AppColors.darkBorder : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    isLocked
                        ? 'Locked (${_cooldownSecondsRemaining}s)'
                        : (_mode == _AuthMode.signIn ? 'Sign In with Email' : 'Create Owner Account'),
                    style: AppTypography.buttonText,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: context.borderColor.withValues(alpha: 0.3)),
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontFamily: 'Product Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Continue with Google', style: AppTypography.buttonText),
                ],
              ),
      ),
    );
  }
}
