import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example is the same as the one in `main_wait_action_advanced_1.dart`.
/// However, instead of only using flags in the [WaitAction], it uses both
/// flags and references.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state contains a [wait] object of type [Wait].
class AppState {
  final Map<int, String> descriptions;
  final Wait wait;

  AppState({this.descriptions, this.wait});

  /// The copy method has a named [wait] parameter of type [Wait].
  AppState copy({int counter, Map<int, String> descriptions, Wait wait}) => AppState(
        descriptions: descriptions ?? this.descriptions,
        wait: wait ?? this.wait,
      );

  /// The [wait] parameter is instantiated to `Wait()`.
  static AppState initialState() => AppState(
        descriptions: {},
        wait: Wait(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          descriptions == other.descriptions &&
          wait == other.wait;

  @override
  int get hashCode => descriptions.hashCode ^ wait.hashCode;
}

///////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

class GetDescriptionAction extends ReduxAction<AppState> {
  int index;

  GetDescriptionAction(this.index);

  @override
  Future<AppState> reduce() async {
    String description = await read("http://numbersapi.com/$index");
    await Future.delayed(const Duration(seconds: 2)); // Adds some more delay.

    Map<int, String> newDescriptions = Map.of(state.descriptions);
    newDescriptions[index] = description;

    return state.copy(descriptions: newDescriptions);
  }

  // The wait starts here. We use the index as a wait-flag reference.
  @override
  void before() => dispatch(WaitAction.add("button-download", ref: index));

  // The wait ends here. We remove the index from the wait-flag references.
  @override
  void after() => dispatch(WaitAction.remove("button-download", ref: index));
}

///////////////////////////////////////////////////////////////////////////////

/// This widget connects the dumb-widget (`MyHomePage`) with the store.
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PageViewModel>(
      model: PageViewModel(),
      builder: (BuildContext context, PageViewModel vm) => MyHomePage(
        onGetDescription: vm.onGetDescription,
        waiting: vm.waiting,
      ),
    );
  }
}

class PageViewModel extends BaseModel<AppState> {
  PageViewModel();

  bool waiting;
  void Function(int) onGetDescription;

  PageViewModel.build({
    @required this.waiting,
    @required this.onGetDescription,
  }) : super(equals: [waiting]);

  @override
  PageViewModel fromStore() => PageViewModel.build(
        /// If there is any waiting, `state.wait.isWaiting` will return true.
        waiting: state.wait.isWaiting,

        onGetDescription: (int index) => dispatch(GetDescriptionAction(index)),
      );
}

///////////////////////////////////////////////////////////////////////////////

/// This widget connects the dumb-widget (`MyHomePage`) with the store.
class MyItemConnector extends StatelessWidget {
  final int index;
  final void Function(int) onGetDescription;

  MyItemConnector({
    @required this.index,
    @required this.onGetDescription,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ItemViewModel>(
      model: ItemViewModel(index: index),
      builder: (BuildContext context, ItemViewModel vm) => MyItem(
        description: vm.description,
        waiting: vm.waiting,
        index: index,
        onGetDescription: onGetDescription,
      ),
    );
  }
}

class ItemViewModel extends BaseModel<AppState> {
  ItemViewModel({this.index});

  int index;
  String description;
  bool waiting;

  ItemViewModel.build({
    @required this.description,
    @required this.waiting,
  }) : super(equals: [description, waiting]);

  @override
  ItemViewModel fromStore() => ItemViewModel.build(
        description: state.descriptions[index],

        /// If index is waiting, `state.wait.isWaitingFor(index)` returns true.
        waiting: state.wait.isWaitingFor("button-download", ref: index),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyItem extends StatelessWidget {
  final String description;
  final bool waiting;
  final int index;
  final void Function(int) onGetDescription;

  MyItem({
    this.description,
    this.waiting,
    this.index,
    this.onGetDescription,
  });

  @override
  Widget build(BuildContext context) {
    Widget contents;

    if (waiting)
      contents = _progressIndicator();
    else if (description != null)
      contents = _indexDescription();
    else
      contents = _button();

    return Container(height: 70, child: Center(child: contents));
  }

  MaterialButton _button() => MaterialButton(
        color: Colors.blue,
        child:
            Text("CLICK $index", style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => onGetDescription(index),
      );

  Text _indexDescription() =>
      Text(description, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() => CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final bool waiting;
  final void Function(int) onGetDescription;

  MyHomePage({
    Key key,
    this.waiting,
    this.onGetDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(waiting ? "Downloading..." : "Advanced WaitAction Example 2")),
          body: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => MyItemConnector(
              index: index,
              onGetDescription: onGetDescription,
            ),
          ),
        ),
      ],
    );
  }
}
