import 'package:intl/intl.dart';

class Helpers {
  // Date Formatting
  static String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }
  
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }
  
  // Currency Formatting
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
  
  // Number Formatting
  static String formatNumber(double number) {
    final formatter = NumberFormat('#,##0.00', 'tr_TR');
    return formatter.format(number);
  }
  
  // Validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  static bool isValidPassword(String password) {
    // At least 6 characters
    return password.length >= 6;
  }

  // Description cleaning for internal tags
  static String cleanDescription(String description) {
    // Remove [CT#uuid] tags
    if (description.startsWith('[CT#')) {
      final closingBracketIndex = description.indexOf(']');
      if (closingBracketIndex != -1) {
        return description.substring(closingBracketIndex + 1).trim();
      }
    }
    return description;
  }
}
