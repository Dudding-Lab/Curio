/// Local-only draft of a derived object template.
/// Nothing in this model writes to Supabase.
class TemplateDraft {
  TemplateDraft({
    required this.standardCode,
    required this.standardFields,
  });

  final String standardCode;
  final Map<String, String> standardFields;
  final Map<String, String> addedFields = {};
  final Map<String, String> fieldLabels = {};
  final Set<String> hiddenFields = {};
  final Set<String> requiredFields = {};
  final Map<String, List<String>> fieldChoices = {};
  final Map<String, Map<String, String>> localizedLabels = {};
  final Map<String, int> fieldOrder = {};
  final Map<String, dynamic> values = {};
  final Map<String, String> translationModes = {};

  /// Only textual content can be translated; machine-readable values stay fixed.
  /// A translated display value never replaces the captured original.
  String translationModeFor(String key) {
    if (fields[key] != 'text') return 'original';
    return translationModes[key] ??
        (const {'description', 'summary', 'notes', 'review', 'synopsis'}
                .contains(key)
            ? 'translate'
            : 'original');
  }

  void setTranslationMode(String key, String mode) {
    if (!fields.containsKey(key) ||
        !const {'original', 'translate'}.contains(mode) ||
        (mode == 'translate' && fields[key] != 'text')) {
      throw ArgumentError('Invalid translation policy');
    }
    translationModes[key] = mode;
  }

  Map<String, Map<String, dynamic>> get fieldPresentation {
    final result = <String, Map<String, dynamic>>{};
    for (final key in fields.keys) {
      final settings = <String, dynamic>{};
      if (fieldLabels[key]?.trim().isNotEmpty == true) {
        settings['label'] = fieldLabels[key]!.trim();
      }
      if (hiddenFields.contains(key)) {
        settings['hidden'] = true;
      }
      if (requiredFields.contains(key)) {
        settings['required'] = true;
      }
      if (fieldChoices.containsKey(key)) {
        settings['choices'] = fieldChoices[key];
      }
      if (localizedLabels[key]?.isNotEmpty == true) {
        settings['labels'] = localizedLabels[key];
      }
      if (fieldOrder.containsKey(key)) {
        settings['order'] = fieldOrder[key];
      }
      if (fields[key] == 'text') {
        settings['translation_mode'] = translationModeFor(key);
      }
      if (settings.isNotEmpty) {
        result[key] = settings;
      }
    }
    return result;
  }

  static final _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static const supportedTypes = {'text', 'number', 'boolean', 'date'};

  Map<String, String> get fields => {...standardFields, ...addedFields};

  /// A field identifier must not shadow a pre-existing field.
  String? validateField(String key, String type) {
    if (!_keyPattern.hasMatch(key)) return 'invalid_key';
    if (!supportedTypes.contains(type)) return 'invalid_type';
    if (fields.containsKey(key)) return 'duplicate_key';
    if (fields.length >= 30) return 'too_many_fields';
    return null;
  }

  String? addField(String key, String type) {
    final error = validateField(key, type);
    if (error != null) return error;
    addedFields[key] = type;
    return null;
  }

  void removeAddedField(String key) {
    if (!addedFields.containsKey(key)) return;
    addedFields.remove(key);
    fieldLabels.remove(key);
    hiddenFields.remove(key);
    requiredFields.remove(key);
    fieldChoices.remove(key);
    localizedLabels.remove(key);
    fieldOrder.remove(key);
    values.remove(key);
    translationModes.remove(key);
  }

  List<String> get visibleFieldKeys {
    final all = fields.keys.where((key) => !hiddenFields.contains(key)).toList();
    all.sort((a, b) {
      final left = fieldOrder[a] ?? 999;
      final right = fieldOrder[b] ?? 999;
      final order = left.compareTo(right);
      return order == 0 ? a.compareTo(b) : order;
    });
    return all;
  }

  String labelFor(String key, {String? language}) {
    final localized = localizedLabels[key];
    if (language != null && localized != null) {
      final match = localized[language] ?? localized[language.split('-').first];
      if (match != null && match.trim().isNotEmpty) return match.trim();
    }
    if (fieldLabels[key]?.trim().isNotEmpty == true) {
      return fieldLabels[key]!.trim();
    }
    return key.replaceAll('_', ' ');
  }


  void setLocalizedLabel(String key, String locale, String label) {
    if (!fields.containsKey(key) ||
        !RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$').hasMatch(locale) ||
        label.trim().length > 120) {
      throw ArgumentError('Invalid localized label');
    }
    if (label.trim().isEmpty) {
      localizedLabels[key]?.remove(locale);
    } else {
      localizedLabels.putIfAbsent(key, () => {})[locale] = label.trim();
    }
  }

  void setChoices(String key, List<String> choices) {
    if (fields[key] != 'text') {
      throw ArgumentError('Choices require text');
    }
    if (choices.isEmpty) {
      fieldChoices.remove(key);
      return;
    }
    if (choices.length < 2 || choices.length > 30 ||
        choices.any((choice) =>
            choice.trim().isEmpty || choice.trim().length > 120) ||
        choices.map((value) => value.trim()).toSet().length != choices.length) {
      throw ArgumentError('Invalid options');
    }
    fieldChoices[key] = choices.map((value) => value.trim()).toList();
    if (!fieldChoices[key]!.contains(values[key])) {
      values.remove(key);
    }
  }

  /// Returns typed JSON suitable for review, never for unreviewed persistence.
  /// Blank optional entries are omitted. Errors retain the user's draft.
  Map<String, dynamic> validatedAttributes() {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      final value = values[entry.key];
      if (value == null || (value is String && value.trim().isEmpty)) {
        if (requiredFields.contains(entry.key)) {
          throw FormatException('Required field: ${entry.key}');
        }
        continue;
      }
      switch (entry.value) {
        case 'text':
          if (value is! String) throw const FormatException('Invalid text');
          if (fieldChoices.containsKey(entry.key) &&
              !fieldChoices[entry.key]!.contains(value.trim())) {
            throw FormatException('Invalid choice: ${entry.key}');
          }
          result[entry.key] = value.trim();
        case 'number':
          final number = value is num ? value : num.tryParse(value.toString());
          if (number == null || !number.isFinite) {
            throw FormatException('Invalid number: ${entry.key}');
          }
          result[entry.key] = number;
        case 'boolean':
          if (value is! bool) throw const FormatException('Invalid boolean');
          result[entry.key] = value;
        case 'date':
          if (value is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
            throw FormatException('Invalid date: ${entry.key}');
          }
          final date = DateTime.tryParse(value);
          if (date == null ||
              '${date.year.toString().padLeft(4, '0')}-'
                      '${date.month.toString().padLeft(2, '0')}-'
                      '${date.day.toString().padLeft(2, '0')}' !=
                  value) {
            throw FormatException('Invalid date: ${entry.key}');
          }
          result[entry.key] = value;
        default:
          throw const FormatException('Unsupported field type');
      }
    }
    return result;
  }
}
