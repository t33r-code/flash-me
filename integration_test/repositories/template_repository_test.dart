// Integration tests for FirebaseTemplateRepository.
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/template_repository_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/repositories/firebase/firebase_template_repository.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseTemplateRepository repo;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('template');
    repo = FirebaseTemplateRepository();
  });

  tearDownAll(cleanupCurrentUser);

  CardTemplate makeTemplate({String name = 'Test Template'}) => CardTemplate(
        id: '',
        createdBy: uid,
        name: name,
        questions: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  group('createTemplate', () {
    test('stores the template and returns it with a generated ID', () async {
      final created = await repo.createTemplate(makeTemplate());

      expect(created.id, isNotEmpty);
      expect(created.name, 'Test Template');
      expect(created.createdBy, uid);
    });
  });

  group('getTemplate', () {
    test('fetches an existing template by ID', () async {
      final created = await repo.createTemplate(makeTemplate());

      final fetched = await repo.getTemplate(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.name, 'Test Template');
    });

    test('returns null for a non-existent template ID', () async {
      final result = await repo.getTemplate('nonexistent-template-id');
      expect(result, isNull);
    });
  });

  group('updateTemplate', () {
    test('persists name changes to Firestore', () async {
      final created = await repo.createTemplate(makeTemplate());
      final changed = created.copyWith(name: 'Renamed Template');

      await repo.updateTemplate(changed);

      final fetched = await repo.getTemplate(created.id);
      expect(fetched!.name, 'Renamed Template');
    });
  });

  group('deleteTemplate', () {
    test('removes the template from Firestore', () async {
      final created = await repo.createTemplate(makeTemplate());

      await repo.deleteTemplate(created.id);

      final fetched = await repo.getTemplate(created.id);
      expect(fetched, isNull);
    });
  });

  group('watchUserTemplates', () {
    test('stream includes templates created by the user', () async {
      final created =
          await repo.createTemplate(makeTemplate(name: 'Stream Template'));

      final templates = await repo.watchUserTemplates(uid).first;

      expect(templates.any((t) => t.id == created.id), isTrue);
    });
  });
}