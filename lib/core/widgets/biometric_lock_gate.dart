import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Wraps the application to enforce Biometric / PIN lock on app start and resume.
class BiometricLockGate extends StatefulWidget {
  final Widget child;

  const BiometricLockGate({super.key, required this.child});

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _maybeLockOnPause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocked) {
        _promptUnlock();
      }
    }
  }

  Future<void> _maybeLockOnPause() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _checkInitialLock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
      _promptUnlock();
    }
  }

  Future<void> _promptUnlock() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final success = await BiometricService.instance.authenticate(
        reason: 'Authenticate to access Library Manager',
      );
      if (success && mounted) {
        setState(() => _isLocked = false);
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Library Locked',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify your identity using fingerprint, face, or device PIN to continue.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _promptUnlock,
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text('Unlock App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
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

