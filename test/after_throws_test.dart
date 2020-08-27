import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

///////////////////////////////////////////////////////////////////////////////

List<String> info;

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('If the after method throws, the error will be thrown asynchronously.', () async {
    //
    dynamic error;
    dynamic asyncError;
    Store<String> store;

    await runZoned(() async {
      info = [];
      store = Store<String>(initialState: "");

      try {
        store.dispatch(ActionA());
      } catch (_error) {
        error = _error;
      }
      await Future.delayed(const Duration(seconds: 1));
    }, onError: (_asyncError, s) {
      asyncError = _asyncError;
    });

    expect(store.state, "A");

    expect(info, [
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
    ]);

    expect(error, isNull);

    expect(asyncError, "some-error");
  });

  /////////////////////////////////////////////////////////////////////////////
}

class ActionA extends ReduxAction<String> {
  @override
  void before() {
    info.add('A.before state="$state"');
  }

  @override
  String reduce() {
    info.add('A.reduce state="$state"');
    return state + 'A';
  }

  @override
  void after() {
    info.add('A.after state="$state"');
    throw "some-error";
  }
}