import 'package:flutter/material.dart';
import 'package:functional_listener/functional_listener.dart';

import 'listview.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ListenableSubscription errorSubscription;

  @override
  void didChangeDependencies() {
    errorSubscription ??= TheViewModel.of(context)
        .updateWeatherCommand
        .thrownExceptions
        .where((x) => x != null) // filter out the error value reset
        .listen((error, _) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('An error has occured!'),
                content: Text(error.toString()),
              ));
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    errorSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("WeatherDemo")),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: TextField(
              autocorrect: false,
              decoration: InputDecoration(
                hintText: "Filter cities",
                hintStyle: TextStyle(color: Color.fromARGB(150, 0, 0, 0)),
              ),
              style: TextStyle(
                fontSize: 20.0,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
              onChanged: TheViewModel.of(context).textChangedCommand,
            ),
          ),
          Expanded(
            // Handle events to show / hide spinner
            child: ValueListenableBuilder<bool>(
              valueListenable:
                  TheViewModel.of(context).updateWeatherCommand.isExecuting,
              builder: (BuildContext context, bool isRunning, _) {
                // if true we show a busy Spinner otherwise the ListView
                if (isRunning == true) {
                  return Center(
                    child: Container(
                      width: 50.0,
                      height: 50.0,
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else {
                  return WeatherListView();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            // We use a ValueListenableBuilder to toggle the enabled state of the button
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: TheViewModel.of(context)
                        .updateWeatherCommand
                        .canExecute,
                    builder: (BuildContext context, bool canExecute, _) {
                      // Depending on the value of canEcecute we set or clear the Handler
                      final handler = canExecute
                          ? TheViewModel.of(context).updateWeatherCommand
                          : null;
                      return RaisedButton(
                        child: Text("Update"),
                        color: Color.fromARGB(255, 33, 150, 243),
                        textColor: Color.fromARGB(255, 255, 255, 255),
                        onPressed: handler,
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                    valueListenable:
                        TheViewModel.of(context).setExecutionStateCommand,
                    builder: (context, value, _) {
                      return Switch(
                        value: value,
                        onChanged:
                            TheViewModel.of(context).setExecutionStateCommand,
                      );
                    })
              ],
            ),
          ),
        ],
      ),
    );
  }
}
