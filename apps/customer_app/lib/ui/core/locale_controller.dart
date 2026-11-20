import 'package:flutter/material.dart';

/// Manages the active application [Locale] (Arabic RTL by default, with AR/EN
/// runtime switching).
class LocaleController extends ChangeNotifier {
  LocaleController({Locale initialLocale = const Locale('ar')})
      : _locale = initialLocale;

  Locale _locale;

  /// Active locale (`'ar'` or `'en'`).
  Locale get locale => _locale;

  /// Active two-letter language code (`'ar'` or `'en'`).
  String get languageCode => _locale.languageCode;

  /// Whether Arabic RTL is currently active.
  bool get isArabic => _locale.languageCode == 'ar';

  /// Sets the locale explicitly if supported (`'ar'` or `'en'`).
  void setLanguageCode(String code) {
    final normalized = code.toLowerCase().startsWith('en') ? 'en' : 'ar';
    if (_locale.languageCode == normalized) return;
    _locale = Locale(normalized);
    notifyListeners();
  }

  /// Toggles between Arabic (`'ar'`) and English (`'en'`).
  String toggleLocale() {
    final next = isArabic ? 'en' : 'ar';
    setLanguageCode(next);
    return next;
  }
}
