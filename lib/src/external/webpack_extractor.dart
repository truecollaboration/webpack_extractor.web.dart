import 'dart:async';
import 'dart:html';
import 'dart:js_interop';
import 'dart:js_util';

import 'package:webpack_extractor/src/internal/webpack_extractor_impl.dart';

import 'webpack.dart';

abstract class WebpackExtractor {
  static final WebpackExtractor instance = WebpackExtractorImpl.instance;

  static const CONST_VERSION = 2;

  int get version;

  // INotifier<Webpack> get listener;

  Iterable<Webpack> get webpacks;

  Webpack get webpack;

  Webpack listenFor(String webpackName);

  Future<List<Webpack>> findWebpacks({
    Duration? timeout,
    Duration delay = const Duration(milliseconds: 10),
  });

  Future<bool> inject(
    Webpack webpack,
  );

  /// returns false if [window] has newer [WebpackExtractor] version
  static bool addInstanceToWindow({
    bool throwIfError = true,
  }) {
    const JS_FIELD = 'WebpackExtractor';

    try {
      final oldInstance = getProperty<_JsOldWebpackExtractor?>(window, JS_FIELD);
      if(oldInstance == null || oldInstance.version < CONST_VERSION) {
        final jsInstance = createDartExport(instance as WebpackExtractorImpl);
        setProperty(window, JS_FIELD, jsInstance);
      }

      // window.extractWebchunk = (...args) => window.WebpackExtractor.extractModule.call(window.WebpackExtractor, args);
      // window.extractModule = (...args) => window.WebpackExtractor.extractModule.call(window.WebpackExtractor, args);
    } catch(e) {
      if(throwIfError)
        rethrow;
      return false;
    } return true;
  }
}

@JS()
@staticInterop
class _JsOldWebpackExtractor {}

extension on _JsOldWebpackExtractor {
  external int get version;
}