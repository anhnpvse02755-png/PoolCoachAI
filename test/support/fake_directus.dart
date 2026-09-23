import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef DirectusHandler = FutureOr<http.Response> Function(http.Request req);

/// Directus giả: đăng ký handler theo "METHOD /đường-dẫn".
///
/// Mọi request đều được ghi lại vào [requests] để test đọc lại xem app
/// đã gửi gì — nhất là để chứng minh nó **không** gửi dữ liệu của người khác.
class FakeDirectus {
  final routes = <String, DirectusHandler>{};
  final requests = <http.Request>[];

  /// Bật lên thì mọi request ném như khi mất mạng.
  bool offline = false;

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    if (offline) throw http.ClientException('offline', req.url);
    final handler = routes['${req.method} ${req.url.path}'];
    if (handler == null) return error(404, 'ROUTE_NOT_FOUND');
    return handler(req);
  });

  static final baseUrl = Uri.parse('https://api.test');

  List<http.Request> sent(String method, String path) => requests
      .where((r) => r.method == method && r.url.path == path)
      .toList();

  static Map<String, Object?> body(http.Request req) =>
      jsonDecode(req.body) as Map<String, Object?>;

  static http.Response ok(Object? data) => http.Response.bytes(
        utf8.encode(jsonEncode({'data': data})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static http.Response noContent() => http.Response('', 204);

  static http.Response error(int status, String code) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'errors': [
            {'message': code, 'extensions': {'code': code}},
          ],
        })),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// Đăng nhập nào cũng thành công, trả [refresh] làm refresh token.
  void acceptLogin({
    String userId = 'u1',
    String name = 'An',
    String refresh = 'r1',
    int expiresMs = 900000,
  }) {
    routes['POST /auth/login'] = (_) => ok({
          'access_token': 'access-$refresh',
          'expires': expiresMs,
          'refresh_token': refresh,
        });
    routes['GET /users/me'] = (_) => ok({'id': userId, 'first_name': name});
  }
}
