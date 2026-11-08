import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../presentation/providers/settings_provider.dart';

/// Library Settings Screen - Working hours, fee structure, seat settings
class LibrarySettingsScreen extends ConsumerStatefulWidget {
  const LibrarySettingsScreen({super.key});

  @override
  ConsumerState<LibrarySettingsScreen> createState() => _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends ConsumerState<LibrarySettingsScreen> {
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);
  String _defaultFeePlan = 'Monthly';
  double _defaultFeeAmount = 2500;
  bool _autoAllocateSeats = true;
  bool _lateFeeEnabled = true;
  int _lateFeeDays = 5;
  double _lateFeeAmount = 100;

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
                    Text('Library Settings', style: AppTypography.headlineSmall),
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

                      // Working Hours
                      Text('Working Hours', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Opens',
                                time: _openTime,
                                onTap: () async {
                                  final time = await showTimePicker(context: context, initialTime: _openTime);
                                  if (time != null && mounted) setState(() => _openTime = time);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Closes',
                                time: _closeTime,
                                onTap: () async {
                                  final time = await showTimePicker(context: context, initialTime: _closeTime);
                                  if (time != null && mounted) setState(() => _closeTime = time);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Fee Structure
                      Text('Default Fee Structure', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Default Plan', style: AppTypography.labelLarge),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: ['Monthly', 'Quarterly', 'Half-Yearly', 'Yearly'].map((plan) {
                                final isSelected = _defaultFeePlan == plan;
                                return GestureDetector(
                                  onTap: () => setState(() => _defaultFeePlan = plan),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.accent : context.cardBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: !isSelected ? Border.all(color: context.borderColor.withValues(alpha: 0.3)) : null,
                                    ),
                                    child: Text(plan, style: AppTypography.labelMedium.copyWith(
                                      color: isSelected ? Colors.white : context.textSecondaryColor)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Text('Default Amount', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            Text('${ref.watch(settingsProvider).currencySymbol}${_defaultFeeAmount.toStringAsFixed(0)}', style: AppTypography.headlineMedium.copyWith(color: AppColors.accent)),
                            Slider(
                              value: _defaultFeeAmount,
                              min: 500,
                              max: 10000,
                              divisions: 19,
                              label: '${ref.watch(settingsProvider).currencySymbol}${_defaultFeeAmount.toStringAsFixed(0)}',
                              onChanged: (v) => setState(() => _defaultFeeAmount = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Seat Settings
                      Text('Seat Settings', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Auto-allocate Seats', style: AppTypography.labelLarge),
                                  Text('Automatically assign nearest available seat', style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoAllocateSeats,
                              onChanged: (v) => setState(() => _autoAllocateSeats = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Late Fee Settings
                      Text('Late Fee Policy', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_rounded, color: AppColors.warning, size: 20),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Enable Late Fees', style: AppTypography.labelLarge),
                                      Text('Charge late fee after due date', style: AppTypography.bodySmall),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _lateFeeEnabled,
                                  onChanged: (v) => setState(() => _lateFeeEnabled = v),
                                ),
                              ],
                            ),
                            if (_lateFeeEnabled) ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Grace Period', style: AppTypography.bodyMedium),
                                  Text('$_lateFeeDays days', style: AppTypography.labelLarge.copyWith(color: AppColors.warning)),
                                ],
                              ),
                              Slider(
                                value: _lateFeeDays.toDouble(),
                                min: 1,
                                max: 15,
                                divisions: 14,
                                label: '$_lateFeeDays days',
                                onChanged: (v) => setState(() => _lateFeeDays = v.round()),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Late Fee Amount', style: AppTypography.bodyMedium),
                                  Text('${ref.watch(settingsProvider).currencySymbol}${_lateFeeAmount.toStringAsFixed(0)}', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
                                ],
                              ),
                              Slider(
                                value: _lateFeeAmount,
                                min: 50,
                                max: 500,
                                divisions: 9,
                                label: '${ref.watch(settingsProvider).currencySymbol}${_lateFeeAmount.toStringAsFixed(0)}',
                                onChanged: (v) => setState(() => _lateFeeAmount = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      NeonButton(
                        text: 'Save Settings',
                        onPressed: () async {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('settings')
                                .doc('library')
                                .set({
                              'openHour': _openTime.hour,
                              'openMinute': _openTime.minute,
                              'closeHour': _closeTime.hour,
                              'closeMinute': _closeTime.minute,
                              'defaultFeePlan': _defaultFeePlan,
                              'defaultFeeAmount': _defaultFeeAmount,
                              'autoAllocateSeats': _autoAllocateSeats,
                              'lateFeeEnabled': _lateFeeEnabled,
                              'lateFeeDays': _lateFeeDays,
                              'lateFeeAmount': _lateFeeAmount,
                            }, SetOptions(merge: true));
                            if (context.mounted) {
                              context.showSuccess('Settings saved');
                              context.pop();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showError('Failed to save settings');
                            }
                          }
                        },
                        width: double.infinity,
                        icon: Icons.check_rounded,
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

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: context.textTertiaryColor),
                const SizedBox(width: 8),
                Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
