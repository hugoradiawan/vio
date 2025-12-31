import 'package:flutter/foundation.dart';

/// Log level enumeration
enum LogLevel { debug, info, warning, error }

/// Static logger for global application logging
class VioLogger {
  static LogLevel _minLevel = LogLevel.debug;
  static String _prefix = 'Vio';

  VioLogger._();

  /// Initialize the logger with configuration
  static void initialize({
    LogLevel level = LogLevel.debug,
    String prefix = 'Vio',
  }) {
    _minLevel = level;
    _prefix = prefix;
  }

  /// Log a debug message
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log an info message
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a warning message
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '[$timestamp] $levelStr [$_prefix] $message';

    if (kDebugMode) {
      // ignore: avoid_print
      print(logMessage);
      if (error != null) {
        // ignore: avoid_print
        print('  Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('  Stack: $stackTrace');
      }
    }
  }
}

/// Instance-based logger for tagged logging
class Logger {
  final String tag;
  final LogLevel minLevel;

  const Logger(this.tag, {this.minLevel = LogLevel.debug});

  /// Log a debug message
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log an info message
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '[$timestamp] $levelStr [$tag] $message';

    if (kDebugMode) {
      // ignore: avoid_print
      print(logMessage);
      if (error != null) {
        // ignore: avoid_print
        print('  Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('  Stack: $stackTrace');
      }
    }
  }

  /// Create a child logger with a sub-tag
  Logger child(String subTag) {
    return Logger('$tag.$subTag', minLevel: minLevel);
  }
}

/// Global application logger
final appLogger = Logger('Vio');

/// Log extension for easy logging
extension LoggerExtension on Object {
  /// Log this object as debug
  void logDebug([String? tag]) {
    Logger(tag ?? runtimeType.toString()).debug(toString());
  }

  /// Log this object as info
  void logInfo([String? tag]) {
    Logger(tag ?? runtimeType.toString()).info(toString());
  }

  /// Log this object as warning
  void logWarning([String? tag]) {
    Logger(tag ?? runtimeType.toString()).warning(toString());
  }

  /// Log this object as error
  void logError([String? tag]) {
    Logger(tag ?? runtimeType.toString()).error(toString());
  }
}
