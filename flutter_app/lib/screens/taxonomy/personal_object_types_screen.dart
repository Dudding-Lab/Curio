import 'package:curio/features/taxonomy/personal_taxonomy_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Personal templates and categories. Editing will be enabled only after the
/// real multi-account authorization test suite passes.
class PersonalObjectTypesScreen extends StatefulWidget {
  const PersonalObjectTypesScreen({super.key, this.repository});

  final PersonalTaxonomyRepository? repository;

  @override
  State<PersonalObjectTypesScreen> createState() =>
      _PersonalObjectTypesScreenState();
}

class _PersonalObjectTypesScreenState extends State<PersonalObjectTypesScreen> {
  late Future<List<PersonalObjectType>> _types;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = widget.repository ??
        SupabasePersonalTaxonomyRepository(Supabase.instance.client);
    _types = repo.listObjectTypes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myObjectTypes),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PersonalObjectType>>(
        future: _types,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.objectTypesLoadError));
          }
          final types = snapshot.data ?? const <PersonalObjectType>[];
          if (types.isEmpty) {
            return Center(child: Text(l10n.noObjectTypesYet));
          }
          return ListView.builder(
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              return ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(type.title),
                subtitle: Text(l10n.objectTypeFieldCount(type.fields.length)),
              );
            },
          );
        },
      ),
    );
  }
}
