import 'package:flutter/material.dart';

class MainNavBar extends StatelessWidget {
  final bool enabled;
  final int selectedIndex;
  final Function(int) onTap;

  const MainNavBar({
    super.key,
    required this.enabled,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex,
      selectedFontSize: 14,
      selectedItemColor: theme.colorScheme.primary,
      unselectedFontSize: 10,
      unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
      onTap: onTap,
      backgroundColor: isDark ? theme.colorScheme.surface : const Color.fromARGB(255, 245, 240, 250),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stash'),
        BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Build'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}