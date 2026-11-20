import 'package:flutter/material.dart';

/// Manages the active application locale (`'ar'` default RTL or `'en'` LTR).
class LocaleController extends ChangeNotifier {
  LocaleController({
    String initialLocale = 'ar',
    this._onPersistLocale,
  }) : _localeCode = initialLocale.toLowerCase().startsWith('en') ? 'en' : 'ar';

  String _localeCode;
  final Future<void> Function(String locale)? _onPersistLocale;

  /// Current language code (`'ar'` or `'en'`).
  String get localeCode => _localeCode;

  /// Current Flutter [Locale].
  Locale get locale => Locale(_localeCode);

  /// Whether Arabic RTL is active.
  bool get isArabic => _localeCode == 'ar';

  /// Resolved [TextDirection] for the current locale.
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  /// Switches between Arabic (`'ar'`) and English (`'en'`).
  Future<void> toggleLocale() {
    return setLocale(isArabic ? 'en' : 'ar');
  }

  /// Sets the active locale without persisting to the remote profile (for
  /// example when syncing from a freshly fetched profile).
  void applyLocaleSilently(String code) {
    final normalized = code.toLowerCase().startsWith('en') ? 'en' : 'ar';
    if (normalized == _localeCode) return;
    _localeCode = normalized;
    notifyListeners();
  }

  /// Updates the active locale and optionally persists it to `profiles.locale`.
  Future<void> setLocale(String code) async {
    final normalized = code.toLowerCase().startsWith('en') ? 'en' : 'ar';
    if (normalized == _localeCode) return;
    _localeCode = normalized;
    notifyListeners();
    final persist = _onPersistLocale;
    if (persist != null) {
      try {
        await persist(normalized);
      } catch (_) {
        // Local UI toggle remains responsive even if profile sync fails offline.
      }
    }
  }
}
