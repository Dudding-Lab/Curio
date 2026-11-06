import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic end-to-end REVIEW DEMO. No photo upload, model call or save.
/// An actual AI adapter will supply CaptureSuggestion later.
class CaptureSuggestionDemoScreen extends StatefulWidget {
  const CaptureSuggestionDemoScreen({super.key, this.repository});
  final TemplateCatalogRepository? repository;

  @override
  State<CaptureSuggestionDemoScreen> createState() =>
      _CaptureSuggestionDemoScreenState();
}

class _CaptureSuggestionDemoScreenState
    extends State<CaptureSuggestionDemoScreen> {
  late Future<List<StandardObjectTemplate>> _templates;
  CaptureReview? _review;
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    _templates = (widget.repository ??
            SupabaseTemplateCatalogRepository(Supabase.instance.client))
        .listStandards();
  }

  static const _demoProposal = CaptureSuggestion(
    templateCode: 'book',
    title: 'Die unendliche Geschichte',
    attributes: {
      'author': 'Michael Ende',
      'isbn': '9783522202602',
      'publisher': 'Thienemann',
      'publication_year': 1979,
      'language': 'de',
      'unknown_from_ocr': 'not stored',
    },
    evidence: {
      'author': 'Demonstration: simulated cover text',
      'isbn': 'Demonstration: simulated barcode',
    },
  );

  void _initialize(StandardObjectTemplate template) {
    setState(() {
      _review = CaptureReview(
        template: template,
        proposal: _demoProposal,
        requiredFields: {'author', 'isbn', 'edition'},
      );
      _validated = false;
    });
  }

  void _check() {
    try {
      _review!.validatedAttributes();
      setState(() => _validated = true);
    } on FormatException {
      setState(() => _validated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.suggestionReviewDemo)),
      body: FutureBuilder<List<StandardObjectTemplate>>(
        future: _templates,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.hasError) {
            return Center(child: Text(l10n.standardTemplatesLoadError));
          }
          final matches = CaptureSuggestionMatcher.rank(
            _demoProposal.attributes,
            snapshot.data!,
          );
          final books = snapshot.data!
              .where((template) => template.code == 'book')
              .toList();
          if (books.isEmpty) {
            return Center(child: Text(l10n.standardTemplatesLoadError));
          }
          final review = _review;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.aiDemoNotice),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.aiMatchedTemplate,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...matches.take(3).map((match) => ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: Text(match.template.title),
                        subtitle: Text(l10n.aiMatchedFields(match.matches)),
                        trailing: match.template.code == 'book'
                            ? const Icon(Icons.check_circle_outline)
                            : null,
                      )),
                  OutlinedButton(
                    onPressed: () => _initialize(books.first),
                    child: Text(l10n.aiReviewBookProposal),
                  ),
                  if (review != null) ...[
                    const Divider(height: 32),
                    Text(l10n.aiReviewFields,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('suggested-title'),
                      initialValue: review.reviewedTitle,
                      decoration: InputDecoration(
                        labelText: l10n.itemTitle,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        review.setTitle(value);
                        setState(() => _validated = false);
                      },
                    ),
                    const SizedBox(height: 12),
                    ...review.draft.fields.entries.map((entry) {
                      final key = entry.key;
                      final value = review.draft.values[key];
                      final required = review.draft.requiredFields.contains(key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          key: ValueKey('suggestion-$key'),
                          initialValue: value?.toString() ?? '',
                          decoration: InputDecoration(
                            labelText: required ? '$key *' : key,
                            border: const OutlineInputBorder(),
                            helperText: review.proposal.evidence[key],
                          ),
                          onChanged: (text) {
                            review.draft.values[key] = text;
                            setState(() => _validated = false);
                          },
                        ),
                      );
                    }),
                    if (review.rejectedReasons.isNotEmpty)
                      Text(l10n.aiRejectedFields(review.rejectedReasons.length)),
                    if (review.missingRequiredFields.isNotEmpty)
                      Text(l10n.aiMissingRequired(
                          review.missingRequiredFields.join(', '))),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _check,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.validateTemplatePreview),
                    ),
                    const SizedBox(height: 12),
                    Text(_validated
                        ? l10n.aiReviewComplete
                        : l10n.aiNeedsReview),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
