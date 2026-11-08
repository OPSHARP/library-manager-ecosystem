import 'package:uuid/uuid.dart';
import '../models/book_model.dart';
import '../models/book_transaction_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class BookRepository {
  final FirestoreService _fs;

  BookRepository(this._fs);

  // ─── Streams ───

  Stream<List<BookModel>> getBooks({String? filter, String? category}) {
    return _fs.booksCol.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) {
        var books = snapshot.docs
            .map((doc) => BookModel.fromFirestore(doc))
            .toList();
        if (filter != null && filter != 'All') {
          books = books
              .where((b) => b.status.toLowerCase() == filter.toLowerCase())
              .toList();
        }
        if (category != null && category != 'All') {
          books = books.where((b) => b.category == category).toList();
        }
        return books;
      },
    );
  }

  Stream<List<BookTransactionModel>> getTransactions() {
    return _fs.bookTransactionsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransactionModel.fromFirestore(doc))
            .toList());
  }

  // ─── Categories (client-side from books stream) ───

  Stream<List<String>> getCategories() {
    return getBooks().map((books) {
      final cats = books
          .map((b) => b.category)
          .where((c) => c != null && c.isNotEmpty)
          .map((c) => c!)
          .toSet()
          .toList();
      cats.sort();
      return cats;
    });
  }

  // ─── Counts (from stream) ───

  Stream<int> getTotalBookCount() {
    return _fs.booksCol.snapshots().map((snap) => snap.docs.length);
  }

  Stream<int> getIssuedBookCount() {
    return _fs.booksCol
        .where('status', isEqualTo: 'issued')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ─── CRUD ───

  Future<String> addBook(BookModel book) async {
    final id = book.bookId.isEmpty ? const Uuid().v4() : book.bookId;
    final newBook = book.copyWith(createdAt: DateTime.now());
    final data = newBook.toFirestore();
    data['bookId'] = id;
    await _fs.booksCol.doc(id).set(data);
    AutoBackupService.instance.triggerBackup(_fs.uid);
    return id;
  }

  Future<void> updateBook(BookModel book) async {
    await _fs.booksCol.doc(book.bookId).update(book.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteBook(String bookId) async {
    await _fs.booksCol.doc(bookId).delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  // ─── Issue / Return ───

  Future<void> issueBook(
      String bookId, String studentId, String studentName) async {
    await _fs.firestore.runTransaction((transaction) async {
      final doc = await transaction.get(_fs.booksCol.doc(bookId));
      if (!doc.exists) return;

      final book = BookModel.fromFirestore(doc);
      if (book.availableCopies < 1) return;

      final lastCopy = book.availableCopies <= 1;
      final updated = book.copyWith(
        status: lastCopy ? 'issued' : 'available',
        availableCopies: book.availableCopies - 1,
        studentId: lastCopy ? studentId : null,
        studentName: lastCopy ? studentName : null,
        issueDate: lastCopy ? DateTime.now() : null,
      );

      transaction.update(_fs.booksCol.doc(bookId), updated.toFirestore());

      final txnId = const Uuid().v4();
      final txn = BookTransactionModel(
        transactionId: txnId,
        bookId: bookId,
        bookTitle: book.title,
        studentId: studentId,
        studentName: studentName,
        action: 'issued',
        issueDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      transaction.set(_fs.bookTransactionsCol.doc(txnId), txn.toFirestore());
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> returnBook(String bookId) async {
    await _fs.firestore.runTransaction((transaction) async {
      final doc = await transaction.get(_fs.booksCol.doc(bookId));
      if (!doc.exists) return;

      final book = BookModel.fromFirestore(doc);

      final newAvailable = (book.availableCopies + 1).clamp(0, book.totalCopies);
      final updated = book.copyWith(
        status: newAvailable > 0 ? 'available' : 'issued',
        availableCopies: newAvailable,
        studentId: null,
        studentName: null,
        issueDate: null,
        returnDate: DateTime.now(),
      );

      transaction.update(_fs.booksCol.doc(bookId), updated.toFirestore());

      final txnId = const Uuid().v4();
      final txn = BookTransactionModel(
        transactionId: txnId,
        bookId: bookId,
        bookTitle: book.title,
        studentId: book.studentId ?? '',
        studentName: book.studentName ?? '',
        action: 'returned',
        issueDate: null,
        returnDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      transaction.set(_fs.bookTransactionsCol.doc(txnId), txn.toFirestore());
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Returns ALL books currently issued to [studentId] and records a
  /// 'returned' transaction for each.
  ///
  /// Fast path: one query + a single Firestore BATCH (no per-book
  /// transaction/round-trip). A batch commit is a single network request, so
  /// deleting a student with N issued books takes ~1 round-trip instead of N
  /// sequential transactions. Chunked at 400 ops (each book = update + set)
  /// to stay under Firestore's 500-op batch limit.
  Future<void> returnBooksForStudent(String studentId) async {
    final snapshot = await _fs.booksCol
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'issued')
        .get();
    if (snapshot.docs.isEmpty) return;

    var batch = _fs.firestore.batch();
    int opCount = 0;
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      try {
        final book = BookModel.fromFirestore(doc);
        final newAvailable = (book.availableCopies + 1).clamp(0, book.totalCopies);
        final updated = book.copyWith(
          status: newAvailable > 0 ? 'available' : 'issued',
          availableCopies: newAvailable,
          studentId: null,
          studentName: null,
          issueDate: null,
          returnDate: now,
        );
        batch.update(doc.reference, updated.toFirestore());

        final txnId = const Uuid().v4();
        final txn = BookTransactionModel(
          transactionId: txnId,
          bookId: book.bookId,
          bookTitle: book.title,
          studentId: book.studentId ?? '',
          studentName: book.studentName ?? '',
          action: 'returned',
          issueDate: null,
          returnDate: now,
          createdAt: now,
        );
        batch.set(_fs.bookTransactionsCol.doc(txnId), txn.toFirestore());
        opCount += 2;

        if (opCount >= 400) {
          await batch.commit();
          batch = _fs.firestore.batch();
          opCount = 0;
        }
      } catch (_) {
        // Skip a single broken book — never fail the whole delete.
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }
}
