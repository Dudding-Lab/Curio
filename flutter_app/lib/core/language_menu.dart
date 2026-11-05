import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'locale_controller.dart';

/// Available on authentication and primary app screens.
/// The user's explicit choice overrides system locale.
class KovunelaLanguageMenu extends ConsumerWidget {
  const KovunelaLanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedLocaleProvider);
    final currentCode = selected == null
        ? 'system'
        : (selected!.countryCode == null
            ? selected.languageCode
            : '${selected.languageCode}_${selected.countryCode}');

    const languages = <String, String>{
      'de': 'Deutsch',
      'en': 'English',
      'fr': 'Français',
      'es': 'Español',
      'it': 'Italiano',
      'pt_BR': 'Português (Brasil)',
    };

    return PopupMenuButton<String>(
      tooltip: l10n.language,
      icon: const Icon(Icons.language),
      initialValue: currentCode,
      onSelected: (code) {
        final locale = code == 'system'
            ? null
            : code == 'pt_BR'
                ? const Locale('pt', 'BR')
                : Locale(code);
        ref.read(selectedLocaleProvider.notifier).select(locale);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'system', child: Text(l10n.useSystemLanguage)),
        for (final entry in languages.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
