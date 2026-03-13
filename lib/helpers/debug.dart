import 'package:flutter/foundation.dart'; // Import for debugPrint

class LogHelper {
  static const String _endColor = "\x1B[0m";
  static const String _red = "\x1B[31m";
  static const String _green = "\x1B[32m";
  static const String _yellow = "\x1B[33m";
  static const String _blue = "\x1B[34m";

  static void error(String message) {
    debugPrint('$_red🚨 ERROR: $message$_endColor');
  }

  static void info(String message) {
    debugPrint('$_blue💡 INFO: $message$_endColor');
  }

  static void success(String message) {
    debugPrint('$_green✅ SUCCESS: $message$_endColor');
  }

  static void warning(String message) {
    debugPrint('$_yellow⚠️ WARNING: $message$_endColor');
  }
}
