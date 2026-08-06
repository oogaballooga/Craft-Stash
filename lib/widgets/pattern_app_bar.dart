import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable AppBar with the blue plaid fabric pattern background.
/// Works in both light and dark themes.
class PatternAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const PatternAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light, // white status bar icons always
      centerTitle: centerTitle,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      foregroundColor: Colors.white,
      leading: leading,
      actions: actions,
      flexibleSpace: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/icon/blue_plaid_pattern.png',
              fit: BoxFit.cover,
              repeat: ImageRepeat.repeat,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}