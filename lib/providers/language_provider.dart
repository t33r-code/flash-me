import 'package:flutter_riverpod/flutter_riverpod.dart';

// Holds the language pair from the last card created during this session.
// Used to pre-fill language pickers when creating a card in the Cards section
// (i.e., not inside a specific set).
typedef SessionLanguages = ({String? native, String? target});

class LastUsedLanguagesNotifier extends Notifier<SessionLanguages?> {
  @override
  SessionLanguages? build() => null;

  void set(SessionLanguages? languages) => state = languages;
}

final lastUsedLanguagesProvider =
    NotifierProvider<LastUsedLanguagesNotifier, SessionLanguages?>(
        LastUsedLanguagesNotifier.new);
