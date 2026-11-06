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
  final Map<String, int> fieldOrder = {};
  final Map<String, dynamic> values = {};

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
    fieldOrder.remove(key);
    values.remove(key);
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

  String labelFor(String key) =>
      fieldLabels[key]?.trim().isNotEmpty == true
          ? fieldLabels[key]!.trim()
          : key.replaceAll('_', ' ');

  /// Returns typed JSON suitable for review, never for unreviewed persistence.
  /// Blank optional entries are omitted. Errors retain the user's draft.
  Map<String, dynamic> validatedAttributes() {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      final value = values[entry.key];
      if (value == null || (value is String && value.trim().isEmpty)) continue;
      switch (entry.value) {
        case 'text':
          if (value is! String) throw const FormatException('Invalid text');
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
