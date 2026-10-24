import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

final householdsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('households')
      .select()
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  Future<void> _createHousehold(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neuen Haushalt anlegen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name des Haushalts'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await Supabase.instance.client.from('households').insert({
          'name': result,
          'created_by': Supabase.instance.client.auth.currentUser!.id,
        });
        ref.invalidate(householdsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(householdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(householdsProvider),
          ),
        ],
      ),
      body: householdsAsync.when(
        data: (households) {
          if (households.isEmpty) {
            return const Center(
              child: Text('Noch keine Haushalte vorhanden.\nLegen Sie den ersten an.'),
            );
          }
          return ListView.builder(
            itemCount: households.length,
            itemBuilder: (context, index) {
              final household = households[index];
              return ListTile(
                title: Text(household['name'] as String? ?? 'Unbenannt'),
                subtitle: Text('Erstellt: ${household['created_at'] ?? ''}'),
                onTap: () {
                  final name = household['name'] as String? ?? 'Haushalt';
                  context.push('/households/${household['id']}/collections?name=${Uri.encodeComponent(name)}');
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
              Text('Fehler: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(householdsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createHousehold(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
