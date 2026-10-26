import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef CoachChatHandler = FutureOr<http.Response> Function(http.Request req);

/// Dịch vụ coach-chat giả: đăng ký handler theo "METHOD /đường-dẫn", cùng
/// hình dạng với [FakeDirectus] (xem `fake_directus.dart`) nhưng không có
/// khung `data` — Task 6 wire contract trả thẳng JSON ở gốc.
class FakeCoachChatServer {
  final routes = <String, CoachChatHandler>{};
  final requests = <http.Request>[];

  /// Bật lên thì mọi request ném như khi mất mạng.
  bool offline = false;

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    if (offline) throw http.ClientException('offline', req.url);
    final handler = routes['${req.method} ${req.url.path}'];
    if (handler == null) return json(404, {'error': 'not_found'});
    return handler(req);
  });

  static final baseUrl = Uri.parse('https://coach.test');

  List<http.Request> sent(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path).toList();

  static http.Response json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
