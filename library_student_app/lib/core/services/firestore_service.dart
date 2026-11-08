import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final String ownerUid;

  FirestoreService(this.ownerUid);

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _students =>
      _userDoc(ownerUid).collection('students');
  CollectionReference<Map<String, dynamic>> get _seats =>
      _userDoc(ownerUid).collection('seats');
  CollectionReference<Map<String, dynamic>> get _books =>
      _userDoc(ownerUid).collection('books');
  CollectionReference<Map<String, dynamic>> get _fees =>
      _userDoc(ownerUid).collection('fees');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _userDoc(ownerUid).collection('attendance');

  Future<Map<String, dynamic>?> getDocument(String collection, String docId) async {
    final doc = await _userDoc(ownerUid).collection(collection).doc(docId).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    final snapshot = await _userDoc(ownerUid).collection(collection).get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument(
      String collection, String docId) {
    return _userDoc(ownerUid).collection(collection).doc(docId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(String collection) {
    return _userDoc(ownerUid).collection(collection).snapshots();
  }

  Future<Map<String, dynamic>?> getLibraryByOwnerId(String ownerId) async {
    final snapshot = await _userDoc(ownerId).collection('libraries').limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  /// Live library document (public fields: name/currency/seats/facilities) so
  /// the student dashboard auto-updates when the owner changes settings such
  /// as the currency symbol. A DOCUMENT snapshot (not a collection query) is
  /// used so field-only updates (e.g. `currency`) reliably re-emit.
  Stream<Map<String, dynamic>?> streamLibraryByOwner(String ownerId) {
    return _userDoc(ownerId)
        .collection('libraries')
        .doc('lib_$ownerId')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<Map<String, dynamic>?> getStudentById(String studentId) async {
    final doc = await _students.doc(studentId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getSeatById(String seatId) async {
    final doc = await _seats.doc(seatId).get();
    return doc.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllSeats() {
    return _seats.snapshots();
  }

  Future<List<Map<String, dynamic>>> getStudentBooks(String studentId) async {
    final snapshot = await _books.where('studentId', isEqualTo: studentId).get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Full library book catalog (every book doc, issued or not) — used for
  /// the public "available books" browser in the student portal.
  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final snapshot = await _books.get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentFees(String studentId) async {
    // NOTE: intentionally no server-side orderBy here. A `.where(...).orderBy(...)`
    // on `fees` requires a Firestore composite index (studentId + month), which is
    // not guaranteed to exist and throws a ParallelWaitError in the dashboard's
    // parallel load. Fetch with a single-field equality filter (no index needed)
    // and sort client-side so the dashboard never breaks on a missing index.
    final snapshot = await _fees
        .where('studentId', isEqualTo: studentId)
        .get();
    final fees = snapshot.docs.map((d) => d.data()).toList();
    fees.sort((a, b) {
      final amonth = (a['month'] ?? '').toString();
      final bmonth = (b['month'] ?? '').toString();
      return bmonth.compareTo(amonth);
    });
    return fees;
  }

  Future<List<Map<String, dynamic>>> getStudentAttendanceList({int limitDays = 60}) async {
    final snapshot = await _attendance
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limitDays)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<Map<String, dynamic>?> getAttendanceForDate(String dateKey) async {
    final doc = await _attendance.doc(dateKey).get();
    return doc.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamStudentNotifications(String studentId) {
    return _userDoc(ownerUid).collection('students').doc(studentId).collection('notifications').snapshots();
  }

  Stream<List<Map<String, dynamic>>> streamNotices() {
    return _userDoc(ownerUid)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList())
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  static Future<Map<String, dynamic>?> lookupLibraryByCode(String code) async {
    final doc = await _db.collection('library_registry').doc(code.toUpperCase()).get();
    return doc.data();
  }
}
