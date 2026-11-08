import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../app/router.dart';
import '../../presentation/providers/staff_provider.dart';
import '../../data/models/staff_model.dart';

/// Staff List Screen
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _shiftFilter = 'All';

  static const _shiftFilters = ['All', 'morning', 'afternoon', 'night', 'full_day'];

  static const _shiftColors = <String, Color>{
    'morning': Color(0xFFF59E0B),     // Amber - sunrise
    'afternoon': Color(0xFF3B82F6),   // Blue - sky
    'night': Color(0xFF8B5CF6),       // Violet - dark
    'full_day': Color(0xFF10B981),    // Emerald - all day
  };

  List<StaffModel> _applyFilter(List<StaffModel> staff) {
    if (_shiftFilter == 'All') return staff;
    return staff.where((s) => s.shift == _shiftFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProvider);

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
                    Text('Staff', style: AppTypography.headlineSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text('${staffAsync.valueOrNull?.length ?? 0} members', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              // Shift filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _shiftFilters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _shiftFilters[index];
                      final isSelected = _shiftFilter == filter;
                      final label = filter == 'All'
                          ? 'All'
                          : filter == 'full_day'
                              ? 'Full Day'
                              : filter[0].toUpperCase() + filter.substring(1);
                      final color = filter == 'All' ? AppColors.primary : (_shiftColors[filter] ?? AppColors.primary);
                      return GestureDetector(
                        onTap: () => setState(() => _shiftFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.2) : context.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? color : context.borderColor.withValues(alpha: 0.3),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (filter != 'All') ...[
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(label, style: AppTypography.labelMedium.copyWith(
                                color: isSelected ? color : context.textSecondaryColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: staffAsync.when(
                  data: (staff) {
                    final filtered = _applyFilter(staff);
                    return filtered.isEmpty
                        ? const EmptyState(icon: Icons.people_outline_rounded, title: 'No Staff Members', subtitle: 'Add staff to help manage your library')
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () async {
                              ref.invalidate(staffProvider);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final initials = s.name.isNotEmpty
                                    ? s.name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
                                    : '?';
                                final shiftColor = _shiftColors[s.shift] ?? AppColors.primary;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(14)),
                                  child: Row(children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(gradient: AppGradients.neonCyanBlue, borderRadius: BorderRadius.circular(14)),
                                      child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(s.name, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(s.roleDisplayName, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                                    ])),
                                    // Shift badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: shiftColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(s.shiftShortName, style: AppTypography.badge.copyWith(color: shiftColor)),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (s.isActive ? AppColors.accent : context.textTertiaryColor).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(s.isActive ? 'ACTIVE' : 'INACTIVE', style: AppTypography.badge.copyWith(color: s.isActive ? AppColors.accent : context.textTertiaryColor)),
                                    ),
                                  ]),
                                );
                              },
                            ),
                          );
                  },
                  loading: () => const SkeletonList(count: 5),
                  error: (e, _) => Center(child: Text('Error: $e', style: AppTypography.bodyMedium.copyWith(color: AppColors.error))),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addStaff),
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }
}
