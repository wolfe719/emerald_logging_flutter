import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:emerald_logging_flutter/emerald_logging_flutter.dart';

class SampleClass {
  final String name;
  final int id;

  SampleClass({
    required this.name,
    required this.id,
  });

  static void printSomeLogs() {
    Elogger.finest("Finest message");
    Elogger.finest("Finest message with object - ${SampleClass(name: "John", id: 1)}");

    Elogger.finer("Finer message");
    Elogger.finer("Finer message with object - ${SampleClass(name: "John", id: 1)}");

    Elogger.fine("Fine message");
    Elogger.fine("Fine message with object - ${SampleClass(name: "John", id: 1)}");

    Elogger.config("Config message");
    Elogger.debug("Debug (Config) message");

    Elogger.info("Info message");
    Elogger.info("Info message with object - ${SampleClass(name: "John", id: 1)}");

    Elogger.warning("Warning message");
    try {
      throw Exception("Something bad happened");
    } catch (e) {
      Elogger.warning("Warning message with exception $e");
    }

    Elogger.severe("Error message with exception - ${Exception("Test Error")}");

    Elogger.shout("Shout message!!!");
    
    Elogger.info("Info message with a different logger name", loggerName: "Dio");
  }
}

class ExternalPackage {
  static void printSomeLogs() {
    Logger.root.config("Debug message");

    Logger.root.info("Info message");
    Logger.root.info("Info message with object - ${ExternalPackage()}");

    Logger.root.warning("Warning message");
    try {
      throw Exception("Something bad happened");
    } catch (e) {
      Logger.root.info("Warning message with exception $e");
    }

    Logger.root
        .severe("Error message with exception - ${Exception("Test Error")}");

    Logger("Isar").info("Info message with a different logger name");

    // throw Exception("This has been thrown");
  }
}

void main() {
  runZonedGuarded(() {
    runApp(MyApp());
    init();
  }, (error, stack) {
    // Catch and log crashes
    Elogger.severe('Unhandled error - $error', stackTrace: stack);
  });
}

void init() {
  // Init
  Elogger.init(
    config: EloggerConfig(
      printClassName: true,
      printMethodName: true,
      showDateTime: true,
      showDebugLogs: true,
    ),
  );
  if (kDebugMode) {
    // Send logs to debug console
    Elogger.registerListener(
      (record) => log(record.printable(), stackTrace: record.stackTrace),
    );
  }
  // Send logs to App Console
  Elogger.registerListener(
    (record) => LogConsole.add(
      OutputEvent(record.level, [record.printable()]),
      bufferSize: 1000, // Remember the last X logs
    ),
  );
  // You can also use "registerListener" to log to Crashlytics or any other services
  if (kReleaseMode) {
    Elogger.registerListener((record) {
      // Filter logs that may contain sensitive data
      if (record.loggerName != "App") return;
      if (record.message.contains("apiKey")) return;
      if (record.message.contains("password")) return;
      // Send logs to logging services
      // FirebaseCrashlytics.instance.log(record.message);
      // DatadogSdk.instance.logs?.info(record.message);
    });
  }
  SampleClass.printSomeLogs();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: <String, WidgetBuilder>{
        "home": (context) => HomeWidget(),
      },
      initialRoute: "home",
      theme: isDarkMode(context) ? ThemeData.dark() : ThemeData.light(),
    );
  }
}

bool isDarkMode(BuildContext context) {
  return MediaQuery.of(context).platformBrightness == Brightness.dark;
}

class HomeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () => SampleClass.printSomeLogs(),
              child: Text("Print some Logs")),
          TextButton(
              onPressed: () => ExternalPackage.printSomeLogs(),
              child: Text("Print some non-elogger Logs")),
          TextButton(
            onPressed: () async {
              await Future.delayed(Duration(milliseconds: 300));
              throw Exception("An exception has been thrown");
            },
            child: Text("Throw Exception"),
          ),
          SizedBox(height: 16),
          Center(
            child: TextButton(
                onPressed: () => LogConsole.open(context, dark: isDarkMode(context)),
                child: Text("Click here to open Logs Console")),
          ),
          SizedBox(height: 16),
          Center(
            child: TextButton(
                onPressed: () => RotatingLogConsole.open(context, dark: isDarkMode(context)),
                child: Text("or click here to open rotating Logs Console")),
          ),
        ],
      ),
    );
  }
}
