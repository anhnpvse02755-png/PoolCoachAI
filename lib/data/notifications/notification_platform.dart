export 'notification_platform_stub.dart'
    if (dart.library.js_interop) 'notification_platform_web.dart'
    if (dart.library.io) 'notification_platform_native.dart';
