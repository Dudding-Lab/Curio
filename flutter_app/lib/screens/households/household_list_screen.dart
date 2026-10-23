import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('Haushaltsliste – Implementierung folgt'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Create household dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
