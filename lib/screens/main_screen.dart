import 'package:flutter/material.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/screens/sets/sets_screen.dart';
import 'package:flash_me/screens/cards/my_cards_screen.dart';
import 'package:flash_me/screens/study/study_screen.dart';
import 'package:flash_me/screens/templates/templates_screen.dart';
import 'package:flash_me/screens/profile_screen.dart';

// Root shell — owns the BottomNavigationBar and switches between the five tabs.
// IndexedStack keeps each tab's widget tree alive so scroll positions and state
// are preserved when the user switches tabs.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack + AnimatedOpacity preserves each tab's state (equivalent to
      // IndexedStack) while crossfading between them on tab switch.
      body: Stack(
        fit: StackFit.expand,
        children: List.generate(_tabs.length, (i) => AnimatedOpacity(
          opacity: i == _selectedIndex ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: i != _selectedIndex,
            child: _tabs[i],
          ),
        )),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        // fixed type required to show labels for 4+ items
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.library_books_outlined),
            activeIcon: const Icon(Icons.library_books),
            label: context.l10n.navSets,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.style_outlined),
            activeIcon: const Icon(Icons.style),
            label: context.l10n.navCards,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.school_outlined),
            activeIcon: const Icon(Icons.school),
            label: context.l10n.navStudy,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.copy_all_outlined),
            activeIcon: const Icon(Icons.copy_all),
            label: context.l10n.navTemplates,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_circle_outlined),
            activeIcon: const Icon(Icons.account_circle),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
