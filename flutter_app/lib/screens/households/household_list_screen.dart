import 'package:flutter/material.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/core/language_menu.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newHousehold),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.householdName),
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
        await Supabase.instance.client.from('households').insert({
          'name': result,
          'created_by': Supabase.instance.client.auth.currentUser!.id,
        });
        ref.invalidate(householdsProvider);
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
    final householdsAsync = ref.watch(householdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.households),
        actions: [
          const KovunelaLanguageMenu(),
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(householdsProvider),
          ),
        ],
      ),
      body: householdsAsync.when(
        data: (households) {
          if (households.isEmpty) {
            return Center(
              child: Text(l10n.noHouseholds),
            );
          }
          return ListView.builder(
            itemCount: households.length,
            itemBuilder: (context, index) {
              final household = households[index];
              return ListTile(
                title: Text(household['name'] as String? ?? l10n.untitled),
                subtitle: Text('${l10n.created}: ${household['created_at'] ?? ''}'),
                onTap: () {
                  final name = household['name'] as String? ?? l10n.households;
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
              Text(l10n.errorOccurred),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(householdsProvider),
                child: Text(l10n.retry),
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
