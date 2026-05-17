import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// sharedPreferencesProvider — synchronous access to SharedPreferences.
// Always overridden at startup in main.dart before runApp so the instance is
// available before any widget builds.
// ---------------------------------------------------------------------------
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('override at startup'),
);

// ---------------------------------------------------------------------------
// themeModeProvider — persists the user's chosen ThemeMode to device storage.
// Reads the saved value synchronously from the SharedPreferences instance
// supplied at startup; no async gap means no theme flash on launch.
// ---------------------------------------------------------------------------
const _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _fromString(prefs.getString(_kThemeModeKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeModeKey, _toString(mode));
  }

  static ThemeMode _fromString(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode() => 'system',
      };
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
