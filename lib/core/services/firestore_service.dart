import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralizes all Firestore collection references scoped under users/{uid}/
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  FirestoreService({required this.uid});

  // ─── User document ───
  DocumentReference<Map<String, dynamic>> get userDoc =>
      _firestore.collection('users').doc(uid);

  // ─── Data subcollections ───
  CollectionReference<Map<String, dynamic>> get studentsCol =>
      _firestore.collection('users').doc(uid).collection('students');

  CollectionReference<Map<String, dynamic>> get staffCol =>
      _firestore.collection('users').doc(uid).collection('staff');

  CollectionReference<Map<String, dynamic>> get seatsCol =>
      _firestore.collection('users').doc(uid).collection('seats');

  CollectionReference<Map<String, dynamic>> get seatLayoutsCol =>
      _firestore.collection('users').doc(uid).collection('seat_layouts');

  CollectionReference<Map<String, dynamic>> get attendanceCol =>
      _firestore.collection('users').doc(uid).collection('attendance');

  CollectionReference<Map<String, dynamic>> get feesCol =>
      _firestore.collection('users').doc(uid).collection('fees');

  CollectionReference<Map<String, dynamic>> get booksCol =>
      _firestore.collection('users').doc(uid).collection('books');

  CollectionReference<Map<String, dynamic>> get bookTransactionsCol =>
      _firestore.collection('users').doc(uid).collection('book_transactions');

  CollectionReference<Map<String, dynamic>> get notificationsCol =>
      _firestore.collection('users').doc(uid).collection('notifications');

  CollectionReference<Map<String, dynamic>> studentNotificationsCol(String studentId) =>
      _firestore.collection('users').doc(uid).collection('students').doc(studentId).collection('notifications');

  CollectionReference<Map<String, dynamic>> get librariesCol =>
      _firestore.collection('users').doc(uid).collection('libraries');

  CollectionReference<Map<String, dynamic>> get expensesCol =>
      _firestore.collection('users').doc(uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> get noticesCol =>
      _firestore.collection('users').doc(uid).collection('notices');

  CollectionReference<Map<String, dynamic>> get activitiesCol =>
      _firestore.collection('users').doc(uid).collection('activities');

  DocumentReference<Map<String, dynamic>> get settingsDoc =>
      _firestore.collection('users').doc(uid).collection('settings').doc('current');

  // ─── Auth credentials (top-level, not per-user) ───
  CollectionReference<Map<String, dynamic>> get authUsersCol =>
      _firestore.collection('users');

  // ─── Support tickets (top-level) ───
  CollectionReference<Map<String, dynamic>> get supportTicketsCol =>
      _firestore.collection('support_tickets');

  // ─── Firestore instance for transactions/batches ───
  FirebaseFirestore get firestore => _firestore;
}
