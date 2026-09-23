import 'package:poolcoachai/domain/auth.dart';

/// Xác thực người chơi — màn hình chỉ biết interface này, không biết Directus.
abstract interface class AuthRepository {
  /// Trạng thái hiện tại, đọc đồng bộ để router quyết định ngay khung đầu.
  AuthState get current;

  /// Chỉ phát khi trạng thái **đổi**; giá trị ban đầu đọc ở [current].
  Stream<AuthState> watchSession();

  /// Đọc phiên đã lưu trên máy. Không cần mạng: mở app offline vẫn vào thẳng.
  Future<void> restore();

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  /// Chỉ dùng khi người chơi **bấm** Đăng xuất. Tự động đăng xuất đi
  /// đường khác và không bao giờ gọi hàm này — xem spec mục 5.4.
  Future<void> signOut();

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({required String token, required String password});

  /// Access token còn hạn, tự làm mới khi còn dưới một phút.
  ///
  /// Ném [AuthFailure.network] khi mất mạng (vẫn giữ đăng nhập) và
  /// [AuthFailure.sessionExpired] khi server từ chối phiên.
  Future<String> accessToken();
}

/// Phiên đăng nhập đã lưu trên máy.
class StoredSession {
  const StoredSession({
    required this.userId,
    required this.displayName,
    required this.refreshToken,
  });

  final String userId;
  final String displayName;
  final String refreshToken;
}

/// Nơi giữ [StoredSession] — tách khỏi Drift để test xác thực không cần DB.
abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}
