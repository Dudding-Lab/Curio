import 'package:flutter/material.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/core/language_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

final collectionsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, householdId) async {
  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('collections')
      .select()
      .eq('household_id', householdId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

class CollectionsListScreen extends ConsumerWidget {
  final String householdId;
  final String? householdName;

  const CollectionsListScreen({
    super.key,
    required this.householdId,
    this.householdName,
  });

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newCollection),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.collectionName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await Supabase.instance.client.from('collections').insert({
          'household_id': householdId,
          'name': result,
          'created_by': Supabase.instance.client.auth.currentUser!.id,
        });
        ref.invalidate(collectionsProvider(householdId));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionsAsync = ref.watch(collectionsProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: Text(householdName ?? l10n.collections),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Text(l10n.noCollections),
            );
          }
          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return ListTile(
                title: Text(collection['name'] as String? ?? l10n.untitled),
                subtitle: Text(collection['description'] as String? ?? ''),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.collectionSelected)),
                  );
                  // TODO: Navigation zu Items der Sammlung
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorOccurred),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(collectionsProvider(householdId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createCollection(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
