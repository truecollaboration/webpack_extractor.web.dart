import 'dart:async';
import 'dart:js';
import 'dart:js_interop';
import 'dart:js_util';

import 'package:pshondation/library.dart';
import 'package:web/web.dart';
import 'package:web_window_api/library.dart';
import 'package:webpack_extractor/src/common/js.dart';
import 'package:webpack_extractor/src/external/webpack.dart';
import 'package:webpack_extractor/src/external/webpack_extractor.dart';
import 'package:webpack_extractor/src/internal/webpack_impl.dart';

class WebpackExtractorImpl implements WebpackExtractor {
  static final instance = WebpackExtractorImpl();

  @override
  @JSExport()
  int get version => WebpackExtractor.CONST_VERSION;
  
  // @override
  // final Notifier<WebpackImpl> listener = Notifier.empty();

  @override
  Iterable<Webpack> get webpacks => _webpacks.values;

  @override
  Webpack get webpack => webpacks.isEmpty ? throw('Webpack not initialized') : webpacks.first;


  final Map<String, WebpackImpl> _webpacks = {};

  @override
  WebpackImpl listenFor(String webpackName) {
    const PUSH = 'push';

    late final WebpackImpl webpack;

    final array = JSArray();
    
    final originPush = getProperty<JSFunction>(array, PUSH);
    JSFunction? overridenPush;
    
    JSFunction createPushProxy(JSFunction function) {
      return Proxy(function, ProxyHandler(
        apply: (target, thisArg, argumentsList) {
          // print('calling push');
          // console.log(target);
          // console.log(overridenPush);
          
          if(target == overridenPush) {
            // console.log(argumentsList);
            // debugger();
            
            for(int i = 0; i < argumentsList.length; i++) {
              final value = argumentsList[i];
              
              // value is List
              // 0 - list of ids
              // 1 - map of modules
              final map = getProperty<JSObject>(value, 1);
              final ids = objectKeys(map).cast<String>().map((e) => int.parse(e)).toList();
              webpack.onAddModules.value = ids;

              for(final id in ids) {
                final sId = id.toString();
                final proxy = Proxy(getProperty(map, sId), ProxyHandler(
                  apply: (target, thisArg, argumentsList) {
                    webpack.handlePreCallModule(target, id, argumentsList);
                    final result = target.apply(thisArg, argumentsList);
                    webpack.handleCallModule(target, id, argumentsList);
                    return result;
                  },
                ));
                setProperty(map, sId, proxy);
              }
            }
          }

          return target.apply(thisArg, argumentsList);
        },
      )) as JSFunction;
    }

    final proxyArray = Proxy(array, ProxyHandler(
      set: (target, prop, value, receiver) {
        // console.log('proxyArray set');
        // console.log('target = ${target.runtimeType}');
        // console.log('prop = ${prop.runtimeType}');
        // console.log('value = ${value.runtimeType}');
        // console.log('receiver = ${receiver.runtimeType}');
        
        // webpack trying to override push function
        if(prop == 'push') {
          // print('overriding push');
          // console.log(value);
          overridenPush = value;
          value = createPushProxy(value as JSFunction);
        }
        
        // print('$webpackName hava new prop = $prop');
        
        // return Reflect.set(...arguments)
        // if(overridenPush != null)
        //   overridenPush!([value]);
        setProperty(target, prop, value);
        return true;
      },
    )) as JSArray;

    // hack for forced call [createPushProxy]
    setProperty(proxyArray, PUSH, originPush);

    setProperty(window, webpackName, proxyArray);

    webpack = _addWebpackIfNotExist(webpackName, proxyArray);

    // inject(webpack);

    return webpack;
    // }
    // Proxy(window, jsify({
    //   'set': (target, prop, value) {
    //     print('window hava new prop = $prop');
    //     // if (prop === 'foo')
    //     //   console.log(`Property updated with value: ${value}!`)
    //     // return Reflect.set(...arguments)
    //     target[prop] = value;
    //     return true;
    //   },
    // }));
  }
  
  @override
  Future<List<Webpack>> findWebpacks({
    Duration? timeout,
    Duration delay = const Duration(milliseconds: 10),
  }) async {
    Timer? timer;
    if(timeout != null) {
      timer = Timer(timeout, () {
        
      });
    }
    
    while(true) {
      final keys = objectKeys(window).map((e) => e.toString());
      for(final key in keys) {
        if(key.startsWith("webpackChunk")) {
          _addWebpackIfNotExist(key, getProperty(window, key));
        }
      }

      if(timeout == null || webpacks.isNotEmpty || !timer!.isActive) {
        break;
      } await Future.delayed(delay);
    }
    
    return webpacks.toList();
  }

  WebpackImpl _addWebpackIfNotExist(String name, JSArray self) {
    if(_webpacks.containsKey(name))
      return _webpacks[name] as WebpackImpl;

    return _webpacks[name] = (WebpackImpl(
      name: name,
      sink: self,
    ));
  }

  @override
  Future<bool> inject(covariant WebpackImpl webpack) async { 
    // int index = 0;
    // for(int i = 0 ; i < getProperty<int>(webpack.sink, 'length'); i++) {
    //     final chunk = getProperty(webpack.sink, i);
    //     var ids = getProperty<List>(chunk, 0);
    //     for(int id in ids) {
    //         if(id >= index) {
    //           index = id + 1;
    //         }
    //     }
    // }

    webpack.sink.push(_buildDataForPush(webpack));
    
    return webpack.injectState.asFuture();
  }

  void extractModules(WebpackImpl webpack) {
    final length = objectKeys(webpack.jsChunks).length;
    if(webpack.lastChunksLength == length) {
      return;
    }

    webpack.lastChunksLength = length;
    for(final value in objectKeys(webpack.jsChunks)) {
      final id = value is String ? int.tryParse(value) : value as int;
      if(id == null) {
        continue;
      }

      if(webpack.modules.containsKey(id)) {
        continue;
      }
      
      try {
        final module = webpack.jsExtractFunction.call([id]);
        webpack.modules[id] = module;
      } catch(e) {
        // print(e);
        // print(s);
        // debugger();
        webpack.errorModules.add(id);
      }
    }

    // if(webpack.errorModules.isNotEmpty) {
    //   print("errorModules = ${webpack.errorModules}");
    // }

    // print("readyModules = ${webpack.modules.keys.toList()}");
  }






  @JSExport('webpacks')
  Object get _js_webpacks => webpacks.map((e) => createDartExport(e as WebpackImpl)).toList();

  @JSExport('webpack')
  Object get _js_webpack => createDartExport(webpack as WebpackImpl);
  
  @JSExport('findWebpacks')
  Promise _js_findWebpacks({ //<List<Webpack>>
    int? timeout,
  }) {
    return futureToPromise(this.findWebpacks(
      timeout: timeout != null ? Duration(milliseconds: timeout) : null,
    ).then((value) => value.map((e) => createDartExport(e as WebpackImpl)).toList()));
  }

  @JSExport('inject')
  Promise _js_inject(
    dynamic webpack,
  ) {
    return futureToPromise(this.inject(
      getProperty(webpack, THIS) as WebpackImpl,
    ));
  }
}






dynamic _buildDataForPush(WebpackImpl webpack) {
  return jsify([
    jsify([-1]),
    jsify({
      // 9999: allowInterop((
      //   JSObject moduleInfo, dynamic _, dynamic extractFunction,
      // ) {
      //   print('execute webpach');
      // }),
    }),
    allowInterop((
      JSObject extractFunction,
    ) {
      if(webpack.injected)
        return;

      bool foundChunks = false;

      {
        final entries = objectKeys(extractFunction).map((e) => e.toString()).toList();
        for(final propName in entries) {
          final propValue = getProperty(extractFunction, propName);
          if(propValue is JsFunction) {
            continue;
          }
          
          final length = getProperty(propValue, 'length');
          if(length != null) {
            continue;
          }

          final propKeys = objectKeys(propValue);
          // console.log('propKeys = ');
          // console.log(propKeys);
          if(!propKeys.isEmpty) {
            final value = propKeys.tryFirst;
            if((value is String && int.tryParse(value) == null && value is! int)) {
              continue;
            }
          }
          
          webpack.jsChunks = propValue;
          foundChunks = true;
          break;
        }
      }

      webpack.jsExtractFunction = extractFunction as JSFunction;

      webpack.injectState.value = foundChunks;
    }),
  ]);
}



// OLD JS VERSION

// (()=>{
//     const VERSION = 1;

//     class _WebpackExtractor {
//         constructor() {
//             this.version = VERSION;
//             // this._webchunks = {};
//             this._extractFunction = null;
//             this._chunks = null;
//             this.lastChunksLength = 0;

//             this.modules = new Map();
//             this.errorModules = [];

//             this.initialized = false;
//             this._inject();
//         }

//         // addWebchunk(content) {
            
//         // }

//         findModule(content, throwError = true) {
//             this._extractModules();
            
//             for(var module of this.modules.entries()) {
//                 var exports = module[1];
//                 if(exports == null || exports == undefined)
//                     continue;
                
//                 var keys = Object.keys(exports);
                
//                 if(keys.length < content.length)
//                     continue;
                
//                 var flag = true;
//                 for(var item of content) {
//                     if(!keys.includes(item)) {
//                         flag = false;
//                         break;
//                     }
//                 }

//                 if(flag) {
//                     return exports;
//                 }
//             } if(throwError)
//                 throw("not found module " + content.join(", "));
            
//             return null;
//         }

//         extractModule(id, throwError = true) {
//             var module = this.modules.get(id);
//             if(module != undefined)
//                 return module;
                
//             if(throwError)
//                 throw("not found module " + id);
//             return null;
//         }
    
//         _inject() {
//         }

    
//     if(window.WebpackExtractor == undefined || window.WebpackExtractor.version == undefined || window.WebpackExtractor.version < VERSION) {
//         window.WebpackExtractor = new _WebpackExtractor();
//     }

//     window.extractWebchunk = (...args) => window.WebpackExtractor.extractModule.call(window.WebpackExtractor, args);
//     window.extractModule = (...args) => window.WebpackExtractor.extractModule.call(window.WebpackExtractor, args);
    
// })();