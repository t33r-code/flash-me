import 'package:flutter/material.dart';
import 'package:flash_me/screens/sets/my_sets_screen.dart';
import 'package:flash_me/screens/cards/my_cards_screen.dart';
import 'package:flash_me/screens/templates/templates_screen.dart';
import 'package:flash_me/screens/profile_screen.dart';

// Root shell — owns the BottomNavigationBar and switches between the four tabs.
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
    MySetsScreen(),
    MyCardsScreen(),
    TemplatesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        // fixed type required to show labels for 4+ items
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_outlined),
            activeIcon: Icon(Icons.library_books),
            label: 'Sets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style_outlined),
            activeIcon: Icon(Icons.style),
            label: 'Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.copy_all_outlined),
            activeIcon: Icon(Icons.copy_all),
            label: 'Templates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
