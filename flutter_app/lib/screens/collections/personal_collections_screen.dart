import 'package:curio/features/collections/personal_collection_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only view until cross-user authorization integration tests pass.
class PersonalCollectionsScreen extends StatefulWidget {
  const PersonalCollectionsScreen({
    super.key,
    this.repository,
  });

  final PersonalCollectionRepository? repository;

  @override
  State<PersonalCollectionsScreen> createState() =>
      _PersonalCollectionsScreenState();
}

class _PersonalCollectionsScreenState extends State<PersonalCollectionsScreen> {
  late Future<List<PersonalCollection>> _collections;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _collections = (widget.repository ??
            SupabasePersonalCollectionRepository(Supabase.instance.client))
        .list();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.personalCollections),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PersonalCollection>>(
        future: _collections,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.personalCollectionsLoadError));
          }
          final collections = snapshot.data ?? const <PersonalCollection>[];
          if (collections.isEmpty) {
            return Center(child: Text(l10n.noPersonalCollectionsYet));
          }
          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return ListTile(
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: Text(collection.title),
                subtitle: collection.description.isEmpty
                    ? null
                    : Text(collection.description, maxLines: 2),
              );
            },
          );
        },
      ),
    );
  }
}
