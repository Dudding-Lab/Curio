/// A text translation is an optional display variant, never an overwrite.
/// The source snapshot prevents displaying stale translations after an edit.
class LocalizedText {
  const LocalizedText({
    required this.original,
    required this.sourceLanguage,
    this.variants = const {},
  });

  final String original;
  final String sourceLanguage;
  final Map<String, TranslationVariant> variants;

  /// Language switching never sends a translation request by itself.
  /// If the translation is absent or stale, display the source verbatim.
  String display({required String language, required bool translate}) {
    if (!translate || language.toLowerCase() == sourceLanguage.toLowerCase()) {
      return original;
    }
    final exact = variants[language];
    final baseLanguage = language.split('-').first;
    final variant = exact ?? variants[baseLanguage];
    if (variant == null || variant.sourceText != original) return original;
    return variant.text;
  }
}

class TranslationVariant {
  const TranslationVariant({
    required this.text,
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.provider = 'manual',
  });

  final String text;
  final String sourceText;
  final String sourceLanguage;
  final String targetLanguage;
  final String provider;
}
