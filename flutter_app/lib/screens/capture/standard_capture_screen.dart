import 'package:curio/features/capture/standard_item_capture_repository.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data-driven capture using the published, versioned standard field schemas.
/// Personal details stay in the user's private workspace; the server stages
/// eligible book facts for internal catalog review without a second consent.
class StandardCaptureScreen extends StatefulWidget {
  const StandardCaptureScreen({
    super.key,
    this.repository,
    this.enableSave =
        const bool.fromEnvironment('KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE'),
  });
  final StandardItemCaptureRepository? repository;
  final bool enableSave;

  @override
  State<StandardCaptureScreen> createState() => _StandardCaptureScreenState();
}

class _StandardCaptureScreenState extends State<StandardCaptureScreen> {
  late final StandardItemCaptureRepository _repository;
  late final Future<List<StandardObjectTemplate>> _standards;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final Map<String, TextEditingController> _fields = {};
  final Map<String, bool> _booleans = {};
  StandardObjectTemplate? _selected;
  bool _review = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseStandardItemCaptureRepository(Supabase.instance.client);
    _standards = _repository.listStandards();
  }

  void _select(StandardObjectTemplate template) {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _fields.clear();
    _booleans.clear();
    for (final field in template.fields.entries) {
      if (field.value == 'boolean') {
        _booleans[field.key] = false;
      } else {
        _fields[field.key] = TextEditingController();
      }
    }
    setState(() {
      _selected = template;
      _review = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String labelFor(String key) {
    const labels = {
      'isbn': 'ISBN', 'author': 'Autor/in', 'publisher': 'Verlag',
      'publication_year': 'Erscheinungsjahr', 'language': 'Sprache (z. B. de)',
      'edition': 'Ausgabe', 'manufacturer': 'Hersteller',
      'model': 'Modell', 'serial_number': 'Seriennummer',
      'purchase_date': 'Kaufdatum (JJJJ-MM-TT)', 'working': 'Funktionsfähig',
      'director': 'Regie', 'artist': 'Interpret/in',
      'album': 'Album', 'platform': 'Plattform', 'format': 'Format',
      'release_year': 'Erscheinungsjahr', 'species': 'Art',
      'location': 'Standort', 'acquired_on': 'Anschaffungsdatum (JJJJ-MM-TT)',
      'watering_notes': 'Pflegehinweise',
    };
    return labels[key] ?? key.replaceAll('_', ' ');
  }

  static bool validIsbn(String raw) {
    final value = raw.replaceAll(RegExp(r'[ -]'), '').toUpperCase();
    if (RegExp(r'^\\d{13}$').hasMatch(value)) {
      var sum = 0;
      for (var i = 0; i < 13; i++) {
        sum += int.parse(value[i]) * (i.isEven ? 1 : 3);
      }
      return sum % 10 == 0 &&
          (value.startsWith('978') || value.startsWith('979'));
    }
    if (!RegExp(r'^\\d{9}[\\dX]$').hasMatch(value)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (value[i] == 'X' ? 10 : int.parse(value[i])) * (10 - i);
    }
    return sum % 11 == 0;
  }

  Map<String, dynamic> _attributes() {
    final selected = _selected;
    if (selected == null) throw const FormatException('Vorlage auswählen');
    final result = <String, dynamic>{};
    for (final field in selected.fields.entries) {
      if (field.value == 'boolean') {
        result[field.key] = _booleans[field.key] ?? false;
        continue;
      }
      final raw = _fields[field.key]!.text.trim();
      if (raw.isEmpty) continue;
      if (field.key == 'isbn' && !validIsbn(raw)) {
        throw const FormatException('Die ISBN hat eine ungültige Prüfziffer.');
      }
      if (field.value == 'number') {
        final number = num.tryParse(raw.replaceAll(',', '.'));
        if (number == null || !number.isFinite) {
          throw FormatException('Ungültige Zahl: ${labelFor(field.key)}');
        }
        result[field.key] = number;
      } else if (field.value == 'date') {
        final date = DateTime.tryParse(raw);
        if (!RegExp(r'^\\d{4}-\\d{2}-\\d{2}$').hasMatch(raw) || date == null ||
            date.toIso8601String().substring(0, 10) != raw) {
          throw FormatException('Ungültiges Datum: ${labelFor(field.key)}');
        }
        result[field.key] = raw;
      } else {
        result[field.key] = raw;
      }
    }
    return result;
  }

  void _check() {
    if (_selected == null) {
      setState(() => _error = 'Bitte eine Objektvorlage auswählen.');
      return;
    }
    if (_title.text.trim().isEmpty || _title.text.trim().length > 200) {
      setState(() => _error = 'Bitte einen Titel (maximal 200 Zeichen) eingeben.');
      return;
    }
    if (_description.text.trim().length > 5000) {
      setState(() => _error = 'Die Beschreibung ist zu lang.');
      return;
    }
    try {
      _attributes();
      setState(() {
        _error = null;
        _review = true;
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    if (_saving || !widget.enableSave || _selected == null) return;
    setState(() => _saving = true);
    try {
      final id = await _repository.create(
        standardCode: _selected!.code,
        title: _title.text,
        description: _description.text,
        attributes: _attributes(),
      );
      if (id.isEmpty) throw StateError('Missing saved object');
      if (!mounted) return;
      context.go('/items');
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Speichern fehlgeschlagen. Die Eingaben bleiben erhalten.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Gegenstand mit Vorlage erfassen')),
      body: FutureBuilder<List<StandardObjectTemplate>>(
        future: _standards,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return const Center(child: Text('Vorlagen konnten nicht geladen werden.'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final standards = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (!_review) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('standard-selection'),
                      isExpanded: true,
                      initialValue: _selected?.code,
                      decoration: const InputDecoration(
                          labelText: 'Objektart', border: OutlineInputBorder()),
                      items: standards.map((t) =>
                          DropdownMenuItem(value: t.code, child: Text(t.title))).toList(),
                      onChanged: _saving ? null : (code) {
                        for (final t in standards) {
                          if (t.code == code) {
                            _select(t);
                            break;
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      key: const ValueKey('standard-title'),
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: l10n.itemTitle, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      key: const ValueKey('standard-description'),
                      maxLines: 3,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        labelText: l10n.itemDescription, border: const OutlineInputBorder()),
                    ),
                    if (_selected != null) ...[
                      ..._selected!.fields.entries.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: field.value == 'boolean'
                            ? SwitchListTile(
                                key: ValueKey('field-${field.key}'),
                                title: Text(labelFor(field.key)),
                                value: _booleans[field.key] ?? false,
                                onChanged: (value) =>
                                    setState(() => _booleans[field.key] = value),
                              )
                            : TextField(
                                key: ValueKey('field-${field.key}'),
                                controller: _fields[field.key],
                                keyboardType: field.value == 'number'
                                    ? const TextInputType.numberWithOptions(decimal: true)
                                    : TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: labelFor(field.key),
                                  border: const OutlineInputBorder(),
                                  helperText: field.key == 'isbn'
                                      ? 'Gültige ISBN-10 oder ISBN-13'
                                      : null,
                                ),
                              ),
                      )),
                    ],
                    FilledButton(
                      onPressed: _saving ? null : _check,
                      child: Text(l10n.continueToReview),
                    ),
                  ] else ...[
                    Text(l10n.reviewManualItem,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    ListTile(title: Text('Objektart'),
                        subtitle: Text(_selected!.title)),
                    ListTile(title: Text(l10n.itemTitle),
                        subtitle: Text(_title.text.trim())),
                    if (_description.text.trim().isNotEmpty)
                      ListTile(title: Text(l10n.itemDescription),
                          subtitle: Text(_description.text.trim())),
                    ..._attributes().entries.map((entry) =>
                        ListTile(title: Text(labelFor(entry.key)),
                            subtitle: Text(entry.value.toString()))),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _saving ? null : () => setState(() {
                        _review = false;
                        _error = null;
                      }),
                      child: Text(l10n.editDetails),
                    ),
                    if (!widget.enableSave)
                      Padding(padding: const EdgeInsets.all(12),
                          child: Text(l10n.saveUnavailable)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.enableSave && !_saving ? _save : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? l10n.saveInProgress : l10n.saveItem),
                    ),
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
