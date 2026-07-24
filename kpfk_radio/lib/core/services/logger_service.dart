import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class LoggerService {
  static final Logger _logger = Logger('KPFKRadio');
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;

    // Debug builds: show INFO and above (FINE/debug diagnostics are dropped so
    // the console isn't flooded by per-tick playback/metadata logs).
    // Release builds: only SEVERE records reach the handler, and nothing is
    // printed to the console — production must not spam logcat.
    Logger.root.level = kDebugMode ? Level.INFO : Level.SEVERE;
    Logger.root.onRecord.listen((record) {
      if (record.error != null) {
        // Route errors to the uncaught-error handler (crash reporting hook).
        Zone.current.handleUncaughtError(
            record.error!, record.stackTrace ?? StackTrace.empty);
      }

      // Only print to the console during development.
      if (kDebugMode) {
        final message = '${record.level.name}: ${record.time}: '
            '${record.loggerName}: ${record.message}';
        // ignore: avoid_print
        print(message);
      }
    });

    _initialized = true;
  }

  static void info(String message) {
    _logger.info(message);
  }

  static void warning(String message) {
    _logger.warning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  static void debug(String message) {
    _logger.fine(message);
  }

  static void audioError(String message,
      [Object? error, StackTrace? stackTrace]) {
    _logger.severe('AudioService: $message', error, stackTrace);
  }

  static void webViewError(String message,
      [Object? error, StackTrace? stackTrace]) {
    _logger.severe('WebView: $message', error, stackTrace);
  }

  static void metadataError(String message,
      [Object? error, StackTrace? stackTrace]) {
    _logger.severe('Metadata: $message', error, stackTrace);
  }

  static void streamError(String message,
      [Object? error, StackTrace? stackTrace]) {
    _logger.severe('Stream: $message', error, stackTrace);
  }
}
