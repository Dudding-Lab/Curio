import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Safe first capture step. The user always reviews content before saving.
class ManualCaptureScreen extends StatefulWidget {
  const ManualCaptureScreen({super.key});

  @override
  State<ManualCaptureScreen> createState() => _ManualCaptureScreenState();
}

class _ManualCaptureScreenState extends State<ManualCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _reviewing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _review() {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _reviewing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draft = ManualItemDraft(
      title: _titleController.text,
      description: _descriptionController.text,
    ).normalized();

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
                        onPressed: () => setState(() => _reviewing = false),
                        child: Text(l10n.editDetails),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.saveUnavailable),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(l10n.saveItem),
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
