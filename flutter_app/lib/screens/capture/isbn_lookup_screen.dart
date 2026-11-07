import 'package:curio/features/capture/book_lookup_repository.dart';
import 'package:curio/features/capture/canonical_catalog_repository.dart';
import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live ISBN lookup with explicit user review before private save.
/// Lookup itself never writes or publishes book information.
class IsbnLookupScreen extends StatefulWidget {
  const IsbnLookupScreen({super.key, this.repository, this.templates});
  final BookLookupRepository? repository;
  final TemplateCatalogRepository? templates;

  @override
  State<IsbnLookupScreen> createState() => _IsbnLookupScreenState();
}

class _IsbnLookupScreenState extends State<IsbnLookupScreen> {
  final _isbnController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<GoogleBookCandidate>? _books;
  CaptureReview? _review;
  GoogleBookCandidate? _selectedBook;

  @override
  void dispose() {
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _books = null;
      _review = null;
      _selectedBook = null;
      _error = null;
    });
    try {
      final repository = widget.repository ?? CatalogFirstBookLookupRepository(
        catalog: SupabaseCanonicalCatalogRepository(Supabase.instance.client),
        external: SupabaseBookLookupRepository(Supabase.instance.client),
      );
      final result = await repository.byIsbn(_isbnController.text.trim());
      if (!mounted) return;
      setState(() => _books = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.isbnLookupError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(GoogleBookCandidate candidate) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = widget.templates ??
          SupabaseTemplateCatalogRepository(Supabase.instance.client);
      final templates = await catalog.listStandards();
      final books = templates.where((item) => item.code == 'book');
      if (books.isEmpty) throw StateError('Book template not found');
      final review = CaptureReview(
        template: books.first,
        proposal: candidate.toSuggestion(),
        requiredFields: const {'isbn'},
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _selectedBook = candidate;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.isbnLookupError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.isbnLookupTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.isbnLookupNotice),
              const SizedBox(height: 12),
              TextField(
                controller: _isbnController,
                key: const ValueKey('isbn-input'),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.isbnInputLabel,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
                label: Text(l10n.isbnSearchAction),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              if (_books != null && _books!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.isbnNoResults),
                ),
              if (_books != null)
                ..._books!.map((book) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.book_outlined),
                        title: Text(book.title),
                        subtitle: Text('${book.attributes['author'] ?? l10n.isbnUnknownAuthor} · ${book.source == 'kovunela_catalog' ? l10n.catalogSourceKovunela : l10n.catalogSourceGoogle}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _loading ? null : () => _select(book),
                      ),
                    )),
              if (_review != null) ...[
                const Divider(height: 32),
                Text(l10n.isbnReviewHeading,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_review!.reviewedTitle),
                const SizedBox(height: 12),
                ..._review!.draft.fields.keys.map((key) {
                  final value = _review!.draft.values[key];
                  if (value == null) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(value.toString()),
                  );
                }),
                if (_review!.rejectedReasons.isNotEmpty)
                  Text(l10n.aiRejectedFields(_review!.rejectedReasons.length)),
                const SizedBox(height: 8),
                const Text('Die Daten sind noch nicht gespeichert. Du kannst sie im nächsten Schritt bearbeiten und prüfen.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('isbn-use-book'),
                  onPressed: _loading || _selectedBook == null ? null : () =>
                      context.push('/capture/standard', extra: _selectedBook),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Buchdaten übernehmen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
