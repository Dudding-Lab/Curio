import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Null means: follow the device's language preference.
final selectedLocaleProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _restore();
  }

  static const _key = 'kovunela.language';

  Future<void> _restore() async {
    final stored = await SharedPreferencesAsync().getString(_key);
    if (!mounted || stored == null) return;
    final parts = stored.split('_');
    final locale = parts.length == 2
        ? Locale(parts[0], parts[1])
        : Locale(stored);
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      state = locale;
    }
  }

  static const supportedLanguageCodes = {
    'de', 'en', 'fr', 'es', 'it', 'pt',
  };

  Future<void> select(Locale? locale) async {
    if (locale != null &&
        !supportedLanguageCodes.contains(locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported language');
    }
    state = locale;
    final preferences = SharedPreferencesAsync();
    if (locale == null) {
      await preferences.remove(_key);
    } else {
      final code = locale.countryCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.countryCode}';
      await preferences.setString(_key, code);
    }
  }
}
