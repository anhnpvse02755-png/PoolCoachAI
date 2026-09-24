import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/remote/directus_client.dart';

import '../../support/fake_directus.dart';

void main() {
  late FakeDirectus server;
  late DirectusClient api;

  setUp(() {
    server = FakeDirectus();
    api = DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);
  });

  test('trả trường data của phản hồi, kèm Bearer token', () async {
    server.routes['GET /users/me'] = (_) => FakeDirectus.ok({'id': 'u1'});

    final data = await api.get('/users/me', token: 'abc');

    expect(data, {'id': 'u1'});
    expect(server.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('gửi body JSON và giữ nguyên chữ tiếng Việt', () async {
    server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();

    final data = await api.post('/users/register', body: {'first_name': 'Nguyễn Ân'});

    expect(data, isNull);
    expect(FakeDirectus.body(server.requests.single)['first_name'], 'Nguyễn Ân');
  });

  test('lỗi server thành DirectusError mang mã của Directus', () async {
    server.routes['POST /auth/login'] =
        (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

    expect(
      () => api.post('/auth/login', body: {}),
      throwsA(isA<DirectusError>()
          .having((e) => e.status, 'status', 401)
          .having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
  });

  test('không tới được server thành DirectusUnreachable', () async {
    server.offline = true;

    expect(() => api.get('/users/me'), throwsA(isA<DirectusUnreachable>()));
  });

  test('đọc được tham số query', () async {
    server.routes['GET /items/drill_logs'] = (req) =>
        FakeDirectus.ok([req.url.queryParameters['limit']]);

    expect(await api.get('/items/drill_logs', query: {'limit': '-1'}), ['-1']);
  });

  test('phản hồi không phải JSON thì vẫn ra DirectusError, không nổ', () async {
    server.routes['GET /x'] = (_) => http.Response('<html>502</html>', 502);

    expect(
      () => api.get('/x'),
      throwsA(isA<DirectusError>().having((e) => e.code, 'code', isNull)),
    );
  });
}
