import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'utils/constants.dart';
import 'utils/helpers.dart';
// ignore: unused_import — ensures provider bindings are registered at startup
import 'providers/storage_provider.dart';

void main() {
  // runZonedGuarded catches unhandled async errors that would otherwise
  // terminate the process — specifically the firebase_auth Windows plugin bug
  // where auth-state notifications are fired on a non-platform thread.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Google Sign-In requires native support (Android/iOS) or a configured
    // OAuth client ID (web). Skip on desktop; catch on web in case the client
    // ID meta tag is absent — email/password auth still works without it.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await GoogleSignIn.instance.initialize();
    } else if (kIsWeb) {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (_) {
        AppLogger.info('Google Sign-In not configured for web — skipping');
      }
    }
    AppLogger.success('App initialized');
    // Load prefs before runApp so themeModeProvider can read synchronously —
    // no async gap means no theme flash on first frame.
    final prefs = await SharedPreferences.getInstance();
    runApp(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ));
  }, (error, stack) {
    AppLogger.error('Unhandled error: $error', stack);
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      // authStateProvider now emits a uid String? — null means signed out.
      home: authState.when(
        data: (uid) => uid != null ? const MainScreen() : const AuthScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) {
          AppLogger.error('Auth state error: $error', stackTrace);
          return const Scaffold(
            body: Center(child: Text('Error loading app. Please restart.')),
          );
        },
      ),
    );
  }
}
