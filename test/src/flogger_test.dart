import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:emerald_logging_flutter/emerald_logging_flutter.dart';

void main() {
  group("Flogger", () {
    tearDown(() {
      Elogger.clearListeners();
    });
    test("captures logs emitted with Flogger", () {
      final message = "Test message";
      Elogger.registerListener((record) {
        expect(record.message, message);
        expect(record.level, Level.INFO);
      });
      Elogger.info(message);
    });
    test("captures logs emitted outside of Flogger", () {
      final message = "Test message";
      final loggerName = "TestLogger";
      Elogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.WARNING);
      });
      Logger(loggerName).warning(message);
    });
    test("logs to multiple Logger instances", () async {
      final message = "Test message";
      final loggerName1 = "TestLogger1";
      final loggerName2 = "TestLogger2";
      List<EloggerRecord> logs = [];
      Elogger.registerListener((record) {
        logs.add(record);
      });
      Logger(loggerName1).info(message);
      Logger(loggerName2).warning(message);
      expect(logs.length, 2);
      expect(logs[0].message, message);
      expect(logs[0].loggerName, loggerName1);
      expect(logs[0].level, Level.INFO);
      expect(logs[1].message, message);
      expect(logs[1].loggerName, loggerName2);
      expect(logs[1].level, Level.WARNING);
    });
    test("supports multiple listeners", () {
      final message = "Test message";
      final loggerName = "TestLogger";
      var count = 0;
      Elogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.SEVERE);
        count++;
      });
      Elogger.registerListener((record) {
        expect(record.message, message);
        expect(record.loggerName, loggerName);
        expect(record.level, Level.SEVERE);
        count++;
      });
      Logger(loggerName).severe(message);
      expect(count, 2);
    });
    test("clears all listeners", () {
      Elogger.registerListener((record) {
        fail("Should not be called");
      });
      Elogger.clearListeners();
      Elogger.info("message");
    });
    test("uses custom printer when provided", () {
      final printer = (record) {
        return "Custom printer: ${record.message}";
      };
      Elogger.init(config: EloggerConfig(printer: printer));
      Elogger.registerListener((record) {
        expect(record.printable(), "Custom printer: message");
      });
      Elogger.info("message");
    });
    test("uses FloggerConfig when printer is not provided", () {
      final loggerName = "TestLogger";
      Elogger.init(
        config: EloggerConfig(
          loggerName: loggerName,
          printClassName: false,
          printMethodName: false,
          showDateTime: false,
          showDebugLogs: true,
        ),
      );
      Elogger.registerListener((record) {
        print(record.printable());
        expect(record.printable(), "I/$loggerName: message");
      });
      Elogger.info("message");
    });
  });
}
