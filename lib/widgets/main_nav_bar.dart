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

    // Slightly offset the nav bar from the body background so it's visually distinct,
    // while still transitioning smoothly through the parent ColorScheme.
    final navBackground = isDark
        ? Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.06), theme.colorScheme.surface)
        : Color.alphaBlend(Colors.black.withOpacity(0.04), theme.colorScheme.surface);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex,
      selectedFontSize: 14,
      selectedItemColor: theme.colorScheme.primary,
      unselectedFontSize: 10,
      unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
      onTap: onTap,
      backgroundColor: navBackground,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stash'),
        BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Build'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}