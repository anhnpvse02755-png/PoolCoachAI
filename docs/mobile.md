# PoolCoach AI trên điện thoại (Android và iOS)

Cùng một codebase Flutter chạy trên web, Android và iOS. Application id
(Android) và bundle id (iOS): `vn.poolcoachai.app`. Tên hiển thị: **PoolCoach AI**.

## Chuẩn bị máy build (Windows)

Trong PowerShell, mỗi lần mở cửa sổ mới (hoặc đặt vĩnh viễn trong biến môi trường người dùng):

```powershell
$env:PATH += ";C:\Users\anhnpv\flutter\bin"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "C:\Users\anhnpv\AppData\Local\Android\sdk"
$env:PATH += ";$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator"
```

`database.g.dart` không được commit, nên sau khi clone/pull phải sinh lại:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Lần build Gradle đầu tiên rất lâu (khoảng 16 phút, tải phụ thuộc); các lần sau nhanh.

## Địa chỉ server

| Tham số build | Mặc định | Dùng để |
|---|---|---|
| `--dart-define=API_URL=…` | `https://poolcoachai-api.kjdybl.easypanel.host` | Directus |
| `--dart-define=WEB_URL=…` | `https://poolcoachai.kjdybl.easypanel.host` | Link đặt lại mật khẩu trong email (app native không có địa chỉ web riêng, người dùng bấm link rồi đặt mật khẩu trên trang web) |
| `--dart-define=COACH_CHAT_URL=…` | `https://poolcoachai-coach.kjdybl.easypanel.host` | Dịch vụ coach-chat (Hỏi huấn luyện viên) |

`WEB_URL` + `/reset-password` phải nằm trong `PASSWORD_RESET_URL_ALLOW_LIST` của Directus
(bản live đã có).

## Build và chạy Android

```powershell
# Debug, chạy thẳng lên máy/emulator đang kết nối
flutter run

# APK release (ký bằng khoá thật nếu có android/key.properties)
flutter build apk --release
#   -> build\app\outputs\flutter-apk\app-release.apk

# App Bundle cho Google Play (sau này)
flutter build appbundle --release
#   -> build\app\outputs\bundle\release\app-release.aab
```

Không có `android/key.properties` (CI, máy người khác) thì bản release tự ký bằng khoá
debug — vẫn cài và chạy được nhưng **không đưa lên Play Store được**.

### Khoá ký release (QUAN TRỌNG — sao lưu)

- Keystore: `C:\Users\anhnpv\.poolcoachai-keys\poolcoachai-release.jks` (alias `poolcoachai`)
- Mật khẩu + đường dẫn: `C:\Users\anhnpv\.poolcoachai-keys\key.properties.backup.txt`
- `android/key.properties` (đã gitignore) là bản sao của file trên mà Gradle đọc.

**Mất file `.jks` hoặc mật khẩu là không thể cập nhật app đã đưa lên Play Store nữa**
(chỉ còn cách phát hành app mới). Hãy chép cả hai file vào nơi an toàn (trình quản lý mật
khẩu, ổ đĩa mã hoá, USB cất riêng). Không commit, không gửi qua chat/email.

Trên máy khác: chép `poolcoachai-release.jks` vào máy đó, tạo `android/key.properties`:

```
storePassword=…
keyPassword=…
keyAlias=poolcoachai
storeFile=C:/đường/dẫn/poolcoachai-release.jks
```

### Chạy trên emulator

1. Bật ảo hoá: trong Windows, bật **Windows Hypervisor Platform** (Turn Windows features
   on or off) và bật Virtualization (Intel VT-x / AMD-V) trong BIOS, rồi khởi động lại.
2. Cài cmdline-tools + system image (đã làm trên máy này):
   `sdkmanager "system-images;android-35;google_apis;x86_64"`
3. Tạo máy ảo: `avdmanager create avd -n pcai_api35 -k "system-images;android-35;google_apis;x86_64" -d pixel_6`
4. Chạy: `emulator -avd pcai_api35`, rồi `flutter run`.

### Chạy trên điện thoại thật (USB debugging)

1. Trên điện thoại: **Cài đặt > Giới thiệu điện thoại**, bấm 7 lần vào **Số bản dựng**
   (Build number) để bật Tuỳ chọn nhà phát triển.
2. **Cài đặt > Tuỳ chọn nhà phát triển > Gỡ lỗi USB** (USB debugging): bật.
3. Cắm cáp USB (cáp có truyền dữ liệu, không phải cáp chỉ sạc) vào máy tính. Chọn chế độ
   **Truyền tệp** nếu điện thoại hỏi.
4. Điện thoại hiện hộp thoại "Cho phép gỡ lỗi USB?": chọn **Luôn cho phép** rồi **Cho phép**.
5. Kiểm tra: `adb devices` phải thấy máy ở trạng thái `device` (không phải `unauthorized`).
6. `flutter run` (debug) hoặc `adb install -r build\app\outputs\flutter-apk\app-release.apk`.

Có thể gửi thẳng file `app-release.apk` qua Zalo/Drive rồi mở trên điện thoại (cho phép
"Cài ứng dụng không rõ nguồn gốc"), không cần cáp.

### Thông báo nhắc bảo dưỡng đầu cơ

- App đặt lịch thông báo của hệ điều hành lúc **09:00 giờ máy**, trước hạn bảo dưỡng 7 ngày và
  đúng ngày hạn; lịch được đặt lại mỗi khi danh sách cơ đổi và huỷ hết khi đăng xuất.
- Android 13 trở lên và iOS sẽ hỏi quyền khi bấm **Bật thông báo** ở màn Dụng cụ.
- Dùng lịch "không chính xác": Android có thể báo lệch vài phút, đổi lại không cần quyền
  báo thức chính xác. Một số hãng (Xiaomi, Oppo…) có chế độ tiết kiệm pin chặn thông báo nền:
  cần cho phép app chạy nền nếu không thấy thông báo.

### Phông chữ

App dùng `google_fonts` (Be Vietnam Pro, JetBrains Mono) và tải phông lúc chạy qua mạng
rồi cache. Lần mở đầu tiên khi không có mạng sẽ hiện phông hệ thống thay thế; có mạng một
lần là đủ. Chưa đóng gói phông vào APK.

## iOS

Không build được trên Windows: iOS build bằng **GitHub Actions trên macOS** —
`.github/workflows/ios.yml`.

- Mỗi lần push/PR vào `main` (hoặc chạy tay: tab Actions > iOS / build > Run workflow), job
  `build-ios` chạy `flutter build ios --release --no-codesign` và đưa `Runner.app.zip` lên
  mục Artifacts. Đây là bản **chưa ký**: chỉ chứng minh app biên dịch được, chưa cài lên
  iPhone được.
- Job `Android / test` (`.github/workflows/android.yml`, ubuntu) chạy `flutter analyze`,
  `flutter test` và `flutter build apk --debug`. Test không chạy trên macOS để đỡ tốn phút.

### iOS: cần gì từ Apple

Để cài lên iPhone thật hoặc đưa lên TestFlight/App Store cần:

1. **Apple Developer Program** (99 USD/năm), đăng ký bằng Apple ID.
2. Tạo **App ID** `vn.poolcoachai.app` trong Certificates, Identifiers & Profiles.
3. Tạo chứng chỉ **Apple Distribution** (xuất ra file `.p12` kèm mật khẩu) và
   **provisioning profile** loại App Store cho App ID trên.
4. Trong **App Store Connect**: tạo app với bundle id trên; tạo **API key** (Users and
   Access > Integrations) để tải file `.p8`, ghi Key ID và Issuer ID.
5. Thêm 6 secret vào GitHub (Settings > Secrets and variables > Actions):
   `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`,
   `IOS_PROVISIONING_PROFILE_BASE64`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`,
   `APPSTORE_API_PRIVATE_KEY` (base64 một file: `base64 -i file.p12`).
6. Thêm `ios/ExportOptions.plist` (method `app-store`, teamID, tên profile), rồi trong
   `ios.yml` đổi `if: false` của job `testflight` thành `if: true`. Job đó đã viết sẵn
   (nhập chứng chỉ, `flutter build ipa`, đẩy lên TestFlight) nhưng đang **tắt**.

Thông báo trên iOS: `AppDelegate.swift` đã đặt delegate của `UNUserNotificationCenter`; quyền
được hỏi lúc người dùng bấm **Bật thông báo**.
