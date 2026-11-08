import 'package:intl/intl.dart';

/// Formatters for dates, currency, and text
class Formatters {
  Formatters._();

  // ─── Date Formatters ───
  static String date(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String dateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String monthShort(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  static String dayMonth(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  static String firestoreDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.isNegative) return 'Just now';

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  // ─── Currency Formatter ───
  static String currency(double amount, {String symbol = '\$', String locale = 'en_US'}) {
    final formatter = NumberFormat('#,##0.00', locale);
    return '$symbol${formatter.format(amount)}';
  }

  static String currencyCompact(double amount, {String symbol = '\$', String locale = 'en_US'}) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  // ─── Number Formatters ───
  static String number(int number, {String locale = 'en_US'}) {
    return NumberFormat('#,##0', locale).format(number);
  }

  static String percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  // ─── Phone Formatter ───
  static String phone(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0, 5)} ${phone.substring(5)}';
    }
    return phone;
  }

  // ─── Name Formatter ───
  static String initials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String titleCase(String text) {
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }
}
