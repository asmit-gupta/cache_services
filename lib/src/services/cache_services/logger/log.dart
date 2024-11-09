part of '../cache_service.dart';

/// A custom logging class that provides different logging behaviors for debug and production modes.
///
/// This class wraps the `Logger` package and adds conditional logging based on the current build mode.
/// In debug mode, it logs messages of all levels (debug, info, warning, error).
/// In production mode, it only logs error messages to minimize performance impact and avoid exposing sensitive information.
class CustomLogger {
  /// The underlying logger instance from the `logger` package.
  final Logger _logger;

  /// A flag indicating whether the app is running in production mode.
  final bool _isProduction;

  /// Creates a new instance of [CustomLogger].
  ///
  /// Initializes the underlying [Logger] with custom settings and determines
  /// the current build mode using [kReleaseMode].
  /// [showLogs] - flag to control logs in debug mode.
  CustomLogger({required bool showLogs})
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 3,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.dateAndTime,
          ),
        ),
        _isProduction = kReleaseMode ? kReleaseMode : showLogs;

  /// Logs a debug message.
  ///
  /// This method only logs the message in debug mode (when [_isProduction] is false).
  ///
  /// [message] The debug message to be logged.
  void d(String message) {
    if (!_isProduction) {
      _logger.d(message);
    }
  }

  /// Logs an info message.
  ///
  /// This method only logs the message in debug mode (when [_isProduction] is false).
  ///
  /// [message] The info message to be logged.
  void i(String message) {
    if (!_isProduction) {
      _logger.i(message);
    }
  }

  /// Logs a warning message.
  ///
  /// This method only logs the message in debug mode (when [_isProduction] is false).
  ///
  /// [message] The warning message to be logged.
  void w(String message) {
    if (!_isProduction) {
      _logger.w(message);
    }
  }

  /// Logs an error message.
  ///
  /// This method logs the error message in both debug and production modes.
  /// It's designed to capture critical issues that need attention even in production environments.
  ///
  /// [message] The error message to be logged.
  /// [error] Optional. The error object associated with this log entry.
  /// [stackTrace] Optional. The stack trace associated with the error.
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    // Always log errors, even in production
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
