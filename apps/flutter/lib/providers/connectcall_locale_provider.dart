import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Overridden in main.dart
});

class LocaleNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const _key = 'app_locale';

  LocaleNotifier(this._prefs) : super(_prefs.getString(_key) ?? 'en');

  void toggleLocale() {
    state = state == 'en' ? 'hi' : 'en';
    _prefs.setString(_key, state);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});
