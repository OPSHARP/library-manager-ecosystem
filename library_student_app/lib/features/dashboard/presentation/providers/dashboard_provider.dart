import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/services/firestore_service.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/student_model.dart';
import '../../data/models/seat_model.dart';
import '../../data/models/book_model.dart';
import '../../data/models/fee_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/library_model.dart';

final firestoreServiceProvider = Provider.family<FirestoreService, String>(
  (ref, ownerUid) => FirestoreService(ownerUid),
);

final studentRepositoryProvider = Provider.family<StudentRepository, String>((
  ref,
  ownerUid,
) {
  final service = ref.watch(firestoreServiceProvider(ownerUid));
  return StudentRepository(service);
});

class DashboardState {
  final StudentModel? student;
  final LibraryModel? library;
  final SeatModel? assignedSeat;
  final List<SeatModel> allSeats;
  final List<BookModel> books;
  final List<BookModel> libraryBooks;
  final List<FeeModel> fees;
  final List<AttendanceModel> attendance;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.student,
    this.library,
    this.assignedSeat,
    this.allSeats = const [],
    this.books = const [],
    this.libraryBooks = const [],
    this.fees = const [],
    this.attendance = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    StudentModel? student,
    LibraryModel? library,
    SeatModel? assignedSeat,
    List<SeatModel>? allSeats,
    List<BookModel>? books,
    List<BookModel>? libraryBooks,
    List<FeeModel>? fees,
    List<AttendanceModel>? attendance,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      student: student ?? this.student,
      library: library ?? this.library,
      assignedSeat: assignedSeat ?? this.assignedSeat,
      allSeats: allSeats ?? this.allSeats,
      books: books ?? this.books,
      libraryBooks: libraryBooks ?? this.libraryBooks,
      fees: fees ?? this.fees,
      attendance: attendance ?? this.attendance,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Whether the owner has registered this student (full personal data mode).
  bool get isVerified => student != null;

  /// Currency symbol shown on fee amounts — taken LIVE from the library doc so
  /// it matches whatever the owner selected (defaults to $ when unknown).
  String get currency => (library?.currency ?? '').isEmpty
      ? '\$'
      : library!.currency;

  int get totalSeats => allSeats.length;
  int get freeSeats => allSeats.where((s) => s.isAvailable).length;
  List<String> get seatCategories =>
      allSeats.map((s) => s.category).toSet().toList()..sort();

  /// Books currently available to borrow from the library catalog.
  List<BookModel> get availableBooks => libraryBooks
      .where((b) => b.status == 'available' && b.availableCopies > 0)
      .toList();

  double get totalPaid =>
      fees.where((f) => f.isPaid).fold(0, (sum, f) => sum + f.amount);
  double get totalPending => fees
      .where((f) => f.isPending || f.isOverdue)
      .fold(0, (sum, f) => sum + f.amount);
  int get presentDays => attendance.fold(0, (sum, day) {
    return sum +
        day.records.where((r) => r.studentId == student?.studentId).length;
  });
  int get totalAttendanceDays => attendance.length;
  int get missedDays => totalAttendanceDays - presentDays;
  int get issuedBooksCount => books.where((b) => b.isIssued).length;
  int get returnedBooksCount => books.where((b) => b.isReturned).length;
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final String _ownerUid;
  final String _studentId;
  final StudentRepository _repo;
  StreamSubscription<LibraryModel?>? _librarySub;

  DashboardNotifier(this._ownerUid, this._studentId, this._repo)
    : super(const DashboardState(isLoading: true)) {
    _loadAll();
    // LIVE library doc — when the owner changes the currency (or any public
    // field), already-joined students' dashboards update in place instead of
    // keeping the stale symbol. Subscribed ONLY when a library is actually
    // joined: with an empty ownerUid the doc reference would be invalid
    // (users//libraries/…) and throw synchronously, blanking every screen
    // that watches this provider (Home + Profile).
    if (_ownerUid.isNotEmpty) {
      _librarySub = _repo.streamLibrary(_ownerUid).listen(
        (lib) {
          if (lib != null && state.library != null) {
            state = state.copyWith(library: lib);
          }
        },
        onError: (_) {
          // Transient read errors (offline/permission) must never blank the
          // dashboard — the last known library state stays on screen.
        },
      );
    }
  }

  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    if (_ownerUid.isEmpty) {
      state = const DashboardState(isLoading: false);
      return;
    }

    // Load each section independently so a transient/permission-denied (or
    // missing-index failure in one collection NEVER takes down the whole home
    // screen with a ParallelWaitError. Each helper swallows its own error and returns
    // a safe empty/null so the dashboard always renders.
    Future<T?> guard<T>(Future<T?> Function() fn) async {
      try {
        return await fn();
      } catch (_) {
        return null;
      }
    }

    // Public data — fragmented reads make the first paint much faster AND are
    // resilient to a denied collection (see _guard above). Run them in
    // parallel so the dashboard paints in ~1 network round-trip instead of 4.
    final libraryF = guard<LibraryModel>(() => _repo.getLibrary(_ownerUid));
    final seatsF = guard<List<SeatModel>>(() => _repo.streamAllSeats().first);
    final booksF = guard<List<BookModel>>(() => _repo.getAllBooks());
    final studentF = guard<StudentModel>(() => _repo.getStudent(_studentId));
    final results = await Future.wait<Object?>([
      libraryF,
      seatsF,
      booksF,
      studentF,
    ]);
    final library = results[0] as LibraryModel?;
    final allSeats = (results[1] as List<SeatModel>?) ?? const <SeatModel>[];
    final libraryBooks = (results[2] as List<BookModel>?) ?? const <BookModel>[];
    final student = results[3] as StudentModel?;

    if (student == null) {
      state = DashboardState(
        student: null,
        library: library,
        allSeats: allSeats,
        libraryBooks: libraryBooks,
        isLoading: false,
      );
      return;
    }

    // Personal data — each loaded independently so a denied fee/attendance
    // record read empties that section instead of erroring the whole screen.
    // All four run in parallel for the same single-round-trip reason.
    final seatF = guard<SeatModel>(
      () => student.seatId != null
          ? _repo.getSeat(student.seatId!)
          : Future<SeatModel?>.value(null),
    );
    final booksF2 = guard<List<BookModel>>(
      () => _repo.getStudentBooks(student.studentId),
    );
    final feesF2 = guard<List<FeeModel>>(
      () => _repo.getStudentFees(student.studentId),
    );
    final attF = guard<List<AttendanceModel>>(
      () => _repo.getAllAttendance(studentId: student.studentId),
    );
    final personal = await Future.wait<Object?>([
      seatF,
      booksF2,
      feesF2,
      attF,
    ]);
    final seat = personal[0] as SeatModel?;
    final books = (personal[1] as List<BookModel>?) ?? const <BookModel>[];
    final fees = (personal[2] as List<FeeModel>?) ?? const <FeeModel>[];
    final attendance =
        (personal[3] as List<AttendanceModel>?) ?? const <AttendanceModel>[];

    state = DashboardState(
      student: student,
      library: library,
      assignedSeat: seat,
      allSeats: allSeats,
      libraryBooks: libraryBooks,
      books: books,
      fees: fees,
      attendance: attendance,
      isLoading: false,
    );
  }

  Future<void> refresh() => _loadAll();

  @override
  void dispose() {
    _librarySub?.cancel();
    super.dispose();
  }
}

/// Family keyed by a record. Records use structural equality, so passing a
/// fresh `(ownerUid: …, studentId: …)` on every rebuild reuses the cached
/// provider instead of spinning up a new notifier (a Map key would not).
typedef DashboardParams = ({String ownerUid, String studentId});

final dashboardProvider =
    StateNotifierProvider.family<
      DashboardNotifier,
      DashboardState,
      DashboardParams
    >((ref, params) {
      final repo = ref.watch(studentRepositoryProvider(params.ownerUid));
      return DashboardNotifier(params.ownerUid, params.studentId, repo);
    });
