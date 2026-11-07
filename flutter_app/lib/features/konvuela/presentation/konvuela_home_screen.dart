import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/konvuela_repository.dart';

final konvuelaRepositoryProvider = Provider<KonvuelaRepository>(
  (ref) => KonvuelaRepository(Supabase.instance.client),
);

final personalCollectionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(konvuelaRepositoryProvider).listCollections(),
);

final personalItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(konvuelaRepositoryProvider).listItems(),
);

class KonvuelaHomeScreen extends ConsumerWidget {
  const KonvuelaHomeScreen({super.key});

  Future<void> _addCollection(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Neue persönliche Sammlung'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Erstellen'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      await ref.read(konvuelaRepositoryProvider).createCollection(name);
      ref.invalidate(personalCollectionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sammlung konnte nicht erstellt werden: $e')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Neues persönliches Objekt'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Titel'),
                ),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Beschreibung (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
      if (save != true || titleController.text.trim().isEmpty) return;
      await ref.read(konvuelaRepositoryProvider).createItem(
        titleController.text,
        description: descriptionController.text,
      );
      ref.invalidate(personalItemsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Objekt konnte nicht erstellt werden: $e')),
        );
      }
    } finally {
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(personalCollectionsProvider);
    final items = ref.watch(personalItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konvuela – Persönlicher Bereich'),
        actions: [
          IconButton(
            tooltip: 'Neues Objekt erfassen',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => _addItem(context, ref),
          ),
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: () {
              ref.invalidate(personalCollectionsProvider);
              ref.invalidate(personalItemsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Meine Sammlungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          collections.when(
            data: (rows) => rows.isEmpty
                ? const ListTile(title: Text('Noch keine persönlichen Sammlungen'))
                : Column(
                    children: rows.map((row) => ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(row['title']?.toString() ?? 'Unbenannt'),
                    )).toList(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(
              title: const Text('Sammlungen konnten nicht geladen werden'),
              subtitle: Text(e.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(personalCollectionsProvider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Meine Objekte', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          items.when(
            data: (rows) => rows.isEmpty
                ? const ListTile(title: Text('Noch keine Objekte'))
                : Column(
                    children: rows.map((row) => ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(row['title']?.toString() ?? 'Unbenannt'),
                      subtitle: Text(row['description']?.toString() ?? ''),
                    )).toList(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(
              title: const Text('Objekte konnten nicht geladen werden'),
              subtitle: Text(e.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(personalItemsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCollection(context, ref),
        label: const Text('Sammlung'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
