// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

library async_redux_view_model;

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

/// Each state passed in the [Vm.equals] parameter in the in view-model will be
/// compared by equality (==), unless it is of type [VmEquals], when it will be
/// compared by the [VmEquals.vmEquals] method, which by default is a comparison
/// by identity (but can be overridden).
abstract class VmEquals<T> {
  bool vmEquals(T other) => identical(this, other);
}

/// [Vm] is a base class for your view-models.
///
/// A view-model is a helper object to a [StoreConnector] widget. It holds the
/// part of the Store state the corresponding dumb-widget needs, and may also
/// convert this state part into a more convenient format for the dumb-widget
/// to work with.
///
/// Each time the state changes, all [StoreConnector]s in the widget tree will
/// create a view-model, and compare it with the view-model they created with
/// the previous state. Only if the view-model changed, the [StoreConnector]
/// will rebuild. For this to work, you must implement equals/hashcode for the
/// view-model class. Otherwise, the [StoreConnector] will think the view-model
/// changed everytime, and thus will rebuild everytime. This wouldn't create any
/// visible problems to your app, but would be inefficient and maybe slow.
///
/// Using the [Vm] class you can implement equals/hashcode without having to
/// override these methods. Instead, simply list all fields (which are not
/// immutable, like functions) to the [equals] parameter in the constructor.
/// For example:
///
/// ```
/// ViewModel({this.counter, this.onIncrement}) : super(equals: [counter]);
/// ```
///
/// Each listed state will be compared by equality (==), unless it is of type
/// [VmEquals], when it will be compared by the [VmEquals.vmEquals] method,
/// which by default is a comparison by identity (but can be overridden).
///
@immutable
abstract class Vm {
  //

  /// To test the view-model generated by a Factory, use [createFrom] and pass it the
  /// [store] and the [factory]. Note this method must be called in a recently
  /// created factory, as it can only be called once per factory instance.
  ///
  /// The method will return the view-model, which you can use to:
  ///
  /// * Inspect the view-model properties directly, or
  ///
  /// * Call any of the view-model callbacks. If the callbacks dispatch actions,
  /// you use `await store.waitActionType(MyAction)`,
  /// or `await store.waitAllActionTypes([MyAction, OtherAction])`,
  /// or `await store.waitCondition((state) => ...)`, or if necessary you can even
  /// record all dispatched actions and state changes with `Store.record.start()`
  /// and `Store.record.stop()`.
  ///
  /// Example:
  /// ```
  /// var store = Store(initialState: User("Mary"));
  /// var vm = Vm.createFrom(store, MyFactory());
  ///
  /// // Checking a view-model property.
  /// expect(vm.user.name, "Mary");
  ///
  /// // Calling a view-model callback and waiting for the action to finish.
  /// vm.onChangeNameTo("Bill"); // Dispatches SetNameAction("Bill").
  /// await store.waitActionType(SetNameAction);
  /// expect(store.state.name, "Bill");
  ///
  /// // Calling a view-model callback and waiting for the state to change.
  /// vm.onChangeNameTo("Bill"); // Dispatches SetNameAction("Bill").
  /// await store.waitCondition((state) => state.name == "Bill");
  /// expect(store.state.name, "Bill");
  /// ```
  ///
  @visibleForTesting
  static Model createFrom<St, T extends Widget?, Model extends Vm>(
    Store<St> store,
    VmFactory<St, T, Model> factory,
  ) {
    internalsVmFactoryInject(factory, store.state, store);
    return internalsVmFactoryFromStore(factory) as Model;
  }

  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object?> equals;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [Vm] are equal.
  Vm({this.equals = const []}) : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object? field) {
      if (field is Function)
        throw StoreException("ViewModel equals "
            "can't contain field of type Function: ${field.runtimeType}.");
    });

    return true;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Vm &&
            runtimeType == other.runtimeType &&
            _listEquals(
              equals,
              other.equals,
            );
  }

  bool _listEquals<T>(List<T>? list1, List<T>? list2) {
    if (list1 == null) return list2 == null;
    if (list2 == null || list1.length != list2.length) return false;
    if (identical(list1, list2)) return true;
    for (int index = 0; index < list1.length; index++) {
      var item1 = list1[index];
      var item2 = list2[index];

      if ((item1 is VmEquals<T>) &&
          (item2 is VmEquals<T>) //
          &&
          !item1.vmEquals(item2)) return false;

      if (item1 != item2) return false;
    }
    return true;
  }

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object? prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

/// Factory that creates a view-model of type [Vm], for the [StoreConnector]:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(),
///      builder: ...
/// ```
///
/// You must override the [fromStore] method:
///
/// ```
/// class _Factory extends VmFactory {
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: 1)));
/// }
/// ```
///
/// If necessary, you can pass the [StoreConnector] widget to the factory:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(this),
///      builder: ...
///
/// ...
/// class _Factory extends VmFactory<AppState, MyHomePageConnector> {
///    _Factory(connector) : super(connector);
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: widget.amount)));
/// }
/// ```
///
abstract class VmFactory<St, T extends Widget?, Model extends Vm> {
  /// You need to pass the connector widget only if the view-model needs any info from it.
  VmFactory([this._connector]);

  Model? fromStore();

  final T? _connector;

  /// The connector widget that will instantiate the view-model.
  @Deprecated("Use `connector` instead")
  T? get widget => _connector;

  /// The connector widget that will instantiate the view-model.
  T get connector {
    if (_connector == null)
      throw StoreException(
          "To use the `connector` field you must pass it to the factory constructor:"
          "\n\n"
          "return StoreConnector<AppState, _Vm>(\n"
          "   vm: () => Factory(this),\n"
          "   ..."
          "\n\n"
          "class Factory extends VmFactory<_Vm, MyConnector> {\n"
          "   Factory(Widget widget) : super(widget);");
    else
      return _connector;
  }

  late final Store<St> _store;
  late final St _state;

  /// Once the Vm is created, we save it so that it can be used by factory methods.
  Model? _vm;
  bool _vmCreated = false;

  /// Once the view-model is created, and as long as it's not null, you can reference
  /// it by using the [vm] getter. This is meant to be used inside of Factory methods.
  ///
  /// Example:
  ///
  /// ```
  /// ViewModel fromStore() =>
  ///   ViewModel(
  ///     value: _calculateValue(),
  ///     onTap: _onTap);
  ///   }
  ///
  /// // Here we use the value, without having to recalculate it.
  /// void _onTap() => dispatch(SaveValueAction(vm.value));
  /// ```
  ///
  Model get vm {
    if (!_vmCreated)
      throw StoreException("You can't reference the view-model "
          "before it's created and returned by the fromStore method.");

    if (_vm == null)
      throw StoreException("You can't reference the view-model, "
          "because it's null.");

    return _vm!;
  }

  bool get ifVmIsNull {
    if (!_vmCreated)
      throw StoreException("You can't reference the view-model "
          "before it's created and returned by the fromStore method.");

    return (_vm == null);
  }

  void _setStore(St state, Store store) {
    _store = store as Store<St>;
    _state = state;
  }

  /// The state the store was holding when the factory and the view-model were created.
  /// This state is final inside of the factory.
  St get state => _state;

  /// Gets the store environment.
  /// This can be used to create a global value, but scoped to the store.
  /// For example, you could have a service locator, here, or a configuration value.
  ///
  /// See also: [prop] and [setProp].
  Object? get env => _store.env;

  /// Gets a property from the store.
  /// This can be used to save global values, but scoped to the store.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// See also: [setProp] and [env].
  V prop<V>(Object? key) => _store.prop<V>(key);

  /// Sets a property in the store.
  /// This can be used to save global values, but scoped to the store.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// See also: [prop] and [env].
  void setProp(Object? key, Object? value) => _store.setProp(key, value);

  /// The current (most recent) store state.
  /// This will return the current state the store holds at the time the method is called.
  St currentState() => _store.state;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// store.dispatch(MyAction());
  /// ```
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  Dispatch<St> get dispatch => _store.dispatch;

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  DispatchAsync<St> get dispatchAsync => _store.dispatchAndWait;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await store.dispatchAndWait(DoThisFirstAction());
  /// store.dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await store.dispatchAndWait(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  DispatchAndWait<St> get dispatchAndWait => _store.dispatchAndWait;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Method [dispatchSync] is of type [DispatchSync]. It returns `ActionStatus`,
  /// which means you can also get the final status of the action:
  ///
  /// ```dart
  /// var status = store.dispatchSync(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  DispatchSync<St> get dispatchSync => _store.dispatchSync;

  /// You can use [isWaiting] to check if:
  /// * A specific async ACTION is currently being processed.
  /// * An async action of a specific TYPE is currently being processed.
  /// * If any of a few given async actions or action types is currently being processed.
  ///
  /// If you wait for an action TYPE, then it returns false when:
  /// - The ASYNC action of type [actionType] is NOT currently being processed.
  /// - If [actionType] is not really a type that extends [ReduxAction].
  /// - The action of type [actionType] is a SYNC action (since those finish immediately).
  ///
  /// If you wait for an ACTION, then it returns false when:
  /// - The ASYNC [action] is NOT currently being processed.
  /// - If [action] is a SYNC action (since those finish immediately).
  //
  /// Examples:
  ///
  /// ```dart
  /// // Waiting for an action TYPE:
  /// dispatch(MyAction());
  /// if (isWaiting(MyAction)) { // Show a spinner }
  ///
  /// // Waiting for an ACTION:
  /// var action = MyAction();
  /// dispatch(action);
  /// if (isWaiting(action)) { // Show a spinner }
  ///
  /// // Waiting for any of the given action TYPES:
  /// dispatch(BuyAction());
  /// if (isWaiting([BuyAction, SellAction])) { // Show a spinner }
  /// ```
  bool isWaiting(Object actionOrTypeOrList) => _store.isWaiting(actionOrTypeOrList);

  /// Returns true if an [actionOrActionTypeOrList] failed with an [UserException].
  /// Note: This method uses the EXACT type in [actionOrActionTypeOrList]. Subtypes are not considered.
  bool isFailed(Object actionOrTypeOrList) => _store.isFailed(actionOrTypeOrList);

  /// Returns the [UserException] of the [actionTypeOrList] that failed.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  UserException? exceptionFor(Object actionTypeOrList) => _store.exceptionFor(actionTypeOrList);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the exceptions list.
  /// This removal happens as soon as the action is dispatched, not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  void clearExceptionFor(Object actionTypeOrList) => _store.clearExceptionFor(actionTypeOrList);

  /// Returns a future which will complete when the given state [condition] is true.
  /// If the condition is already true when the method is called, the future completes immediately.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes. If you want, you
  /// can modify [StoreTester.defaultTimeoutMillis] to change the default timeout.
  /// Note: To disable the timeout, modify this to a large value, like 300000000 (almost 10 years).
  ///
  /// ```dart
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// ```
  Future<ReduxAction<St>?> waitCondition(
    bool Function(St) condition, {
    int? timeoutMillis,
  }) =>
      _store.waitCondition(condition, timeoutMillis: timeoutMillis);

  /// Returns a future that completes when ALL given [actions] finished dispatching.
  /// You MUST provide at list one action, or an error will be thrown.
  ///
  /// If [completeImmediately] is `false` (the default), this method will throw an error if none
  /// of the given actions are in progress when the method is called. Otherwise, the future will
  /// complete immediately and throw no error.
  ///
  /// Example:
  ///
  /// ```ts
  /// // Dispatching two actions in PARALLEL and waiting for both to finish.
  /// var action1 = ChangeNameAction('Bill');
  /// var action2 = ChangeAgeAction(42);
  /// await waitAllActions([action1, action2]);
  ///
  /// // Compare this to dispatching the actions in SERIES:
  /// await dispatchAndWait(action1);
  /// await dispatchAndWait(action2);
  /// ```
  Future<void> waitAllActions(List<ReduxAction<St>> actions, {bool completeImmediately = false}) {
    if (actions.isEmpty) throw StoreException('You have to provide a non-empty list of actions.');
    return _store.waitAllActions(actions, completeImmediately: completeImmediately);
  }

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException? getAndRemoveFirstError() => _store.getAndRemoveFirstError();
}

/// For internal use only. Please don't use this.
Vm? internalsVmFactoryFromStore(VmFactory<dynamic, dynamic, dynamic> vmFactory) {
  vmFactory._vm = vmFactory.fromStore();
  vmFactory._vmCreated = true;
  return vmFactory._vm;
}

/// For internal use only. Please don't use this.
void internalsVmFactoryInject<St>(
    VmFactory<St, dynamic, dynamic> vmFactory, St state, Store store) {
  vmFactory._setStore(state, store);
}
