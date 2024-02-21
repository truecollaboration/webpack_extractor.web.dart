import 'dart:js_interop';

import 'package:foundation/library.dart';

import 'typedef.dart';

abstract class Webpack {
  String get name;

  bool get injected;

  Iterable<int> get errorModules;

  INotifier<List<int>> get onAddModules;

  INotifier<bool> get injectState;

  void onCallModule(OnCallModuleCallback callback);

  /// if [throwError], cant return null, otherwise can
  JSObject? findModule(
    List<String> content, {
      bool throwError = true,
  });

  /// if [throwError], cant return null, otherwise can
  JSObject? extractModule(
    int id, {
      bool throwError = true,
  });
}