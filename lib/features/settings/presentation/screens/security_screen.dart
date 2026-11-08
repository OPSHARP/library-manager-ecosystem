import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/services/biometric_service.dart';

/// Security Screen - Device management, 2FA, biometric lock
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.instance.isAvailable();
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                    const SizedBox(width: 8),
                    Text('Security', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Device management
                      Text('Device Management', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      _DeviceTile(
                        device: 'Samsung Galaxy S24',
                        lastActive: 'Active now',
                        isCurrentDevice: true,
                      ),
                      _DeviceTile(
                        device: 'Chrome on Windows',
                        lastActive: '2 hours ago',
                        isCurrentDevice: false,
                      ),
                      const SizedBox(height: 16),

                      // Two-factor auth
                      Text('Two-Factor Authentication', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shield_rounded, size: 22, color: AppColors.warning),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SMS Verification', style: AppTypography.labelLarge),
                                  Text('Add an extra layer of security', style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                            Switch(
                              value: _twoFactorEnabled,
                              onChanged: (v) {
                                setState(() => _twoFactorEnabled = v);
                                context.showSuccess(v ? '2FA enabled' : '2FA disabled');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Biometric Lock
                      Text('Biometric Lock', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fingerprint_rounded, size: 22, color: AppColors.accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fingerprint / Face ID', style: AppTypography.labelLarge),
                                  Text(
                                    _biometricAvailable
                                        ? 'Unlock app with biometrics'
                                        : 'Not available on this device',
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _biometricEnabled,
                              onChanged: _biometricAvailable
                                  ? (v) async {
                                      if (v) {
                                        // Authenticate before enabling
                                        final authenticated = await BiometricService.instance.authenticate(
                                          reason: 'Verify your identity to enable biometric lock',
                                        );
                                        if (!authenticated) return;
                                      }
                                      setState(() => _biometricEnabled = v);
                                      await BiometricService.instance.setBiometricEnabled(v);
                                      if (context.mounted) {
                                        context.showSuccess(v ? 'Biometric lock enabled' : 'Biometric lock disabled');
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
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

class _DeviceTile extends StatelessWidget {
  final String device;
  final String lastActive;
  final bool isCurrentDevice;

  const _DeviceTile({
    required this.device,
    required this.lastActive,
    required this.isCurrentDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isCurrentDevice
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.devices_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(device, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis)),
                    if (isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('THIS DEVICE', style: AppTypography.badge.copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ],
                ),
                Text(lastActive, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (!isCurrentDevice)
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}
