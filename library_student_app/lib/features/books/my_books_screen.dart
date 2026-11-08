import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/utils/extensions.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../dashboard/data/models/book_model.dart';
import '../auth/presentation/providers/auth_provider.dart';

class MyBooksScreen extends ConsumerStatefulWidget {
  const MyBooksScreen({super.key});

  @override
  ConsumerState<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends ConsumerState<MyBooksScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Books'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedIndex,
                  backgroundColor: AppColors.systemGray6,
                  thumbColor: AppColors.systemGray5,
                  onValueChanged: (value) {
                    if (value != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIndex = value);
                    }
                  },
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                      child: Text(
                        'My Books',
                        style: TextStyle(
                          color: _selectedIndex == 0
                              ? CupertinoColors.white
                              : AppColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                      child: Text(
                        'Library Books',
                        style: TextStyle(
                          color: _selectedIndex == 1
                              ? CupertinoColors.white
                              : AppColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: dashboard.isLoading
                  ? const LoadingWidget()
                  : (_selectedIndex == 0
                      ? _buildMyBooks(dashboard.books)
                      : _buildAvailableBooks(dashboard.libraryBooks)),
            ),
                      ],
        ),
      ),
    );
  }

  Widget _buildMyBooks(List<BookModel> books) {
    if (books.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.book,
        title: 'No Books',
        subtitle: 'You haven\'t taken any books yet',
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: books.length,
      itemBuilder: (context, index) => _BookTile(book: books[index]),
    );
  }

  Widget _buildAvailableBooks(List<BookModel> allBooks) {
    final available = allBooks
        .where((b) => b.status == 'available' && b.availableCopies > 0)
        .toList();
    if (available.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.book_circle,
        title: 'No Books Available',
        subtitle: 'All books are currently issued. Check back later.',
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: available.length,
      itemBuilder: (context, index) {
        final book = available[index];
        return GlassContainer(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.book_fill,
                  color: AppColors.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      style: const TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (book.category != null && book.category!.isNotEmpty)
                          _chip(
                            book.category!,
                            AppColors.systemCyan,
                            AppColors.systemCyan.withValues(alpha: 0.14),
                          ),
                        _chip(
                          '${book.availableCopies} available',
                          AppColors.success,
                          AppColors.successBg,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final BookModel book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final isIssued = book.isIssued;
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.systemBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.book_solid,
              color: AppColors.systemBlue,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  book.author,
                  style: const TextStyle(
                    color: AppColors.secondaryLabel,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isIssued ? AppColors.warningBg : AppColors.successBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isIssued ? 'Issued' : 'Returned',
                        style: TextStyle(
                          color: isIssued ? AppColors.warning : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (book.issueDate != null)
                      Text(
                        'Issued: ${book.issueDate!.formatDate()}',
                        style: const TextStyle(
                          color: AppColors.tertiaryLabel,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (book.returnDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Returned: ${book.returnDate!.formatDate()}',
                    style: const TextStyle(
                      color: AppColors.tertiaryLabel,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
