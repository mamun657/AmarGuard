import 'package:flutter/material.dart';

import '../../data/services/local_prefs.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : _locale = _resolve(_prefs.languageCode);

  final LocalPrefs _prefs;
  Locale _locale;

  static const Locale english = Locale('en');
  static const Locale bangla = Locale('bn');

  static const List<Locale> supported = [english, bangla];

  Locale get locale => _locale;

  bool get isBangla => _locale.languageCode == 'bn';

  String get languageCode => _locale.languageCode;

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode &&
        (_locale.countryCode ?? '') == (locale.countryCode ?? '')) {
      return;
    }
    _locale = locale;
    await _prefs.setLanguageCode(locale.languageCode);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    if (code == 'bn') {
      await setLocale(bangla);
    } else {
      await setLocale(english);
    }
  }

  static Locale _resolve(String code) {
    if (code == 'bn') return bangla;
    return english;
  }
}
