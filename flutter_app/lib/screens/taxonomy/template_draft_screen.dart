import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/features/taxonomy/template_draft.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interactive LOCAL draft editor and dynamic item-form preview.
/// No mutation RPC is used; drafts are not persisted.
class TemplateDraftScreen extends StatefulWidget {
  const TemplateDraftScreen({
    super.key,
    required this.standardCode,
    this.repository,
    this.initialTemplate,
  });

  final String standardCode;
  final TemplateCatalogRepository? repository;
  final StandardObjectTemplate? initialTemplate;

  @override
  State<TemplateDraftScreen> createState() => _TemplateDraftScreenState();
}

class _TemplateDraftScreenState extends State<TemplateDraftScreen> {
  late Future<StandardObjectTemplate> _template;
  TemplateDraft? _draft;
  final _keyController = TextEditingController();
  final _titleController = TextEditingController();
  String _newFieldType = 'text';
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _template = _getTemplate();
  }

  Future<StandardObjectTemplate> _getTemplate() async {
    if (widget.initialTemplate != null) return widget.initialTemplate!;
    final repo = widget.repository ??
        SupabaseTemplateCatalogRepository(Supabase.instance.client);
    final all = await repo.listStandards();
    return all.firstWhere((entry) => entry.code == widget.standardCode);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addField(AppLocalizations l10n, TemplateDraft draft) {
    final key = _keyController.text.trim();
    final error = draft.addField(key, _newFieldType);
    if (error != null) {
      _showError(l10n.invalidTemplateField);
      return;
    }
    _keyController.clear();
    setState(() {});
  }

  Widget _editor(AppLocalizations l10n, TemplateDraft draft) {
    final fieldKeys = draft.fields.keys.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.templateDraftOnly,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.templateVariantTitle,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.templateFields,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...fieldKeys.map((key) {
          final isCustom = draft.addedFields.containsKey(key);
          return Card(
            key: ValueKey('field-$key'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('$key · ${draft.fields[key]}',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      if (isCustom)
                        IconButton(
                          tooltip: l10n.removeTemplateField,
                          onPressed: () =>
                              setState(() => draft.removeAddedField(key)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  if (draft.fields[key] == 'text')
                    DropdownButtonFormField<String>(
                      key: ValueKey('translation-$key'),
                      initialValue: draft.translationModeFor(key),
                      decoration: InputDecoration(
                        labelText: l10n.templateContentLanguagePolicy,
                        helperText: l10n.templateContentLanguageHint,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'original',
                          child: Text(l10n.keepOriginalText),
                        ),
                        DropdownMenuItem(
                          value: 'translate',
                          child: Text(l10n.translateTextByAppLanguage),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          setState(() => draft.setTranslationMode(key, mode));
                        }
                      },
                    ),
                  TextFormField(
                    key: ValueKey('label-$key'),
                    initialValue: draft.fieldLabels[key] ?? '',
                    decoration: InputDecoration(
                      labelText: l10n.templateFieldLabel,
                    ),
                    onChanged: (value) => draft.fieldLabels[key] = value,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.templateFieldHidden),
                          value: draft.hiddenFields.contains(key),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              draft.hiddenFields.add(key);
                            } else {
                              draft.hiddenFields.remove(key);
                            }
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          key: ValueKey('order-$key'),
                          initialValue: draft.fieldOrder[key]?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.templateFieldOrder,
                          ),
                          onChanged: (value) {
                            final n = int.tryParse(value);
                            if (n != null && n >= 0 && n <= 999) {
                              draft.fieldOrder[key] = n;
                            } else {
                              draft.fieldOrder.remove(key);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(l10n.addTemplateField,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('new-field-key'),
          controller: _keyController,
          decoration: InputDecoration(
            labelText: l10n.templateFieldKey,
            border: const OutlineInputBorder(),
            helperText: l10n.templateFieldKeyHint,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('new-field-type'),
          initialValue: _newFieldType,
          decoration: InputDecoration(labelText: l10n.templateFieldType),
          items: TemplateDraft.supportedTypes
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) =>
              setState(() => _newFieldType = value ?? 'text'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _addField(l10n, draft),
          icon: const Icon(Icons.add),
          label: Text(l10n.addTemplateField),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => setState(() => _preview = true),
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l10n.previewTemplateForm),
        ),
      ],
    );
  }

  Widget _previewForm(AppLocalizations l10n, TemplateDraft draft) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.templateDraftOnly),
        const SizedBox(height: 12),
        ...draft.visibleFieldKeys.map((key) {
          final label = draft.labelFor(key);
          switch (draft.fields[key]) {
            case 'boolean':
              return SwitchListTile(
                key: ValueKey('value-$key'),
                title: Text(label),
                value: draft.values[key] == true,
                onChanged: (value) =>
                    setState(() => draft.values[key] = value),
              );
            case 'date':
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('value-$key'),
                  initialValue: draft.values[key]?.toString() ?? '',
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD',
                  ),
                  onChanged: (value) => draft.values[key] = value,
                ),
              );
            case 'number':
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('value-$key'),
                  initialValue: draft.values[key]?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => draft.values[key] = value,
                ),
              );
            default:
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('value-$key'),
                  initialValue: draft.values[key]?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => draft.values[key] = value,
                ),
              );
          }
        }),
        OutlinedButton.icon(
          onPressed: () {
            try {
              final attributes = draft.validatedAttributes();
              _showError(l10n.templatePreviewValid(attributes.length));
            } on FormatException {
              _showError(l10n.templatePreviewInvalid);
            }
          },
          icon: const Icon(Icons.rule),
          label: Text(l10n.validateTemplatePreview),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _preview = false),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.editDetails),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<StandardObjectTemplate>(
      future: _template,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.templateVariantTitle)),
            body: Center(child: Text(l10n.standardTemplatesLoadError)),
          );
        }
        final template = snapshot.data!;
        final draft = _draft ??= TemplateDraft(
          standardCode: template.code,
          standardFields: template.fields,
        );
        if (_titleController.text.isEmpty) {
          _titleController.text = template.title;
        }
        return Scaffold(
          appBar: AppBar(title: Text(template.title)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _preview
                  ? _previewForm(l10n, draft)
                  : _editor(l10n, draft),
            ),
          ),
        );
      },
    );
  }
}
