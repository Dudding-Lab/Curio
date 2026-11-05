import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Shared navigation chrome for forthcoming Kovunela features.
///
/// This is an opt-in widget; legacy screens can migrate incrementally.
/// It never assumes that the current user has a workspace or items.
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

  static const destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Start'),
    NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), label: 'Sammlungen'),
    NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Erfassen'),
    NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Orte'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Suche'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = KovunelaBreakpoints.isCompact(width);

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
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Start')),
                    NavigationRailDestination(icon: Icon(Icons.collections_bookmark_outlined), label: Text('Sammlungen')),
                    NavigationRailDestination(icon: Icon(Icons.add_circle_outline), label: Text('Erfassen')),
                    NavigationRailDestination(icon: Icon(Icons.place_outlined), label: Text('Orte')),
                    NavigationRailDestination(icon: Icon(Icons.search), label: Text('Suche')),
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
              destinations: destinations,
            )
          : null,
    );
  }
}
