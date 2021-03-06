import 'package:flutter/material.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:functional_listener/functional_listener.dart';

/// An object that can assist in representing the current state of Command while
/// testing different valueListenable of a Command. Basically a [List] with
/// initialize logic and null safe clear.
class Collector<T> {
  /// Holds a list of values being passed to this object.
  List<T> values;

  /// Initializes [values] adds the incoming [value] to it.
  call(T value) {
    values ??= <T>[];
    values.add(value);
  }

  /// Check null and clear the list.
  clear() {
    values?.clear();
  }

  reset() {
    clear();
    values = null;
  }
}

/// A Custom Exception that overrides == operator to ease object comparison i
/// inside a [Collector].
class CustomException implements Exception {
  String message;

  CustomException(this.message);

  @override
  bool operator ==(Object other) =>
      other is CustomException && other.message == message;

  @override
  String toString() => "CustomException: $message";
}

void main() {
  /// Create commonly used collector for all the valueListenable in a [Command].
  /// The collectors simply collect the values emitted by the ValueListenable
  /// into a list and keep it for comparison later.
  Collector<bool> canExecuteCollector = Collector<bool>();
  Collector<bool> isExecutingCollector = Collector<bool>();
  Collector<CommandResult> cmdResultCollector = Collector<CommandResult>();
  Collector<CommandError> thrownExceptionCollector = Collector<CommandError>();
  Collector pureResultCollector = Collector();

  /// A utility method to setup [Collector] for all the [ValueListenable] in a
  /// given command.
  void setupCollectors(Command command, {bool enablePrint = false}) {
    // Set up the collectors
    command.canExecute.listen((b, _) {
      canExecuteCollector(b);
      if (enablePrint) {
        print("Can Execute $b");
      }
    });
    // Setup is Executing listener only for async commands.
    if (command is CommandAsync) {
      command.isExecuting.listen((b, _) {
        isExecutingCollector(b);
        if (enablePrint) {
          print("Can Execute $b");
        }
      });
    }
    command.results.listen((cmdResult, _) {
      cmdResultCollector(cmdResult);
      if (enablePrint) {
        print("Can Execute $cmdResult");
      }
    });
    command.thrownExceptions.listen((cmdError, _) {
      thrownExceptionCollector(cmdError);
      if (enablePrint) {
        print("Can Execute $cmdError");
      }
    });
    command.listen((pureResult, _) {
      pureResultCollector(pureResult);
      if (enablePrint) {
        print("Can Execute $pureResult");
      }
    });
  }

  /// clear the common collectors before each test.
  setUp(() {
    canExecuteCollector.reset();
    isExecutingCollector.reset();
    cmdResultCollector.reset();
    thrownExceptionCollector.reset();
    pureResultCollector.reset();
  });

  group("Synchronous Command Testing", () {
    test('Execute simple sync action No Param No Result', () {
      int executionCount = 0;
      var command = Command.createSyncNoParamNoResult(() => executionCount++);

      expect(command.canExecute.value, true);

      // Setup collectors for the command.
      setupCollectors(command);

      command.execute();

      expect(command.canExecute.value, true);
      expect(executionCount, 1);

      // Verify the collectors values.
      expect(pureResultCollector.values, [null]);
      expect(cmdResultCollector.values, isNull);
      expect(thrownExceptionCollector.values, isNull);
    });

    test('Execute simple sync action with canExecute restriction', () async {
      // restriction true means command can execute
      // if restriction is false, then command cannot execute.
      // We test both cases in this test
      final restriction = ValueNotifier<bool>(true);

      var executionCount = 0;

      final command = Command.createSyncNoParamNoResult(() => executionCount++,
          restriction: restriction);

      expect(command.canExecute.value, true);

      // Setup Collectors
      setupCollectors(command);

      command.execute();

      expect(executionCount, 1);

      expect(command.canExecute.value, true);

      restriction.value = false;

      expect(command.canExecute.value, false);

      command.execute();

      expect(executionCount, 1);
    });

    test('Execute simple sync action with exception', () {
      final command = Command.createSyncNoParamNoResult(
          () => throw CustomException("Intentional"));

      setupCollectors(command);

      expect(command.canExecute.value, true);
      expect(command.thrownExceptions.value, null);

      command.execute();
      expect(command.results.value.error, isA<CustomException>());
      expect(command.thrownExceptions.value.error, isA<CustomException>());

      expect(command.canExecute.value, true);

      // verify Collectors.
      expect(cmdResultCollector.values, [
        CommandResult<void, void>(
            null, null, CustomException("Intentional"), false),
      ]);
      expect(thrownExceptionCollector.values,
          [CommandError<void>(null, CustomException("Intentional"))]);
    });

    test('Execute simple sync action with parameter', () {
      int executionCount = 0;
      final command = Command.createSyncNoResult<String>((x) {
        print("action: " + x.toString());
        executionCount++;
        return null;
      });
      // Setup Collectors.
      setupCollectors(command);

      expect(command.canExecute.value, true);

      command.execute("Parameter");
      expect(command.results.value,
          CommandResult<String, void>('Parameter', null, null, false));
      expect(command.thrownExceptions.value, null);
      expect(executionCount, 1);

      expect(command.canExecute.value, true);

      // Verify Collectors
      expect(thrownExceptionCollector.values, isNull);
      expect(cmdResultCollector.values, [
        CommandResult<void, void>("Parameter", null, null, false),
      ]);
      expect(pureResultCollector.values, [null]);
    });

    test('Execute simple sync function without parameter', () {
      int executionCount = 0;
      final command = Command.createSyncNoParam<String>(() {
        print("action: ");
        executionCount++;
        return "4711";
      }, '');

      expect(command.canExecute.value, true);
      // Setup Collectors
      setupCollectors(command);
      command.execute();

      expect(command.value, "4711");
      expect(command.results.value,
          CommandResult<void, String>(null, '4711', null, false));
      expect(command.thrownExceptions.value, null);
      expect(executionCount, 1);

      expect(command.canExecute.value, true);

      // verify collectors
      expect(thrownExceptionCollector.values, isNull);
      expect(pureResultCollector.values, [
        '4711',
      ]);
      expect(cmdResultCollector.values,
          [CommandResult<void, String>(null, '4711', null, false)]);
    });

    test('Execute simple sync function with parameter and result', () {
      int executionCount = 0;
      final command = Command.createSync<String, String>((s) {
        print("action: " + s);
        executionCount++;
        return s + s;
      }, '');

      expect(command.canExecute.value, true);
      // Setup Collectors
      setupCollectors(command);
      command.execute("4711");
      expect(command.value, "47114711");

      expect(command.results.value,
          CommandResult<String, String>('4711', '47114711', null, false));
      expect(command.thrownExceptions.value, null);
      expect(executionCount, 1);

      expect(command.canExecute.value, true);

      // verify collectors
      expect(thrownExceptionCollector.values, isNull);
      expect(pureResultCollector.values, [
        '47114711',
      ]);
      expect(cmdResultCollector.values,
          [CommandResult<void, String>("4711", '47114711', null, false)]);
    });
    test('Execute simple sync function with catchAlways == false', () {
      int executionCount = 0;
      final command = Command.createSync<String, String>(
        (s) {
          print("action: " + s);
          executionCount++;
          throw CustomException("Intentional");
        },
        'Initial Value',
        catchAlways: false,
      );

      expect(command.canExecute.value, true);
      // Setup Collectors
      setupCollectors(command);
      command.execute("4711");

      // the initial value is still returned so expect ex
      expect(command.value, "Initial Value");

      expect(command.thrownExceptions.value,
          CommandError("4711", CustomException("Intentional")));
      expect(executionCount, 1);

      expect(command.canExecute.value, true);

      // verify collectors
      expect(thrownExceptionCollector.values, [
        CommandError("4711", CustomException("Intentional")),
      ]);
      expect(pureResultCollector.values, isNull);
      expect(cmdResultCollector.values, [
        CommandResult<void, String>(
            "4711", null, CustomException("Intentional"), false)
      ]);
    });
  });

  group("Asynchronous Command Testing", () {
    Future<String> slowAsyncFunction(String s) async {
      print("___Start__Slow__Action__________");
      await Future.delayed(const Duration(milliseconds: 10));
      print("___End__Slow__Action__________");
      return s;
    }

    test('Execute simple async function with no Parameter no Result', () async {
      var executionCount = 0;

      final command = Command.createAsyncNoParamNoResult(
        () async {
          executionCount++;
          await slowAsyncFunction("no pram");
        },
        // restriction: setExecutionStateCommand,
      );

      // set up all the collectors for this command.
      setupCollectors(command);

      // Ensure command is not executing already.
      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      // Execute command.
      command.execute();

      // Waiting till the async function has finished executing.
      await Future.delayed(Duration(milliseconds: 10));

      expect(command.isExecuting.value, false);

      expect(executionCount, 1);

      // Expected to return false, true, false
      // but somehow skips the initial state which is false.
      expect(isExecutingCollector.values, [true, false]);

      expect(canExecuteCollector.values, [false, true]);

      expect(cmdResultCollector.values, [
        CommandResult<void, void>(null, null, null, true),
        CommandResult<void, void>(null, null, null, false),
      ]);
    });

    // test('Handle calling noParamFunctions being called with param', () async {
    //   var executionCount = 0;

    //   final command = Command.createAsyncNoParamNoResult(
    //     () async {
    //       executionCount++;
    //       await slowAsyncFunction("no pram");
    //     },
    //     // restriction: setExecutionStateCommand,
    //   );

    //   // set up all the collectors for this command.
    //   setupCollectors(command);

    //   // Ensure command is not executing already.
    //   expect(command.isExecuting.value, false,
    //       reason: "IsExecuting before true");

    //   // Execute command.
    //   command.execute("Done");

    //   // Waiting till the async function has finished executing.
    //   await Future.delayed(Duration(milliseconds: 10));

    //   expect(command.isExecuting.value, false);

    //   expect(executionCount, 1);

    //   // Expected to return false, true, false
    //   // but somehow skips the initial state which is false.
    //   expect(isExecutingCollector.values, [true, false]);

    //   expect(canExecuteCollector.values, [false, true]);

    //   expect(cmdResultCollector.values, [
    //     CommandResult<void, void>(null, null, null, true),
    //     CommandResult<void, void>(null, null, null, false),
    //   ]);
    // });

    test('Execute simple async function with No parameter', () async {
      var executionCount = 0;

      final command = Command.createAsyncNoParam<String>(() async {
        executionCount++;
        return await slowAsyncFunction("No Param");
      }, "Initial Value");

      // set up all the collectors for this command.
      setupCollectors(command);

      // Ensure command is not executing already.
      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      // Execute command.
      command.execute();

      // Waiting till the async function has finished executing.
      await Future.delayed(Duration(milliseconds: 10));

      expect(command.isExecuting.value, false);

      expect(executionCount, 1);

      // Expected to return false, true, false
      // but somehow skips the initial state which is false.
      expect(isExecutingCollector.values, [true, false]);

      expect(canExecuteCollector.values, [false, true]);

      expect(cmdResultCollector.values, [
        CommandResult<void, String>(null, null, null, true),
        CommandResult<void, String>(null, "No Param", null, false),
      ]);
    });
    test('Execute simple async function with parameter', () async {
      var executionCount = 0;

      final command = Command.createAsyncNoResult<String>(
        (s) async {
          executionCount++;
          await slowAsyncFunction(s);
        },
        // restriction: setExecutionStateCommand,
      );

      // set up all the collectors for this command.
      setupCollectors(command);

      // Ensure command is not executing already.
      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      // Execute command.
      command.execute("Done");

      // Waiting till the async function has finished executing.
      await Future.delayed(Duration(milliseconds: 10));

      expect(command.isExecuting.value, false);

      expect(executionCount, 1);

      // Expected to return false, true, false
      // but somehow skips the initial state which is false.
      expect(isExecutingCollector.values, [true, false]);

      expect(canExecuteCollector.values, [false, true]);

      expect(cmdResultCollector.values, [
        CommandResult<String, void>("Done", null, null, true),
        CommandResult<String, void>("Done", null, null, false),
      ]);
    });

    test('Execute simple async function with parameter and return value',
        () async {
      var executionCount = 0;

      final command = Command.createAsync<String, String>(
        (s) async {
          executionCount++;
          return slowAsyncFunction(s);
        },
        "initialValue",
      );

      setupCollectors(command);

      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      command.execute("Done");

      // Waiting till the async function has finished executing.
      await Future.delayed(Duration(milliseconds: 10));

      expect(command.isExecuting.value, false);

      expect(executionCount, 1);

      // Expected to return false, true, false
      // but somehow skips the initial state which is false.
      expect(isExecutingCollector.values, [true, false]);

      expect(canExecuteCollector.values, [false, true]);

      expect(cmdResultCollector.values, [
        CommandResult<String, void>("Done", null, null, true),
        CommandResult<String, void>("Done", "Done", null, false),
      ]);
    });

    test('Execute simple async function call while already running', () async {
      var executionCount = 0;

      final command = Command.createAsync<String, String>(
        (s) async {
          executionCount++;
          return slowAsyncFunction(s);
        },
        "Initial Value",
      );

      setupCollectors(command);

      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      expect(command.value, "Initial Value");

      command.execute("Done");
      command.execute("Done2"); // should not execute

      await Future.delayed(Duration(milliseconds: 100));

      expect(command.isExecuting.value, false);
      expect(executionCount, 1);

      // The expectation ensures that first command execution went through and
      // second command execution didn't wen through.
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", null, null, true),
        CommandResult<String, String>("Done", "Done", null, false)
      ]);
    });

    test('Execute simple async function called twice with delay', () async {
      var executionCount = 0;

      final command = Command.createAsync<String, String>(
        (s) async {
          executionCount++;
          return slowAsyncFunction(s);
        },
        "Initial value",
      );

      setupCollectors(command);

      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      command.execute("Done");

      // Reuse the same command after 50 milliseconds and it should work.
      await Future.delayed(Duration(milliseconds: 50));
      command.execute("Done2");

      await Future.delayed(Duration(milliseconds: 50));
      expect(command.isExecuting.value, false);
      expect(executionCount, 2);

      // Verify all the necessary collectors
      expect(canExecuteCollector.values, [false, true, false, true],
          reason: "CanExecute order is wrong");
      expect(isExecutingCollector.values, [true, false, true, false],
          reason: "IsExecuting order is wrong.");
      expect(pureResultCollector.values, ["Done", "Done2"]);
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", null, null, true),
        CommandResult<String, String>("Done", "Done", null, false),
        CommandResult<String, String>("Done2", null, null, true),
        CommandResult<String, String>("Done2", "Done2", null, false)
      ]);
    });

    test(
        'Execute simple async function called twice with delay and emitLastResult=true',
        () async {
      var executionCount = 0;

      final command = Command.createAsync<String, String>(
        (s) async {
          executionCount++;
          return slowAsyncFunction(s);
        },
        "Initial Value",
        includeLastResultInCommandResults: true,
      );

      // Setup all collectors.
      setupCollectors(command);

      expect(command.isExecuting.value, false,
          reason: "IsExecuting before true");

      command.execute("Done");
      await Future.delayed(Duration(milliseconds: 50));
      command("Done2");

      await Future.delayed(Duration(milliseconds: 50));

      expect(command.isExecuting.value, false);
      expect(executionCount, 2);

      // Verify all the necessary collectors
      expect(canExecuteCollector.values, [false, true, false, true],
          reason: "CanExecute order is wrong");
      expect(isExecutingCollector.values, [true, false, true, false],
          reason: "IsExecuting order is wrong.");
      expect(pureResultCollector.values, ["Done", "Done2"]);
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", "Initial Value", null, true),
        CommandResult<String, String>("Done", "Done", null, false),
        CommandResult<String, String>("Done2", "Done", null, true),
        CommandResult<String, String>("Done2", "Done2", null, false)
      ]);
    });
    Future<String> slowAsyncFunctionFail(String s) async {
      print("___Start____Action___Will throw_______");
      throw CustomException("Intentionally");
    }

    test('async function with exception and catchAlways==false', () async {
      final Command<String, String> command =
          Command.createAsync<String, String>(
        slowAsyncFunctionFail,
        "Initial Value",
        catchAlways: false,
      );

      setupCollectors(command);

      expect(command.canExecute.value, true);
      expect(command.isExecuting.value, false);

      // TODO: Test Rethrows part. Not sure how to test it.
      // Following expectations are not validated.
      try {
        command("Done");
      } catch (e) {
        expect(e, isA<CustomException>());
        print('Exception as expected for Done');
      }
      await Future.delayed(Duration.zero);

      expect(command.canExecute.value, true);
      expect(command.isExecuting.value, false);

      await Future.delayed(Duration(milliseconds: 100));

      try {
        command("Done2");
      } catch (e) {
        expect(e, isA<CustomException>());
        print('Exception as expected for Done2');
      }

      await Future.delayed(Duration.zero);

      expect(command.canExecute.value, true);
      expect(command.isExecuting.value, false);

      await Future.delayed(Duration(milliseconds: 100));

      // Ensure at least two command errors came through thrownExceptions
      expect(
          thrownExceptionCollector.values
              .skipWhile((value) => value is CommandError),
          hasLength(2));

      // thrownException may contain null in between consecutive command calls.
      // hence the assertion includes null.
      // TODO: Ensure this is the correct behavior.
      for (var error in thrownExceptionCollector.values) {
        expect(error, anyOf(isNull, isA<CommandError>()));
      }

      // Verify nothing came through pure results from .
      expect(pureResultCollector.values, isNull);

      // Verify the results collector.
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", null, null, true),
        CommandResult<String, String>(
            "Done", null, CustomException("Intentionally"), false),
        CommandResult<String, String>("Done2", null, null, true),
        CommandResult<String, String>(
            "Done2", null, CustomException("Intentionally"), false)
      ]);
    });

    test('async function with exception with and catchAlways==true', () async {
      final command = Command.createAsync<String, String>(
        slowAsyncFunctionFail,
        "Initial Value",
        catchAlways: true,
      );

      setupCollectors(command);

      expect(command.canExecute.value, true);
      expect(command.isExecuting.value, false);

      expect(command.thrownExceptions.value, isNull);
      command.execute("Done");

      await Future.delayed(Duration.zero);

      expect(command.canExecute.value, true);
      expect(command.isExecuting.value, false);

      // Verify nothing came through pure results from .
      expect(pureResultCollector.values, isNull);

      expect(thrownExceptionCollector.values,
          [CommandError<String>("Done", CustomException("Intentionally"))]);

      // Verify the results collector.
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", null, null, true),
        CommandResult<String, String>(
            "Done", null, CustomException("Intentionally"), false),
      ]);
    });
  });

  group("Test Global parameters and general utilities like dipose", () {
    test("Check Command Dispose", () async {
      final command = Command.createSync<String, String>(
        (s) {
          return s;
        },
        "Initial Value",
        catchAlways: false,
      );
      // Setup collectors. Note: This indirectly sets listeners.
      setupCollectors(command);

      // ignore: invalid_use_of_protected_member
      expect(command.hasListeners, true);

      // execute command and ensure there is no values in any of the collectors.
      command.dispose();

      // Check valid exception is raised trying to use disposed value notifiers.
      expect(() => command("Done"), throwsFlutterError);

      // verify collectors
      expect(canExecuteCollector.values, isNull);
      expect(cmdResultCollector.values, isNull);
      expect(pureResultCollector.values, isNull);
      expect(thrownExceptionCollector.values, isNull);
      expect(isExecutingCollector.values, isNull);
    });

    test("Check catchAlwaysDefault = false", () async {
      final command = Command.createAsync<String, String>((s) async {
        throw CustomException("Intentional");
      }, "Initial Value");
      // Set Global catchAlwaysDefault to false.
      // It defaults to true.
      Command.catchAlwaysDefault = false;

      // Setup collectors.
      setupCollectors(command);

      command("Done");
      await Future.delayed(Duration.zero);

      // verify collectors
      expect(canExecuteCollector.values, isNotEmpty);
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Done", null, null, true),
        CommandResult<String, String>(
            "Done", null, CustomException("Intentional"), false)
      ]);
      expect(pureResultCollector.values, isNull);
      expect(thrownExceptionCollector.values, [
        CommandError("Done", CustomException("Intentional")),
      ]);
      expect(isExecutingCollector.values, isNotEmpty);
    });

    test("Check globalExceptionHadnler is called in Sync/Async Command",
        () async {
      final command = Command.createSync<String, String>((s) {
        throw CustomException("Intentional");
      }, "Initial Value", debugName: "globalHandler");

      Command.globalExceptionHandler =
          expectAsync2((String debugName, CommandError ce) {
        expect(debugName, "globalHandler");
        expect(ce, isA<CommandError>());
        expect(
            ce, CommandError<Object>("Done", CustomException("Intentional")));
      }, count: 1);

      expect(() => command("Done"), throwsA(isA<CustomException>()));
      await Future.delayed(Duration(milliseconds: 100));
      final command2 = Command.createAsync<String, String>((s) async {
        throw CustomException("Intentional");
      }, "Initial Value", debugName: "globalHandler");
      // Set Global catchAlwaysDefault to false.
      // It defaults to true.
      Command.globalExceptionHandler =
          expectAsync2((String debugName, CommandError ce) {
        expect(debugName, "globalHandler");
        expect(ce, isA<CommandError>());
        expect(
            ce, CommandError<Object>("Done", CustomException("Intentional")));
      }, count: 1);

      expectLater(
          () async => command2("Done"), throwsA(isA<CustomException>()));
    });

    test("Check logging Handler is called in Sync/Async command", () async {
      final command = Command.createSync<String, String>((s) {
        return s;
      }, "Initial Value", debugName: "loggingHandler");
      // Set Global catchAlwaysDefault to false.
      // It defaults to true.
      Command.loggingHandler = expectAsync2(
        (String debugName, CommandResult cr) {
          expect(debugName, "loggingHandler");
          expect(cr, isA<CommandResult>());
          expect(
            cr,
            CommandResult<String, String>("Done", "Done", null, false),
          );
        },
        count: 2,
      );

      command("Done");
      await Future.delayed(Duration(milliseconds: 100));
      final command2 = Command.createAsync<String, String>((s) async {
        await Future.delayed(Duration(milliseconds: 20));
        return s;
      }, "Initial Value", debugName: "loggingHandler");

      command2("Done");
    });
    tearDown(() {
      Command.loggingHandler = null;
      Command.globalExceptionHandler = null;
    });
  });
  group("Test Command Builder", () {
    testWidgets("Test Command Builder", (WidgetTester tester) async {
      final testCommand = Command.createAsyncNoParam<String>(
        () async {
          await Future.delayed(Duration(seconds: 2));
          print("Command is called");
          return "New Value";
        },
        "Initial Value",
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CommandBuilder<void, String>(
                command: testCommand,
                onData: (context, value, _) {
                  return Text(
                    value,
                  );
                },
                whileExecuting: (_, __) {
                  return Text("Is Executing");
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
      expect(find.widgetWithText(Center, "Initial Value"), findsOneWidget);
      testCommand();
      await tester.pump(Duration(milliseconds: 500));
      // By now circular progress indicator should be visible.
      expect(find.widgetWithText(Center, "Initial Value"), findsNothing);
      expect(find.widgetWithText(Center, "Is Executing"), findsOneWidget);
      // Wait for command to finish async execution.
      await tester.pump(Duration(milliseconds: 1500));
      expect(find.widgetWithText(Center, "Is Executing"), findsNothing);
      expect(find.widgetWithText(Center, "New Value"), findsOneWidget);
    });
    testWidgets("Test Command Builder On error", (WidgetTester tester) async {
      final testCommand = Command.createAsyncNoParam<String>(
        () async {
          await Future.delayed(Duration(seconds: 2));
          throw CustomException("Exception From Command");
        },
        "Initial Value",
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CommandBuilder<void, String>(
                command: testCommand,
                onData: (context, value, _) {
                  return Text(
                    value,
                  );
                },
                whileExecuting: (_, __) {
                  return Text("Is Executing");
                },
                onError: (_, error, __) {
                  if (error is CustomException) {
                    return Text(error.message);
                  }
                  return Text("Unknown Exception Occurred");
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
      expect(find.widgetWithText(Center, "Initial Value"), findsOneWidget);
      testCommand();
      await tester.pump(Duration(milliseconds: 500));
      // By now circular progress indicator should be visible.
      expect(find.widgetWithText(Center, "Initial Value"), findsNothing);
      expect(find.widgetWithText(Center, "Is Executing"), findsOneWidget);
      // Wait for command to finish async execution.
      await tester.pump(Duration(milliseconds: 1500));
      expect(find.widgetWithText(Center, "Is Executing"), findsNothing);
      expect(find.widgetWithText(Center, "Exception From Command"),
          findsOneWidget);
    });
  });

  group("Improve Code Coverage", () {
    test("Test Data class", () {
      expect(
        CommandResult<String, String>.blank(),
        CommandResult<String, String>(null, null, null, false),
      );
      expect(
        CommandResult<String, String>.error(
            "param", CustomException("Intentional")),
        CommandResult<String, String>(
            "param", null, CustomException("Intentional"), false),
      );
      expect(
        CommandResult<String, String>.isLoading("param"),
        CommandResult<String, String>("param", null, null, true),
      );
      expect(
        CommandResult<String, String>.data("param", "result"),
        CommandResult<String, String>("param", "result", null, false),
      );
      expect(CommandResult<String, String>.data("param", "result").toString(),
          "ParamData param - Data: result - HasError: false - IsExecuting: false");
      expect(
          CommandError<String>("param", CustomException("Intentional"))
              .toString(),
          "CustomException: Intentional - for param: param");
    });
    test('Test MockCommand - execute', () {
      final mockCommand = MockCommand(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.execute();

      // verify collectors
      expect(cmdResultCollector.values, isNull);
      expect(pureResultCollector.values, ["Initial Value"]);
      // expect(isExecutingCollector.values, [true, false]);
    });
    test('Test MockCommand - startExecuting', () {
      final mockCommand = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.startExecution("Start");

      // verify collectors
      expect(cmdResultCollector.values,
          [CommandResult<String, String>("Start", null, null, true)]);
      // expect(pureResultCollector.values, ["Initial Value"]);
      // expect(isExecutingCollector.values, [true, false]);
    });

    test('Test MockCommand - endExecutionWithData', () {
      final mockCommand = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.endExecutionWithData("end_data");

      // verify collectors
      expect(cmdResultCollector.values,
          [CommandResult<String, String>(null, "end_data", null, false)]);
      expect(pureResultCollector.values, ["end_data"]);
    });
    test('Test MockCommand - endExecutionNoData', () {
      final mockCommand = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.endExecutionNoData();

      // verify collectors
      expect(cmdResultCollector.values,
          [CommandResult<String, String>(null, null, null, false)]);
      expect(pureResultCollector.values, isNull);
      // expect(isExecutingCollector.values, [true, false]);
    });
    test('Test MockCommand - endExecutionWithError', () {
      final mockCommand = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.endExecutionWithError("Test Mock Error");

      // verify collectors
      expect(mockCommand.results.value.error.toString(),
          "Exception: Test Mock Error - for param: null");
      expect(pureResultCollector.values, isNull);
      // expect(isExecutingCollector.values, [true, false]);
    });
    test('Test MockCommand - queueResultsForNextExecuteCall', () {
      final mockCommand = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );

      mockCommand.queueResultsForNextExecuteCall([
        CommandResult<String, String>("Param", null, null, true),
        CommandResult<String, String>("Param", "Result", null, false)
      ]);
      // Ensure mock command is executable.
      expect(mockCommand.canExecute.value, true);
      setupCollectors(mockCommand);

      mockCommand.execute();

      // verify collectors
      expect(cmdResultCollector.values, [
        CommandResult<String, String>("Param", null, null, true),
        CommandResult<String, String>("Param", "Result", null, false),
      ]);
      expect(pureResultCollector.values, ["Result"]);
      // expect(isExecutingCollector.values, [true, false]);
    });
  });
}
