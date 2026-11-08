import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/utils/extensions.dart';
import '../providers/join_requests_provider.dart';

class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(joinRequestsProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.darkSurface,
        middle: const Text('Join Requests', style: TextStyle(color: AppColors.textPrimary)),
        previousPageTitle: 'Back',
      ),
      child: SafeArea(
        child: requestsAsync.when(
          loading: () => const LoadingWidget(message: 'Loading requests...'),
          error: (err, stack) => Center(
            child: Text('Error: $err', style: const TextStyle(color: CupertinoColors.destructiveRed)),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return _buildEmpty();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final req = requests[index];
                return _RequestTile(request: req);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(CupertinoIcons.person_3_fill, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text('No pending requests', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  const _RequestTile({required this.request});

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _isProcessing = false;

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      final uid = widget.request['uid'] as String;
      await ref.read(joinRequestRepositoryProvider).acceptRequest(uid);
      if (mounted) context.showSuccess('Student accepted successfully!');
    } catch (e) {
      if (mounted) context.showError('Failed to accept request.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _isProcessing = true);
    try {
      final uid = widget.request['uid'] as String;
      await ref.read(joinRequestRepositoryProvider).declineRequest(uid);
      if (mounted) context.showSuccess('Request declined.');
    } catch (e) {
      if (mounted) context.showError('Failed to decline request.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request['name'] ?? 'Unknown';
    final phone = widget.request['phone'] ?? '';
    final address = widget.request['address'] ?? '';
    final uniqueId = widget.request['studentUniqueId'] ?? '';

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  uniqueId,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (phone.isNotEmpty)
            Row(
              children: [
                const Icon(CupertinoIcons.phone_fill, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(CupertinoIcons.location_solid, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CupertinoActivityIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: CupertinoColors.destructiveRed,
                    onPressed: _handleDecline,
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: AppColors.primary,
                    onPressed: _handleAccept,
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
