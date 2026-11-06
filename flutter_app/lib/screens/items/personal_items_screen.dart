import 'package:curio/features/capture/personal_item_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only personal item list backed by the authenticated database RPC.
/// Creating items stays gated until the cross-user authorization tests pass.
class PersonalItemsScreen extends StatefulWidget {
  const PersonalItemsScreen({super.key});

  @override
  State<PersonalItemsScreen> createState() => _PersonalItemsScreenState();
}

class _PersonalItemsScreenState extends State<PersonalItemsScreen> {
  late Future<List<PersonalItem>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = SupabasePersonalItemRepository(Supabase.instance.client).list();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myItems),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PersonalItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.itemListLoadError));
          }
          final items = snapshot.data ?? const <PersonalItem>[];
          if (items.isEmpty) {
            return Center(child: Text(l10n.noItemsYet));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.title),
                subtitle: item.description.isEmpty
                    ? null
                    : Text(item.description, maxLines: 2),
              );
            },
          );
        },
      ),
    );
  }
}
