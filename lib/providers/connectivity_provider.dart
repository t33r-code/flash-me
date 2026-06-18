import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Streams connectivity status, seeded with the current state so the offline
// banner reflects reality immediately on startup (before any change fires).
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

// True when at least one network interface is active.
// Optimistically true while the initial check is in flight so there is no
// false offline flash during app startup.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).when(
    data: (list) => list.any((r) => r != ConnectivityResult.none),
    loading: () => true,
    error: (_, _) => true,
  );
});