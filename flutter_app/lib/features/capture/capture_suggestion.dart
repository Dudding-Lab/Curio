import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/features/taxonomy/template_draft.dart';

/// A structured proposal from a future OCR / vision / catalog enrichment adapter.
/// This is untrusted input: all keys and values must be checked against the
/// selected template before the user can adopt them.
class CaptureSuggestion {
  const CaptureSuggestion({
    required this.templateCode,
    required this.title,
    required this.attributes,
    this.evidence = const {},
    this.confidence,
  });

  final String templateCode;
  final String title;
  final Map<String, dynamic> attributes;
  final Map<String, String> evidence;
  final double? confidence;

  factory CaptureSuggestion.fromJson(Map<String, dynamic> json) {
    final raw = json['attributes'];
    if (raw is! Map) throw const FormatException('Missing attributes');
    final attrs = Map<String, dynamic>.from(raw);
    if (attrs.length > 30) throw const FormatException('Too many attributes');
    final title = json['title'];
    final code = json['template_code'];
    if (title is! String ||
        title.trim().isEmpty ||
        title.trim().length > 200 ||
        code is! String) {
      throw const FormatException('Invalid suggestion');
    }
    final confidence = json['confidence'];
    if (confidence != null &&
        (confidence is! num || !confidence.isFinite ||
            confidence < 0 || confidence > 1)) {
      throw const FormatException('Invalid confidence');
    }
    final rawEvidence = json['evidence'];
    final evidence = rawEvidence == null
        ? <String, String>{}
        : (rawEvidence is Map
            ? Map<String, dynamic>.from(rawEvidence).map((key, value) {
                if (value is! String || value.length > 500) {
                  throw const FormatException('Invalid evidence');
                }
                return MapEntry(key, value);
              })
            : throw const FormatException('Invalid evidence'));
    return CaptureSuggestion(
      templateCode: code,
      title: title.trim(),
      attributes: attrs,
      confidence: confidence?.toDouble(),
      evidence: evidence,
    );
  }
}

class CaptureMatch {
  const CaptureMatch({
    required this.template,
    required this.score,
    required this.matches,
  });

  final StandardObjectTemplate template;
  final double score;
  final int matches;
}

/// Deterministic candidate ranking; does not itself claim to identify an
/// object or call AI. Excludes all unknown keys from scoring.
class CaptureSuggestionMatcher {
  static List<CaptureMatch> rank(
    Map<String, dynamic> observedAttributes,
    List<StandardObjectTemplate> templates,
  ) {
    final results = <CaptureMatch>[];
    for (final template in templates) {
      final count = observedAttributes.keys
          .where((key) => template.fields.containsKey(key))
          .length;
      if (count == 0) continue;
      final score = count / template.fields.length;
      results.add(CaptureMatch(
        template: template,
        score: score,
        matches: count,
      ));
    }
    results.sort((a, b) {
      final byCount = b.matches.compareTo(a.matches);
      if (byCount != 0) return byCount;
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.template.code.compareTo(b.template.code);
    });
    return results;
  }
}

class CaptureReview {
  CaptureReview({
    required this.template,
    required this.proposal,
    Set<String>? requiredFields,
    Map<String, List<String>>? choices,
  }) : draft = TemplateDraft(
          standardCode: template.code,
          standardFields: template.fields,
        ) {
    draft.requiredFields.addAll(
      (requiredFields ?? const <String>{})
          .where((key) => template.fields.containsKey(key)),
    );
    for (final entry in (choices ?? const <String, List<String>>{}).entries) {
      if (template.fields[entry.key] == 'text') {
        draft.setChoices(entry.key, entry.value);
      }
    }
    _screenProposal();
  }

  final StandardObjectTemplate template;
  final CaptureSuggestion proposal;
  final TemplateDraft draft;
  final Map<String, dynamic> accepted = {};
  final Map<String, String> rejectedReasons = {};
  String? _reviewedTitle;

  String get suggestedTitle => proposal.title;
  String get reviewedTitle => _reviewedTitle ?? proposal.title;

  void setTitle(String value) {
    _reviewedTitle = value;
  }

  void _screenProposal() {
    if (proposal.templateCode != template.code) {
      throw const FormatException('Suggested template mismatch');
    }
    for (final entry in proposal.attributes.entries) {
      if (!template.fields.containsKey(entry.key)) {
        rejectedReasons[entry.key] = 'unknown_field';
        continue;
      }
      final one = TemplateDraft(
        standardCode: template.code,
        standardFields: {entry.key: template.fields[entry.key]!},
      );
      if (draft.fieldChoices.containsKey(entry.key)) {
        one.setChoices(entry.key, draft.fieldChoices[entry.key]!);
      }
      one.values[entry.key] = entry.value;
      try {
        final result = one.validatedAttributes();
        if (!result.containsKey(entry.key)) {
          rejectedReasons[entry.key] = 'empty_value';
        } else {
          accepted[entry.key] = result[entry.key];
          draft.values[entry.key] = result[entry.key];
        }
      } on FormatException {
        rejectedReasons[entry.key] = 'type_or_choice_mismatch';
      }
    }
  }

  List<String> get missingRequiredFields {
    final missing = <String>[];
    for (final key in draft.requiredFields) {
      final value = draft.values[key];
      if (value == null || (value is String && value.trim().isEmpty)) {
        missing.add(key);
      }
    }
    missing.sort();
    return missing;
  }

  /// Can be used to preview a valid payload. Never persists anything.
  Map<String, dynamic> validatedAttributes() {
    if (reviewedTitle.trim().isEmpty || reviewedTitle.trim().length > 200) {
      throw const FormatException('Title required');
    }
    return draft.validatedAttributes();
  }
}
