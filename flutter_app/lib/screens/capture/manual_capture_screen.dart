import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:curio/features/capture/personal_item_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Review-first capture. Live saving is intentionally disabled by default
/// until real two-account authorization tests have passed.
class ManualCaptureScreen extends StatefulWidget {
  const ManualCaptureScreen({
    super.key,
    this.repository,
    this.enableSave =
        const bool.fromEnvironment('KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE'),
  });

  /// Inject a fake repository in widget tests; production uses Supabase.
  final PersonalItemRepository? repository;
  final bool enableSave;

  @override
  State<ManualCaptureScreen> createState() => _ManualCaptureScreenState();
}

class _ManualCaptureScreenState extends State<ManualCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _reviewing = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  ManualItemDraft get _draft => ManualItemDraft(
        title: _titleController.text,
        description: _descriptionController.text,
      ).normalized();

  void _review() {
    if (_formKey.currentState?.validate() != true) return;
    if (_draft.validate() != null) return;
    setState(() => _reviewing = true);
  }

  Future<void> _save() async {
    if (!widget.enableSave || _saving) return;
    final draft = _draft;
    if (draft.validate() != null) return;

    setState(() => _saving = true);
    try {
      final repository = widget.repository ??
          SupabasePersonalItemRepository(Supabase.instance.client);
      final id = await repository.create(draft);
      if (id.isEmpty) throw StateError('Missing confirmed server item ID');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveCompleted)),
      );
      context.go('/items');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: Text(_reviewing ? l10n.reviewManualItem : l10n.manualCapture),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _reviewing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.reviewManualItem,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        title: Text(l10n.itemTitle),
                        subtitle: Text(draft.title),
                      ),
                      if (draft.description.isNotEmpty)
                        ListTile(
                          title: Text(l10n.itemDescription),
                          subtitle: Text(draft.description),
                        ),
                      const SizedBox(height: 12),
                      Text(l10n.optionalCollectionHint),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _reviewing = false),
                        child: Text(l10n.editDetails),
                      ),
                      if (!widget.enableSave) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l10n.saveUnavailable),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed:
                            widget.enableSave && !_saving ? _save : null,
                        icon: Icon(
                          _saving ? Icons.hourglass_top : Icons.save_outlined,
                        ),
                        label: Text(_saving ? l10n.saveInProgress : l10n.saveItem),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.manualCaptureHint,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _titleController,
                          maxLength: ManualItemDraft.maxTitleLength,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.itemTitle,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? l10n.nameRequired
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: ManualItemDraft.maxDescriptionLength,
                          decoration: InputDecoration(
                            labelText: l10n.itemDescription,
                            hintText: l10n.descriptionPlaceholder,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/capture/standard'),
                          icon: const Icon(Icons.category_outlined),
                          label: const Text('Mit Objektvorlage erfassen'),
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.optionalCollectionHint),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _review,
                          child: Text(l10n.continueToReview),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
