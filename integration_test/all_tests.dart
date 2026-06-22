// Single entry point that runs all repository integration tests in one app launch.
//
// When Flutter runs `flutter test integration_test/` it tries to launch a
// separate Windows app per file, which causes device-conflict errors after the
// first file completes. Running this file instead compiles everything into one
// executable and avoids that problem.
//
// How to run all tests:
//   flutter test integration_test/all_tests.dart -d windows
//
// Individual files can still be run in isolation for faster iteration:
//   flutter test integration_test/repositories/card_repository_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'repositories/card_repository_test.dart' as card_tests;
import 'repositories/card_set_repository_test.dart' as set_tests;
import 'repositories/firestore_rules_test.dart' as rules_tests;
import 'repositories/study_session_repository_test.dart' as session_tests;
import 'repositories/template_repository_test.dart' as template_tests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Wrapping each file's main() in a group scopes its setUpAll/tearDownAll
  // to that group, so each file gets its own user and clean auth state.
  group('card_repository', card_tests.main);
  group('card_set_repository', set_tests.main);
  group('study_session_repository', session_tests.main);
  group('template_repository', template_tests.main);
  group('firestore_rules', rules_tests.main);
}
