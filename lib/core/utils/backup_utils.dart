/// Shared document ID resolution helper for backup/restore operations.
String pickBackupDocId(String collectionName, Map<String, dynamic> map, int index) {
  String? id;
  switch (collectionName) {
    case 'students':
      id = map['studentId'];
      break;
    case 'staff':
      id = map['staffId'];
      break;
    case 'seats':
      id = map['seatId'];
      break;
    case 'fees':
      id = map['feeId'];
      break;
    case 'books':
      id = map['bookId'];
      break;
    case 'book_transactions':
      id = map['transactionId'];
      break;
    case 'notifications':
      id = map['notificationId'];
      break;
    case 'seat_layouts':
      id = map['seatLayoutId'];
      break;
    case 'libraries':
      id = map['libraryId'];
      break;
    case 'activities':
      id = map['activityId'];
      break;
    case 'expenses':
      id = map['expenseId'];
      break;
    case 'notices':
      id = map['noticeId'];
      break;
    case 'attendance':
      id = map['date']?.toString();
      break;
    default:
      id = map['studentId'] ?? map['feeId'] ?? map['bookId'];
  }
  return (id?.toString().isNotEmpty ?? false)
      ? id!.toString()
      : '${DateTime.now().millisecondsSinceEpoch}_$index';
}

