// ignore_for_file: unused_element

import 'dart:js_interop';
import 'dart:js_util';

import 'package:foundation/library.dart';
import 'package:web_window_api/library.dart';
import 'package:webpack_extractor/src/common/js.dart';
import 'package:webpack_extractor/library.dart';

import 'webpack_extractor_impl.dart';

class WebpackImpl implements Webpack {
  @override
  final String name;

  @override
  bool get injected => injectState.value;
  
  @override
  final List<int> errorModules = [];

  @override
  final Notifier<List<int>> onAddModules = Notifier.empty();

  @override
  final Notifier<bool> injectState = Notifier(value: false);

  final JSArray sink;
  WebpackImpl({
    required this.name,
    required this.sink,
  });

  static const __handled = '__handled';
  static const __exports = '__exports';

  void handlePreCallModule(JSFunction function, int id, List<dynamic> args) {
    if(_isFirstCall(function)) {
      final exports = args[1];
      setProperty(function, __exports, exports);
      args[1] = Proxy(exports, ProxyHandler(
        defineProperty: (target, key, descriptor) {
          setProperty(target, key, null);
          // print('key === ');
          // console.log(key);
          defineProperty(target, key, JSObjectDescriptor(
            configurable: true,
            // enumerable: true,
            // writable: true,
            value: hasProperty(descriptor, 'value') ? getProperty(descriptor, 'value') : Null,
            get: hasProperty(descriptor, 'get') ? getProperty(descriptor, 'get') : null,
          ));
          return true;
        },
        set: (target, property, value, receiver) {
          // print('set key === $property');
          defineProperty(target, property, JSObjectDescriptor(
            configurable: true,
            // enumerable: true,
            // writable: true,
            value: value,
            // get: hasProperty(descriptor, 'get') ? getProperty(descriptor, 'get') : null,
          ));
          // setProperty(target, property, value);
          return true;
        },
      ));
    }
  }

  void handleCallModule(JSFunction function, int id, List<dynamic> args) {
    final firstCall = _isFirstCall(function);
    if(firstCall) {
      _setNotFirstCall(function);

    } //args[1] = getProperty(function, __exports);
    final exports = args[1]; //getProperty(args.first, 'exports');

    for(final callback in _onCallModuleCallbacks) {
      callback(id, exports, firstCall);
    }
  }

  bool _isFirstCall(JSFunction function) {
    return !(getProperty<bool?>(function, __handled) ?? false);
  }

  void _setNotFirstCall(JSFunction function) {
    setProperty(function, __handled, true);
  }

  final List<OnCallModuleCallback> _onCallModuleCallbacks = [];

  @override
  void onCallModule(OnCallModuleCallback callback) {
    _onCallModuleCallbacks.add(callback);
  }

  @override
  JSObject? findModule(
    List<String> content, {
      bool throwError = true,
  }) {
    WebpackExtractorImpl.instance.extractModules(this);
    
    for(final module in modules.entries) {
      // idk why was so
      // final exports = getProperty<JSObject?>(module, 1);
      final exports = module.value;
      if(exports == null) {
        continue;
      }
      
      final keys = objectKeys(exports);
      
      if(keys.length < content.length) {
        continue;
      }
      
      var flag = true;
      for(final item in content) {
        if(!keys.contains(item)) {
            flag = false;
            break;
        }
      }

      if(flag) {
          return exports;
      }
    } if(throwError) {
      throw("not found module with content [" + content.join(", ") + "]");
    }
    
    return null;
  }

  @override
  JSObject? extractModule(
    int id, {
      bool throwError = true,
  }) {
    WebpackExtractorImpl.instance.extractModules(this);
    
    final module = modules[id];
    if(module != null) {
      return module;
    }
        
    if(throwError) {
      throw("not found module $id");
    } return null;
  }

  int lastChunksLength = 0;
  
  late final JSObject jsChunks;
  late final JSFunction jsExtractFunction;

  final Map<int, dynamic> modules = {};
  


  @JSExport(THIS)
  Object get _this => this;

  @JSExport('name')
  String get _js_name => name;

  @JSExport('errorModules')
  List<int> get _js_errorModules => errorModules;
  
  @JSExport('onCallModule')
  void _js_onCallModule(
    JSFunction callback,
  ) {
    return onCallModule((id, exports, firstCall) {
      callback([id, exports, firstCall]);
    });
  }
  
  @JSExport('findModule')
  JSObject? _js_findModule(
    List<dynamic> content, {
      bool throwError = true,
  }) {
    return findModule(
      content.cast(),
      throwError: throwError,
    );
  }

  @JSExport('extractModule')
  JSObject? _js_extractModule(
    int id, {
      bool throwError = true,
  }) {
    return extractModule(
      id,
      throwError: throwError,
    );
  }
}