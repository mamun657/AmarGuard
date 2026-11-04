import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPrefs {
  LocalPrefs._(this._prefs);

  static const _kOnboardingComplete = 'onboarding_complete';
  static const _kGuestMode = 'guest_mode';
  static const _kLanguageCode = 'language_code';

  final SharedPreferences _prefs;
  final ValueNotifier<int> _careSignalReadRevision = ValueNotifier<int>(0);

  SharedPreferences get preferences => _prefs;
  Listenable get careSignalReadChanges => _careSignalReadRevision;

  static Future<LocalPrefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPrefs._(prefs);
  }

  bool get hasCompletedOnboarding =>
      _prefs.getBool(_kOnboardingComplete) ?? false;

  Future<void> markOnboardingComplete() =>
      _prefs.setBool(_kOnboardingComplete, true);

  bool get isGuest => _prefs.getBool(_kGuestMode) ?? false;

  Future<void> setGuest(bool value) => _prefs.setBool(_kGuestMode, value);

  Future<void> clearGuest() => _prefs.remove(_kGuestMode);

  List<String> readCareSignalRequestIds(String uid) =>
      _prefs.getStringList(_careSignalReadKey(uid)) ?? const <String>[];

  Future<void> markCareSignalRequestRead(String uid, String requestId) async {
    final requestIds = readCareSignalRequestIds(uid).toSet()..add(requestId);
    final saved = await _prefs.setStringList(
      _careSignalReadKey(uid),
      requestIds.toList(),
    );
    if (!saved) throw StateError('Could not save the CareSignal read state.');
    _careSignalReadRevision.value++;
  }

  String _careSignalReadKey(String uid) => 'caresignal_read_requests_$uid';

  String get languageCode {
    final stored = _prefs.getString(_kLanguageCode) ?? '';
    if (stored == 'bn') return 'bn';
    return 'en';
  }

  Future<void> setLanguageCode(String code) =>
      _prefs.setString(_kLanguageCode, code);
}
