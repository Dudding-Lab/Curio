import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public-to-authenticated, read-only catalog; creating personal derivatives
/// is intentionally not wired into the UI before two-user authorization tests.
class StandardTemplatesScreen extends StatefulWidget {
  const StandardTemplatesScreen({super.key, this.repository});

  final TemplateCatalogRepository? repository;

  @override
  State<StandardTemplatesScreen> createState() =>
      _StandardTemplatesScreenState();
}

class _StandardTemplatesScreenState extends State<StandardTemplatesScreen> {
  late Future<List<StandardObjectTemplate>> _templates;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = widget.repository ??
        SupabaseTemplateCatalogRepository(Supabase.instance.client);
    _templates = repository.listStandards();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.standardTemplates),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<StandardObjectTemplate>>(
        future: _templates,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.standardTemplatesLoadError));
          }
          final templates = snapshot.data ?? const <StandardObjectTemplate>[];
          if (templates.isEmpty) {
            return Center(child: Text(l10n.noStandardTemplates));
          }
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                leading: const Icon(Icons.auto_awesome_motion_outlined),
                title: Text(template.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/templates/standard/${Uri.encodeComponent(template.code)}/draft'),
                subtitle: Text(
                  l10n.objectTypeFieldCount(template.fields.length),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
