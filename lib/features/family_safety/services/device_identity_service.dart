import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  DeviceIdentityService(this._prefs);

  static const String _kDeviceId = 'family_safety_device_id';
  static const String _kNicknamePrefix = 'family_safety_device_nickname';

  final SharedPreferences _prefs;

  Future<String> ensureDeviceId() async {
    final stored = _prefs.getString(_kDeviceId);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }
    final generated = _generateSecureId();
    await _prefs.setString(_kDeviceId, generated);
    return generated;
  }

  Future<String> currentDeviceId() async {
    final stored = _prefs.getString(_kDeviceId);
    if (stored != null && stored.trim().isNotEmpty) return stored;
    return ensureDeviceId();
  }

  Future<String> nicknameForDevice(String deviceId) async {
    final key = '$_kNicknamePrefix$deviceId';
    final stored = _prefs.getString(key);
    if (stored != null && stored.trim().isNotEmpty) return stored;
    return 'My Device';
  }

  Future<void> saveNickname(String deviceId, String nickname) async {
    final key = '$_kNicknamePrefix$deviceId';
    await _prefs.setString(key, nickname.trim());
  }

  Future<void> clearIdentity() async {
    await _prefs.remove(_kDeviceId);
  }

  String _generateSecureId() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 32; index++) {
      buffer.write(random.nextInt(16).toRadixString(16).toUpperCase());
    }
    return buffer.toString();
  }
}
