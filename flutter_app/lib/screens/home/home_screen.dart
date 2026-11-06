import 'package:curio/core/adaptive_navigation.dart';
import 'package:curio/core/language_menu.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// First responsive landing screen. Manual capture opens a review-only form.
/// Photo and barcode capture are not implemented yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _unavailable(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onDestination(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return;
      case 1:
        context.go('/households');
        return;
      case 2:
        context.push('/capture/manual');
        return;
      default:
        _unavailable(context, l10n.featureNotReady);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return KovunelaAdaptiveScaffold(
      title: l10n.appTitle,
      selectedIndex: 0,
      onDestinationSelected: (index) => _onDestination(context, index),
      actions: const [KovunelaLanguageMenu()],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcome,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.captureIntro),
                const SizedBox(height: 24),
                Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.capturePrompt,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Action(
                              icon: Icons.camera_alt_outlined,
                              label: l10n.takePhoto,
                              onPressed: () => _unavailable(
                                context,
                                l10n.captureNotReady,
                              ),
                            ),
                            _Action(
                              icon: Icons.qr_code_scanner,
                              label: l10n.scanBarcode,
                              onPressed: () => _unavailable(
                                context,
                                l10n.captureNotReady,
                              ),
                            ),
                            _Action(
                              icon: Icons.edit_note_outlined,
                              label: l10n.enterManually,
                              onPressed: () => context.push('/capture/manual'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.mySpaces,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(l10n.myItems),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/items'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.collections_bookmark_outlined),
                    title: Text(l10n.personalCollections),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/collections/personal'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(l10n.myObjectTypes),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/object-types'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_motion_outlined),
                    title: Text(l10n.standardTemplates),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/templates/standard'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text(l10n.manageHouseholds),
                    subtitle: Text(l10n.yourCollections),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/households'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
