export 'push_platform_stub.dart'
    if (dart.library.js_interop) 'push_platform_web.dart'
    if (dart.library.io) 'push_platform_native.dart';
