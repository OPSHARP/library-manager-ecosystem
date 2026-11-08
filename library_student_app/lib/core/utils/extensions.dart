import 'package:flutter/cupertino.dart';

extension ContextExtensions on BuildContext {
  void showSnackBar(String message, {String title = 'Message'}) {
    showCupertinoDialog(
      context: this,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void showError(String message) => showSnackBar(message, title: 'Error');
  void showSuccess(String message) => showSnackBar(message, title: 'Success');
}

extension DateTimeFormatting on DateTime {
  String formatDate() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${day.toString().padLeft(2, '0')} ${months[month - 1]} $year';
  }

  String formatTime() {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  String formatDateTime() => '${formatDate()}, ${formatTime()}';

  String toFirestoreKey() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
