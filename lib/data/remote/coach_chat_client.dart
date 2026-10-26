import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/coach/chat_filter.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

/// Client HTTP mỏng cho dịch vụ coach-chat (Task 6 wire contract). Mọi câu
/// trả lời đi qua [filterCoachReply] trước khi tới màn hình (spec Giai đoạn
/// B mục 9); bị chặn thì báo máy chủ tên luật qua `/blocked` (spec S2),
/// không chặn việc trả lời cho người chơi dù báo lỗi.
///
/// Lỗi gộp thành ba nhóm, mỗi nhóm một hành vi (R4):
/// - [AuthFailure.sessionExpired] từ lớp auth: ném nguyên văn, không gửi gì
///   — lớp auth đã tự đăng xuất, router tự rời màn.
/// - HTTP 429: [CoachChatQuotaExceeded] mang `resetAt`.
/// - Mọi lỗi khác (mất mạng, hết giờ, 401, 4xx khác, 502 upstream, 503, 500,
///   phản hồi hỏng): [CoachChatUnavailable] — màn hình nói "thử lại sau".
class RemoteCoachChat implements CoachChatBackend {
  // Như [DirectusClient]: `this._field` nhưng callers vẫn gọi `client:`,
  // `baseUrl:`, `auth:` (Dart bỏ gạch dưới ở tên tham số khi khởi tạo
  // trường bằng `this.`) — khớp đúng chữ ký Task 8 brief.
  RemoteCoachChat({
    required this._client,
    required this._baseUrl,
    required this._auth,
    this.replyTimeout = const Duration(seconds: 180),
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Uri _baseUrl;
  final AuthRepository _auth;

  /// Hết giờ cho `POST /v1/coach-chat` — chờ tới 180 s, vì thời gian xử lý
  /// tệ nhất của dịch vụ khoảng 170 s (ruling của controller).
  final Duration replyTimeout;

  /// Hết giờ cho các lời gọi nhanh: lấy quota, báo luật chặn.
  final Duration timeout;

  @override
  Future<CoachChatAnswer> reply(
    CoachContext context,
    List<CoachChatTurn> history,
    String question,
  ) async {
    final token = await _token();
    final facts = context.toFacts();
    final response = await _send(
      'POST',
      '/v1/coach-chat',
      token: token,
      body: {
        'facts': facts,
        'history': [
          for (final turn in history) {'fromPlayer': turn.fromPlayer, 'text': turn.text},
        ],
        'question': question,
      },
      timeout: replyTimeout,
    );

    if (response.statusCode == 429) {
      final body = _decode(response);
      throw CoachChatQuotaExceeded(_requireDateTime(body, 'resetAt'));
    }
    if (response.statusCode == 502) {
      final body = _decode(response);
      final error = body['error'];
      if (error == 'refused' || error == 'truncated') {
        return (
          reply: (text: '', insufficient: true),
          remainingToday: _require<int>(body, 'remainingToday'),
        );
      }
      throw CoachChatUnavailable(response.statusCode);
    }
    if (response.statusCode != 200) throw CoachChatUnavailable(response.statusCode);

    final body = _decode(response);
    final raw = _require<String>(body, 'text');
    final remainingToday = _require<int>(body, 'remainingToday');
    final rule = coachReplyBlock(raw, facts);
    if (rule != null) unawaited(_reportBlocked(token, rule.name));
    return (reply: filterCoachReply(raw, facts), remainingToday: remainingToday);
  }

  @override
  Future<int> remainingToday() async {
    final token = await _token();
    final response = await _send('GET', '/v1/coach-chat/quota', token: token, timeout: timeout);
    if (response.statusCode != 200) throw CoachChatUnavailable(response.statusCode);
    return _require<int>(_decode(response), 'remainingToday');
  }

  /// Báo máy chủ tên luật đã chặn — nuốt mọi lỗi (spec S2): câu trả lời đã
  /// về tới màn hình, việc báo lỗi không được làm hỏng trải nghiệm đó.
  Future<void> _reportBlocked(String token, String rule) async {
    try {
      await _send('POST', '/v1/coach-chat/blocked', token: token, body: {'rule': rule}, timeout: timeout);
    } on Object {
      // Nuốt mọi lỗi — xem doc comment của hàm.
    }
  }

  Future<String> _token() async {
    try {
      return await _auth.accessToken();
    } on AuthFailure catch (e) {
      if (e == AuthFailure.sessionExpired) rethrow;
      throw CoachChatUnavailable(e);
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    required String token,
    Object? body,
    required Duration timeout,
  }) async {
    final request = http.Request(method, _baseUrl.replace(path: path));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    try {
      return await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on http.ClientException catch (e) {
      throw CoachChatUnavailable(e);
    } on TimeoutException catch (e) {
      throw CoachChatUnavailable(e);
    }
  }

  Map<String, Object?> _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    } on Object {
      // Không dùng lại FormatException nguyên văn: lỗi của jsonDecode kèm
      // theo một đoạn thân phản hồi gốc (R5 vòng 2, review Task 8).
      throw const CoachChatUnavailable('unreadable body');
    }
  }

  /// Đọc một trường bắt buộc khỏi thân JSON đã giải mã, đúng kiểu [T].
  /// Thiếu trường, `null`, hay sai kiểu đều là thân phản hồi không đọc
  /// được (brief: "any unreadable body → CoachChatUnavailable") — không
  /// để lộ nguyên văn thân phản hồi ra ngoài (R5 vòng 2).
  T _require<T>(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is T) return value;
    throw const CoachChatUnavailable('unreadable body');
  }

  DateTime _requireDateTime(Map<String, Object?> body, String key) {
    final raw = _require<String>(body, key);
    try {
      return DateTime.parse(raw);
    } on FormatException {
      throw const CoachChatUnavailable('unreadable body');
    }
  }
}
