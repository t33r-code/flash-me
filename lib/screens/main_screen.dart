import 'package:flutter/material.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/layout_breakpoints.dart';
import 'package:flash_me/screens/sets/sets_screen.dart';
import 'package:flash_me/screens/cards/my_cards_screen.dart';
import 'package:flash_me/screens/study/study_screen.dart';
import 'package:flash_me/screens/templates/templates_screen.dart';
import 'package:flash_me/screens/profile_screen.dart';

// One top-level destination, rendered as both a bottom-nav item (narrow) and a
// navigation-rail destination (wide) so the two stay in sync.
class _Destination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Destination(this.icon, this.activeIcon, this.label);
}

// Bottom-pinned Profile control for the wide navigation rail. Kept out of the
// NavigationRail's destinations so it can sit at the bottom; mirrors the rail's
// icon-over-label look and tints to the primary colour when active.
class _RailProfileButton extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  const _RailProfileButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? destination.activeIcon : destination.icon,
                  color: color),
              const SizedBox(height: 4),
              Text(destination.label,
                  style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// Root shell — switches between the five tabs and adapts its navigation chrome:
// a left NavigationRail on wide/landscape layouts, a BottomNavigationBar on
// narrow ones (breakpoint from layout_breakpoints.dart). The opacity Stack keeps
// each tab's widget tree alive so scroll positions and state survive tab switches
// and breakpoint crossings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = [
    SetsScreen(),
    MyCardsScreen(),
    StudyScreen(),     // centre tab — the core use case
    TemplatesScreen(),
    ProfileScreen(),
  ];

  void _onSelect(int i) => setState(() => _selectedIndex = i);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      _Destination(
          Icons.library_books_outlined, Icons.library_books, l10n.navSets),
      _Destination(Icons.style_outlined, Icons.style, l10n.navCards),
      _Destination(Icons.school_outlined, Icons.school, l10n.navStudy),
      _Destination(Icons.copy_all_outlined, Icons.copy_all, l10n.navTemplates),
      _Destination(Icons.account_circle_outlined, Icons.account_circle,
          l10n.navProfile),
    ];

    // Keeps every tab alive; only the selected one is visible and interactive.
    final content = Stack(
      fit: StackFit.expand,
      children: List.generate(
        _tabs.length,
        (i) => AnimatedOpacity(
          opacity: i == _selectedIndex ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: i != _selectedIndex,
            child: _tabs[i],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide/landscape: a persistent left navigation rail beside the content.
        // Profile (the last destination) is pinned to the bottom of the rail —
        // a common desktop pattern — so it sits apart from the main destinations.
        if (isWideWidth(constraints.maxWidth)) {
          final profileIndex = _tabs.length - 1;
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      // Breathing room from the top edge, mirroring the space
                      // below the pinned Profile control.
                      const SizedBox(height: 8),
                      Expanded(
                        child: NavigationRail(
                          // null when Profile is active — its destination isn't
                          // in this rail (it's the bottom control below).
                          selectedIndex: _selectedIndex < profileIndex
                              ? _selectedIndex
                              : null,
                          onDestinationSelected: _onSelect,
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final d
                                in destinations.sublist(0, profileIndex))
                              NavigationRailDestination(
                                icon: Icon(d.icon),
                                selectedIcon: Icon(d.activeIcon),
                                label: Text(d.label),
                              ),
                          ],
                        ),
                      ),
                      _RailProfileButton(
                        destination: destinations[profileIndex],
                        selected: _selectedIndex == profileIndex,
                        onTap: () => _onSelect(profileIndex),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: content),
              ],
            ),
          );
        }

        // Narrow/portrait: the original bottom navigation bar.
        return Scaffold(
          body: content,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onSelect,
            // fixed type required to show labels for 4+ items
            type: BottomNavigationBarType.fixed,
            items: [
              for (final d in destinations)
                BottomNavigationBarItem(
                  icon: Icon(d.icon),
                  activeIcon: Icon(d.activeIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
