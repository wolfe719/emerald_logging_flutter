import "package:logging/logging.dart";
import 'package:stack_trace/stack_trace.dart';

typedef EloggerPrinter = String Function(EloggerRecord record);
typedef EloggerListener = void Function(EloggerRecord record);

/// Configuration options for [LogRecord]
class EloggerConfig {
  /// The name for the default Logger
  final String loggerName;

  /// Print the class name where the log was triggered
  final bool printClassName;

  /// Print the method name where the log was triggered
  final bool printMethodName;

  /// Print the date and time when the log occurred
  final bool showDateTime;

  /// Print logs with Debug severity
  final bool showDebugLogs;

  /// Print logs with a custom format
  /// If set, ignores all other print options
  final EloggerPrinter? printer;

  const EloggerConfig({
    this.loggerName = "App",
    this.printClassName = true,
    this.printMethodName = false,
    this.showDateTime = false,
    this.showDebugLogs = true,
    this.printer,
  });
}

/// Contains all the information about the [LogRecord]
/// and can be printed with [printable] based on [EloggerConfig]
class EloggerRecord {
  /// Original [LogRecord] from [Logger]
  final LogRecord logRecord;

  /// Print configuration
  final EloggerConfig config;

  /// [Logger] name
  final String loggerName;

  /// Log severity
  final Level level;

  /// Log message
  final String message;

  /// Log time
  final DateTime? time;

  /// [Error] stacktrace
  final StackTrace? stackTrace;

  /// Class name where the log was triggered
  final String? className;

  /// Method name where the log was triggered
  final String? methodName;

  EloggerRecord._(
    this.logRecord,
    this.config,
    this.loggerName,
    this.message,
    this.level,
    this.time,
    this.stackTrace,
    this.className,
    this.methodName,
  );

  /// Create a [EloggerRecord] from a [LogRecord]
  factory EloggerRecord.fromLogger(
    LogRecord record,
    EloggerConfig config,
  ) {
    // Get ClassName and MethodName
    final classAndMethodNames = _getClassAndMethodNames(_getLogFrame()!);
    String? className = classAndMethodNames.key;
    String? methodName = classAndMethodNames.value;
    // Get stacktrace from record stackTrace or record object
    StackTrace? stackTrace = record.stackTrace;
    if (record.stackTrace == null && record.object is Error)
      stackTrace = (record.object as Error).stackTrace;
    // Get message
    var message = record.message;
    // Maybe add object
    if (record.object != null) message += " - ${record.object}";
    // Build Flogger record
    return EloggerRecord._(
      record,
      config,
      record.loggerName,
      message,
      record.level,
      record.time,
      stackTrace,
      className,
      methodName,
    );
  }

  /// Convert the log to a printable [String]
  String printable() {
    if (config.printer != null) return config.printer!(this);
    var printedMessage = "";
    if (config.showDateTime && time != null) {
      printedMessage += "[${time!.toIso8601String()}] ";
    }
    printedMessage += "${_levelShort(level)}/";
    printedMessage += "$loggerName";
    if (className != null && config.printClassName) {
      if (methodName != null && config.printMethodName) {
        printedMessage += " $className#$methodName: ";
      } else {
        printedMessage += " $className: ";
      }
    } else if (methodName != null && config.printMethodName) {
      printedMessage += " $methodName: ";
    } else {
      printedMessage += ": ";
    }
    printedMessage += message;
    return printedMessage;
  }

  static String _levelShort(Level level) {
    if (level == Level.ALL) {
      return "AA";
    } else if (level == Level.OFF) {
      return "NO";
    } else if (level == Level.FINEST) {
      return "FZ";
    } else if (level == Level.FINER) {
      return "FP";
    } else if (level == Level.FINE) {
      return "FF";
    } else if (level == Level.CONFIG) {
      return "DD";
    } else if (level == Level.INFO) {
      return "II";
    } else if (level == Level.WARNING) {
      return "WW";
    } else if (level == Level.SEVERE) {
      return "EE";
    } else if (level == Level.SHOUT) {
      return "EEEE";
    } else {
      return "?";
    }
  }

  static Frame? _getLogFrame() {
    try {
      // Capture the frame where the log originated from the current trace
      final loggingLibrary = "package:logging/src/logger.dart";
      final loggingFlutterLibrary = "package:logging_flutter/src/elogger.dart";
      final currentFrames = Trace.current().frames.toList();
      // Remove all frames from the logging_flutter library
      currentFrames
          .removeWhere((element) => element.library == loggingFlutterLibrary);
      // Capture the last frame from the logging library
      final lastLoggerIndex = currentFrames
          .lastIndexWhere((element) => element.library == loggingLibrary);
      return currentFrames[lastLoggerIndex + 1];
    } catch (e) {}
    return null;
  }

  static MapEntry<String?, String?> _getClassAndMethodNames(Frame frame) {
    String? className;
    String? methodName;
    try {
      // This variable can be ClassName.MethodName or only a function name, when it doesn't belong to a class, e.g. main()
      final member = frame.member!;
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        className = member.split(".")[0];
      } else {
        className = "";
      }
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        methodName = member.split(".")[1];
      } else {
        methodName = member;
      }
    } catch (e) {}
    return MapEntry(className, methodName);
  }
}

/// Convenience singleton with static methods to
/// interact with [Logger]
/// Logs can be configured with [EloggerConfig]
/// Logs can be listened to with [EloggerListener]
abstract class Elogger {
  static EloggerConfig _config = EloggerConfig();
  static Logger _logger = Logger(_config.loggerName);

  Elogger._();

  /// Initialize the default [Logger] and set the [EloggerConfig]
  static void init({EloggerConfig config = const EloggerConfig()}) {
    _config = config;
    _logger = Logger(_config.loggerName);
    Logger.root.level = _config.showDebugLogs ? Level.ALL : Level.INFO;
  }

  /// Log a message with CONFIG [Level]
  static finest(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.FINEST,
    error: error,
  );

  /// Log a message with CONFIG [Level]
  static finer(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.FINER,
    error: error,
  );

  /// Log a message with CONFIG [Level]
  static fine(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.FINE,
    error: error,
  );

  /// Log a message with CONFIG [Level]
  static config(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.CONFIG,
    error: error,
  );

  /// Log a DEBUG message (with CONFIG [Level])
  static debug(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.CONFIG,
    error: error,
  );

  /// Log a message with INFO [Level]
  static info(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.INFO, 
    error: error,
  );

  /// Log a message with WARNING [Level]
  static warning(String message, {String? loggerName, Error? error}) => _log(
    message,
    loggerName: loggerName,
    severity: Level.WARNING,
    error: error,
  );

  /// Log a message with SEVERE [Level]
  static severe(String message, {StackTrace? stackTrace, String? loggerName}) =>
      _log(
        message,
        loggerName: loggerName,
        severity: Level.SEVERE,
        stackTrace: stackTrace,
      );

  /// Log a message with SHOUT [Level]
  static shout(String message, {StackTrace? stackTrace, String? loggerName}) =>
      _log(
        message,
        loggerName: loggerName,
        severity: Level.SHOUT,
        stackTrace: stackTrace,
      );

  static void _log(String message, 
      { String? loggerName, 
        required Level severity, 
        Error? error, 
        StackTrace? stackTrace, }) {
    if (loggerName == null) {
      // Main logger
      _logger.log(severity, message, error, stackTrace);
    } else {
      // Additional loggers
      Logger(loggerName)..log(severity, message, error, stackTrace);
    }
  }

  /// Register a listener to listen to all logs
  /// Logs are emitted as [EloggerRecord]
  static registerListener(EloggerListener onRecord) {
    Logger.root.onRecord
        .map((e) => EloggerRecord.fromLogger(e, _config))
        .listen(onRecord);
  }

  /// Clear all log listeners
  static clearListeners() {
    Logger.root.clearListeners();
  }
}
