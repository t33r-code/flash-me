import 'package:flutter/material.dart';

class AppLogger {
  static void info(String message) {
    debugPrint('ℹ️ INFO: $message');
  }

  static void debug(String message) {
    debugPrint('🐛 DEBUG: $message');
  }

  static void warning(String message) {
    debugPrint('⚠️ WARNING: $message');
  }

  static void error(String message, [StackTrace? stackTrace]) {
    debugPrint('❌ ERROR: $message');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void success(String message) {
    debugPrint('✅ SUCCESS: $message');
  }
}

class AppValidators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }
    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }
}
