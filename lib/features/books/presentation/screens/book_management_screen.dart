import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../students/data/models/student_model.dart';
import '../../data/models/book_model.dart';
import '../providers/book_provider.dart';

class BookManagementScreen extends ConsumerStatefulWidget {
  const BookManagementScreen({super.key});

  @override
  ConsumerState<BookManagementScreen> createState() => _BookManagementScreenState();
}

class _BookManagementScreenState extends ConsumerState<BookManagementScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  final _filters = ['All', 'Available', 'Issued', 'Returned'];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final libraryId = ref.watch(libraryIdProvider);

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text('Books', style: AppTypography.headlineMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'Export PDF',
                      style: IconButton.styleFrom(
                        backgroundColor: context.cardBg,
                      ),
                      onPressed: () => _exportBookPdf(context),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showAddBookSheet(context, libraryId),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textTertiaryColor,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: 'Library'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filters.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final filter = _filters[index];
                              final isSelected = _selectedFilter == filter;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedFilter = filter);
                                  ref.read(bookFilterProvider.notifier).state = filter;
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
color: isSelected ? AppColors.primary : context.cardBg,
                                     borderRadius: BorderRadius.circular(10),
                                     border: !isSelected
                                         ? Border.all(color: context.borderColor.withValues(alpha: 0.3))
                                         : null,
                                   ),
                                   child: Center(
                                     child: Text(
                                       filter,
                                       style: AppTypography.labelMedium.copyWith(
                                         color: isSelected ? Colors.white : context.textSecondaryColor,
                                       ),
                                     ),
                                   ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: booksAsync.when(
                            data: (books) {
                              if (books.isEmpty) {
                                return EmptyState(
                                  icon: Icons.menu_book_rounded,
                                  title: 'No books yet',
                                  subtitle: 'Add books to track issues and returns',
                                  actionText: 'Add Book',
                                  onAction: () => _showAddBookSheet(context, libraryId),
                                );
                              }
                              return RefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: () async {
                                  ref.invalidate(booksStreamProvider);
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: books.length,
                                  itemBuilder: (context, index) => _BookTile(
                                    book: books[index],
                                    onTap: () => _showBookDetails(context, books[index], libraryId),
                                  ),
                                ),
                              );
                            },
                            loading: () => const SkeletonList(),
                            error: (e, _) => Center(child: Text('Error: $e', style: AppTypography.bodyMedium)),
                          ),
                        ),
                      ],
                    ),
                    _buildHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final repo = ref.watch(bookRepositoryProvider);

    return StreamBuilder(
      stream: repo.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final transactions = snapshot.data!;

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 48, color: context.textTertiaryColor),
                const SizedBox(height: 12),
                Text('No borrowing history yet', style: AppTypography.bodyMedium.copyWith(color: context.textTertiaryColor)),
                const SizedBox(height: 4),
                Text('Issue books to students to see history here', style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            final isIssued = txn.action == 'issued';
            final color = isIssued ? AppColors.warning : AppColors.accent;
            final time = txn.createdAt != null ? Formatters.relativeDate(txn.createdAt!) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
                 color: context.cardBg,
                 borderRadius: BorderRadius.circular(14),
                 border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
               ),
               child: Row(
                 children: [
                   Container(
                     width: 42, height: 42,
                     decoration: BoxDecoration(
                       color: color.withValues(alpha: 0.15),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Icon(
                       isIssued ? Icons.book_rounded : Icons.keyboard_return_rounded,
                       size: 20, color: color,
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(txn.bookTitle, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                         const SizedBox(height: 2),
                         Text(
                           isIssued ? 'Issued to ${txn.studentName}' : 'Returned by ${txn.studentName}',
                           style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isIssued ? 'ISSUED' : 'RETURNED',
                          style: AppTypography.badge.copyWith(color: color, fontSize: 9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(time, style: AppTypography.labelSmall),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBookSheet(BuildContext context, String? libraryId, {String? prefilledIsbn, String? prefilledTitle, String? prefilledAuthor, String? prefilledPublisher}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddBookSheet(
        libraryId: libraryId,
        prefilledIsbn: prefilledIsbn,
        prefilledTitle: prefilledTitle,
        prefilledAuthor: prefilledAuthor,
        prefilledPublisher: prefilledPublisher,
        onScanRequested: () async {
          Navigator.pop(ctx);
          final result = await context.push<Map<String, dynamic>>(AppRoutes.isbnScan);
          if (result != null && context.mounted) {
            _showAddBookSheet(
              context, libraryId,
              prefilledIsbn: result['isbn'] as String?,
              prefilledTitle: result['title'] as String?,
              prefilledAuthor: result['author'] as String?,
              prefilledPublisher: result['publisher'] as String?,
            );
          }
        },
      ),
    );
  }
  void _showBookDetails(BuildContext context, BookModel book, String? libraryId) {
    final lid = libraryId ?? 'local_library';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.surfaceCardLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(book.title, style: AppTypography.headlineMedium, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
            if (book.author.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('by ${book.author}', style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
            if (book.isbn != null && book.isbn!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('ISBN: ${book.isbn}', style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor)),
            ],
            if (book.publisher != null && book.publisher!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Publisher: ${book.publisher}', style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor)),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: [
                if (book.category != null && book.category!.isNotEmpty)
                  _DetailChip(Icons.category_rounded, book.category!),
                if (book.language != null && book.language!.isNotEmpty)
                  _DetailChip(Icons.language_rounded, book.language!),
                if (book.rackNumber != null && book.rackNumber!.isNotEmpty)
                  _DetailChip(Icons.inventory_rounded, 'Rack ${book.rackNumber}'),
                if (book.publishedYear != null)
                  _DetailChip(Icons.calendar_today_rounded, '${book.publishedYear}'),
                if (book.pages != null)
                  _DetailChip(Icons.description_rounded, '${book.pages} pages'),
                _DetailChip(Icons.content_copy_rounded, '${book.availableCopies}/${book.totalCopies} available'),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(book.status, context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(book.status.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: _statusColor(book.status, context))),
            ),
            if (book.studentName != null) ...[
              const SizedBox(height: 8),
              Text('Issued to: ${book.studentName}', style: AppTypography.bodyMedium),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (book.status == 'available' || (book.availableCopies > 0 && book.status == 'available')) ...[
                  Expanded(
                    child: NeonButton(
                      text: 'Issue',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showIssueSheet(context, book, lid);
                      },
                      icon: Icons.person_add_rounded,
                    ),
                  ),
                ],
                if (book.status == 'issued') ...[
                  Expanded(
                    child: NeonButton(
                      text: 'Return',
                      onPressed: () async {
                        await ref.read(bookRepositoryProvider).returnBook(book.bookId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      color: AppColors.accent,
                      icon: Icons.keyboard_return_rounded,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: context.surfaceColor,
                          title: const Text('Delete Book'),
                          content: Text('Delete "${book.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(dCtx, true), child: Text('Delete', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(bookRepositoryProvider).deleteBook(book.bookId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                    label: Text('Delete', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showIssueSheet(BuildContext context, BookModel book, String libraryId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _IssueBookSheet(book: book, libraryId: libraryId),
    );
  }

  Future<void> _exportBookPdf(BuildContext context) async {
    try {
      final booksAsync = ref.read(booksProvider);
      final books = booksAsync.valueOrNull;
      if (books == null || books.isEmpty) return;

      final libraryId = ref.read(libraryIdProvider) ?? '';
      final library = await ref.read(libraryRepositoryProvider).getLibrarySync(libraryId);
      final libraryName = library?.libraryName ?? 'Library';

      final bookMaps = books.map((b) => {
        'title': b.title,
        'author': b.author,
        'isbn': b.isbn ?? '-',
        'publisher': b.publisher ?? '-',
        'category': b.category ?? '-',
        'totalCopies': b.totalCopies,
        'availableCopies': b.availableCopies,
        'status': b.status,
      }).toList();

      final bytes = await ExportService.instance.getBookReportBytes(
        books: bookMaps,
        libraryName: libraryName,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(pdfBytes: bytes, title: 'Book Report'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export report: $e')),
        );
      }
    }
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'available': return AppColors.accent;
      case 'issued': return AppColors.warning;
      case 'returned': return AppColors.secondary;
      default: return context.textTertiaryColor;
    }
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceCardLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.textSecondaryColor),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 10, color: context.textSecondaryColor)),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  const _BookTile({required this.book, required this.onTap});

  Color _statusColor(BuildContext context) {
    switch (book.status) {
      case 'available': return AppColors.accent;
      case 'issued': return AppColors.warning;
      case 'returned': return AppColors.secondary;
      default: return context.textTertiaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
Container(
             width: 42, height: 42,
             decoration: BoxDecoration(
               color: _statusColor(context).withValues(alpha: 0.15),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Icon(
               book.status == 'issued' ? Icons.book_rounded : Icons.menu_book_rounded,
               size: 20, color: _statusColor(context),
             ),
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(book.title, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                 if (book.author.isNotEmpty) ...[
                   const SizedBox(height: 2),
                   Text('by ${book.author}', style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                 ],
                 if (book.studentName != null) ...[
                   const SizedBox(height: 2),
                   Text('Issued to: ${book.studentName}', style: AppTypography.bodySmall.copyWith(color: AppColors.warning), overflow: TextOverflow.ellipsis, maxLines: 1),
                 ],
               ],
             ),
           ),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: _statusColor(context).withValues(alpha: 0.15),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Text(book.status.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: _statusColor(context), fontSize: 10)),
           ),
          ],
        ),
      ),
    );
  }
}

class _IssueBookSheet extends ConsumerStatefulWidget {
  final BookModel book;
  final String libraryId;

  const _IssueBookSheet({required this.book, required this.libraryId});

  @override
  ConsumerState<_IssueBookSheet> createState() => _IssueBookSheetState();
}

class _IssueBookSheetState extends ConsumerState<_IssueBookSheet> {
  StudentModel? _selectedStudent;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsStreamProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.surfaceCardLight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Issue Book', style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(widget.book.title, style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor)),
          const SizedBox(height: 16),
          studentsAsync.when(
            data: (students) {
              final activeStudents = students.where((s) => s.isActive).toList();
              if (activeStudents.isEmpty) {
                return const Text('No active students available.');
              }
              return DropdownButtonFormField<StudentModel>(
                initialValue: _selectedStudent,
                decoration: const InputDecoration(
                  labelText: 'Select Student',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                items: activeStudents.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudent = val),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),
          NeonButton(
            text: 'Issue to Student',
            isLoading: _isSaving,
            onPressed: () async {
              if (_selectedStudent == null) return;
              setState(() => _isSaving = true);
              try {
                final repo = ref.read(bookRepositoryProvider);
                await repo.issueBook(
                  widget.book.bookId,
                  _selectedStudent!.studentId,
                  _selectedStudent!.name,
                );
                ref.read(activityRepositoryProvider).logActivity(
                  type: 'book_issued',
                  description: 'Issued "${widget.book.title}" to ${_selectedStudent!.name}',
                  relatedId: widget.book.bookId,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  setState(() => _isSaving = false);
                }
              }
            },
            width: double.infinity,
            icon: Icons.person_add_rounded,
          ),
        ],
      ),
    );
  }
}

class _AddBookSheet extends ConsumerStatefulWidget {
  final String? libraryId;
  final String? prefilledIsbn;
  final String? prefilledTitle;
  final String? prefilledAuthor;
  final String? prefilledPublisher;
  final VoidCallback onScanRequested;

  const _AddBookSheet({
    this.libraryId,
    this.prefilledIsbn,
    this.prefilledTitle,
    this.prefilledAuthor,
    this.prefilledPublisher,
    required this.onScanRequested,
  });

  @override
  ConsumerState<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends ConsumerState<_AddBookSheet> {
  late final TextEditingController titleController;
  late final TextEditingController authorController;
  late final TextEditingController isbnController;
  late final TextEditingController publisherController;
  final categoryController = TextEditingController();
  final rackController = TextEditingController();
  final yearController = TextEditingController();
  final languageController = TextEditingController();
  final pagesController = TextEditingController();
  final copiesController = TextEditingController(text: '1');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.prefilledTitle ?? '');
    authorController = TextEditingController(text: widget.prefilledAuthor ?? '');
    isbnController = TextEditingController(text: widget.prefilledIsbn ?? '');
    publisherController = TextEditingController(text: widget.prefilledPublisher ?? '');
  }

  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    isbnController.dispose();
    publisherController.dispose();
    categoryController.dispose();
    rackController.dispose();
    yearController.dispose();
    languageController.dispose();
    pagesController.dispose();
    copiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.surfaceCardLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Add Book', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onScanRequested,
                icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                label: Text('Scan ISBN', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: isbnController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'ISBN (optional)', prefixIcon: Icon(Icons.qr_code_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: titleController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Book Title *', prefixIcon: Icon(Icons.menu_book_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: authorController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Author', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: publisherController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Publisher', prefixIcon: Icon(Icons.business_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: categoryController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Category (e.g. Fiction, Textbook)', prefixIcon: Icon(Icons.category_rounded))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: rackController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Rack / Shelf', prefixIcon: Icon(Icons.inventory_rounded)))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: yearController, style: AppTypography.bodyMedium, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today_rounded)))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: languageController, style: AppTypography.bodyMedium, decoration: const InputDecoration(labelText: 'Language', prefixIcon: Icon(Icons.language_rounded)))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: pagesController, style: AppTypography.bodyMedium, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pages', prefixIcon: Icon(Icons.description_rounded)))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: copiesController, style: AppTypography.bodyMedium, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of Copies', prefixIcon: Icon(Icons.content_copy_rounded))),
            const SizedBox(height: 20),
            NeonButton(
              text: 'Add Book',
              isLoading: _isSaving,
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                setState(() => _isSaving = true);
                try {
                  final repo = ref.read(bookRepositoryProvider);
                  final copies = int.tryParse(copiesController.text.trim()) ?? 1;
                  await repo.addBook(BookModel(
                    bookId: '',
                    title: titleController.text.trim(),
                    author: authorController.text.trim(),
                    isbn: isbnController.text.trim().isEmpty ? null : isbnController.text.trim(),
                    publisher: publisherController.text.trim().isEmpty ? null : publisherController.text.trim(),
                    category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                    rackNumber: rackController.text.trim().isEmpty ? null : rackController.text.trim(),
                    publishedYear: int.tryParse(yearController.text.trim()),
                    language: languageController.text.trim().isEmpty ? null : languageController.text.trim(),
                    pages: int.tryParse(pagesController.text.trim()),
                    totalCopies: copies,
                    availableCopies: copies,
                  ));
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    setState(() => _isSaving = false);
                  }
                }
              },
              width: double.infinity,
              icon: Icons.add_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
