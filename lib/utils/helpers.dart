import 'package:flutter/material.dart';

// Ring buffer of the last 150 log lines; populated by AppLogger.
// The feedback dialog reads this when the user checks "Include app logs".
class LogBuffer {
  static final LogBuffer _instance = LogBuffer._internal();
  factory LogBuffer() => _instance;
  LogBuffer._internal();

  static const _maxLines = 150;
  final _lines = <String>[];

  void add(String line) {
    _lines.add(line);
    if (_lines.length > _maxLines) _lines.removeAt(0);
  }

  // Returns all buffered lines joined by newlines.
  String dump() => _lines.join('\n');
}

class AppLogger {
  static final _buffer = LogBuffer();

  static void info(String message) {
    const prefix = 'ℹ️ INFO';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void debug(String message) {
    const prefix = '🐛 DEBUG';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void warning(String message) {
    const prefix = '⚠️ WARNING';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void error(String message, [StackTrace? stackTrace]) {
    const prefix = '❌ ERROR';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void success(String message) {
    const prefix = '✅ SUCCESS';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }
}

class AppHelpers {
  // Normalise a raw tag string to its canonical Firestore document ID form:
  // trim whitespace, lowercase, collapse runs of whitespace to a single hyphen.
  // Returns an empty string if the result is empty (caller should discard it).
  static String normalizeTag(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  // Diff two tag lists and return which tags were added and which removed.
  // Both sides are normalised before comparison so casing differences are
  // treated as the same tag.  Returns (toUpsert, toDecrement) where:
  //   toUpsert   — normalised names present in [newTags] but not [oldTags]
  //   toDecrement — normalised names present in [oldTags] but not [newTags]
  static (List<String>, List<String>) diffTags(
      List<String> oldTags, List<String> newTags) {
    final oldNorm =
        oldTags.map(normalizeTag).where((t) => t.isNotEmpty).toSet();
    final newNorm =
        newTags.map(normalizeTag).where((t) => t.isNotEmpty).toSet();
    return (
      newNorm.difference(oldNorm).toList(),
      oldNorm.difference(newNorm).toList(),
    );
  }

  // Log a non-fatal tag write failure. Called from fire-and-forget upsert/
  // decrement paths where the error must not propagate to the caller.
  static void logTagError(String operation, String tag, Object error) {
    AppLogger.warning('Tag $operation failed for "$tag": $error');
  }

  // Returns true if [input] matches any string in [accepted] under normalised
  // rules: always trims, lowercases, and strips common Latin diacritics.
  // Unless [exact] is true, also forgives small typos (Levenshtein ≤ 1 for
  // words up to 5 chars, ≤ 2 for longer).
  static bool isAnswerCorrect(String input, List<String> accepted,
      {bool exact = false}) {
    final norm = _normalizeForMatch(input.trim());
    if (norm.isEmpty) return false;
    return accepted.any((a) {
      final normA = _normalizeForMatch(a.trim());
      if (norm == normA) return true;
      if (exact) return false;
      return _levenshtein(norm, normA) <=
          _editThreshold(norm.length, normA.length);
    });
  }

  // Lowercase + map common Latin diacritics to their base letter.
  // Covers European language learning use cases without requiring a package.
  static String _normalizeForMatch(String s) {
    // All lowercase codepoints for common diacritics mapped to plain ASCII.
    const map = <int, String>{
      // a: à á â ã ä å
      0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
      // e: è é ê ë
      0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
      // i: ì í î ï
      0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
      // o: ò ó ô õ ö ø
      0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o',
      // u: ù ú û ü
      0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u',
      // y: ý ÿ
      0xFD: 'y', 0xFF: 'y',
      // n: ñ
      0xF1: 'n',
      // c: ç
      0xE7: 'c',
      // ß → s (simplified; 'ss' would break length-based threshold)
      0xDF: 's',
      // æ → a (simplified)
      0xE6: 'a',
      // œ → o (simplified)
      0x153: 'o',
    };
    final buf = StringBuffer();
    // toLowerCase() first so only lowercase codepoints need to be in the map.
    for (final cp in s.toLowerCase().runes) {
      buf.write(map[cp] ?? String.fromCharCode(cp));
    }
    return buf.toString();
  }

  // Standard Levenshtein edit distance.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        curr[j] = a[i - 1] == b[j - 1]
            ? prev[j - 1]
            : 1 +
                [prev[j], curr[j - 1], prev[j - 1]]
                    .reduce((x, y) => x < y ? x : y);
      }
      prev.setAll(0, curr);
    }
    return prev[b.length];
  }

  // Allowed edit distance: 0 for ≤2 chars, 1 for ≤5, 2 for longer.
  // Short words (1–2 chars) get no tolerance to avoid over-accepting common
  // function words ("a", "in", "is") being confused with each other.
  static int _editThreshold(int lenA, int lenB) {
    final avg = (lenA + lenB) ~/ 2;
    if (avg <= 2) return 0;
    if (avg <= 5) return 1;
    return 2;
  }
}

class AppValidators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }
    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }
}
