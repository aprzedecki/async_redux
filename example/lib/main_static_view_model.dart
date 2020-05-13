import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<int> store;

/// This example shows how to use the same `ViewModel` architecture of flutter_redux.
/// This is specially useful if you are migrating from flutter_redux.
/// Here, you use the `StoreConnector`'s `converter` parameter,
/// instead of the `model` parameter.
/// And `ViewModel` doesn't extend `BaseModel`, but has a static factory:
///
/// `converter: (store) => ViewModel.fromStore(store)`.
///
void main() {
  store = Store<int>(initialState: 0);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<int> {
  final int amount;

  IncrementAction({@required this.amount}) : assert(amount != null);

  @override
  int reduce() => state + amount;
}

///////////////////////////////////////////////////////////////////////////////

/// This widget connects the dumb-widget (`MyHomePage`) with the store.
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, ViewModel>(
      converter: (store) => ViewModel.fromStore(store),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// Helper class to the connector widget. Holds the part of the State the widget needs,
/// and may perform conversions to the type of data the widget can conveniently work with.
class ViewModel {
  int counter;
  VoidCallback onIncrement;

  ViewModel({
    @required this.counter,
    @required this.onIncrement,
  });

  /// Static factory called by the StoreConnector.
  static ViewModel fromStore(Store<int> store) {
    return ViewModel(
      counter: store.state,
      onIncrement: () => store.dispatch(IncrementAction(amount: 1)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewModel && runtimeType == other.runtimeType && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final int counter;
  final VoidCallback onIncrement;

  MyHomePage({
    Key key,
    this.counter,
    this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Static Factory ViewModel Example'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text('$counter', style: const TextStyle(fontSize: 30))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onIncrement,
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }
}
