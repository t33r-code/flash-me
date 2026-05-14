import 'package:flutter/material.dart';
import 'package:flash_me/utils/languages.dart';

// Dropdown for selecting an ISO 639-1 language code.
// Null value means "not set"; always offered as the first option.
class LanguagePicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const LanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Not set'),
        ),
        ...kLanguages.map(
          (lang) => DropdownMenuItem<String?>(
            value: lang.code,
            child: Text(lang.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
