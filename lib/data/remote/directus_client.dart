import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Server trả lỗi. [code] là `errors[0].extensions.code` của Directus.
class DirectusError implements Exception {
  const DirectusError(this.status, this.code);

  final int status;
  final String? code;

  @override
  String toString() => 'DirectusError($status, $code)';
}

/// Không tới được server: mất mạng, DNS, CORS, hết giờ.
///
/// Tách khỏi [DirectusError] vì hai loại dẫn tới hai hành vi ngược nhau:
/// mất mạng thì giữ đăng nhập và thử lại sau, còn server từ chối thì
/// mới là lúc đăng xuất.
class DirectusUnreachable implements Exception {
  const DirectusUnreachable(this.cause);

  final Object cause;

  @override
  String toString() => 'DirectusUnreachable($cause)';
}

/// Lớp HTTP mỏng trên REST của Directus — trả thẳng trường `data`.
class DirectusClient {
  DirectusClient({
    required this._client,
    required this._baseUrl,
    this._timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  Future<Object?> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) =>
      _send('GET', path, token: token, query: query);

  Future<Object?> post(String path, {Object? body, String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? query,
  }) async {
    final request = http.Request(
      method,
      _baseUrl.replace(path: path, queryParameters: query),
    );
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      ).timeout(_timeout);
    } on http.ClientException catch (e) {
      throw DirectusUnreachable(e);
    } on TimeoutException catch (e) {
      throw DirectusUnreachable(e);
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return null;
      return (jsonDecode(text) as Map<String, Object?>)['data'];
    }
    throw DirectusError(response.statusCode, _errorCode(text));
  }

  static String? _errorCode(String text) {
    try {
      final errors = (jsonDecode(text) as Map<String, Object?>)['errors'];
      final first = (errors! as List<Object?>).first! as Map<String, Object?>;
      return (first['extensions']! as Map<String, Object?>)['code'] as String?;
    } on Object {
      return null;
    }
  }
}
