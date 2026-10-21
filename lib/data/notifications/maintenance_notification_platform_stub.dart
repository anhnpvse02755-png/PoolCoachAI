class MaintenanceNotificationPlatform {
  bool get isSupported => false;

  String? get permission => null;

  Future<String?> requestPermission() async => null;

  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    throw UnsupportedError('Notifications are not supported on this platform');
  }

  String? readValue(String key) => null;

  void writeValue(String key, String value) {
    throw UnsupportedError('Persistent browser storage is not supported');
  }
}

MaintenanceNotificationPlatform createMaintenanceNotificationPlatform() =>
    MaintenanceNotificationPlatform();
