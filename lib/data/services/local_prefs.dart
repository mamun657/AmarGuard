import 'package:shared_preferences/shared_preferences.dart';

class LocalPrefs {
  LocalPrefs._(this._prefs);

  static const _kOnboardingComplete = 'onboarding_complete';
  static const _kGuestMode = 'guest_mode';
  static const _kLanguageCode = 'language_code';

  final SharedPreferences _prefs;

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

  String get languageCode {
    final stored = _prefs.getString(_kLanguageCode) ?? '';
    if (stored == 'bn') return 'bn';
    return 'en';
  }

  Future<void> setLanguageCode(String code) =>
      _prefs.setString(_kLanguageCode, code);
}
