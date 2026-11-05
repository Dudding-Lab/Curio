import 'package:flutter/material.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'design_tokens.dart';

/// Reusable adaptive navigation; opt-in while legacy routes are migrated.
class KovunelaAdaptiveScaffold extends StatelessWidget {
  const KovunelaAdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.actions,
  }) : assert(selectedIndex >= 0 && selectedIndex < 5);

  final String title;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final compact = KovunelaBreakpoints.isCompact(width);
    final labels = [
      l10n.home,
      l10n.collections,
      l10n.capture,
      l10n.locations,
      l10n.search,
    ];
    const icons = <IconData>[
      Icons.home_outlined,
      Icons.collections_bookmark_outlined,
      Icons.add_circle_outline,
      Icons.place_outlined,
      Icons.search,
    ];

    final content = SafeArea(child: body);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: compact
          ? content
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: KovunelaBreakpoints.isExpanded(width)
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.selected,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(
                    icon: Icon(icons[i]),
                    label: labels[i],
                  ),
              ],
            )
          : null,
    );
  }
}
