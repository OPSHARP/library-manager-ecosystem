import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/book_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return BookRepository(fs);
});

final bookFilterProvider = StateProvider<String>((ref) => 'All');

final booksStreamProvider = StreamProvider<List<BookModel>>((ref) {
  return ref.watch(bookRepositoryProvider).getBooks();
});

final booksProvider = Provider<AsyncValue<List<BookModel>>>((ref) {
  final booksAsync = ref.watch(booksStreamProvider);
  final filter = ref.watch(bookFilterProvider);

  return booksAsync.whenData((books) {
    if (filter == 'All') return books;
    return books.where((b) => b.status == filter.toLowerCase()).toList();
  });
});
