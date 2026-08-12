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

  // ── Button pill styling ──────────────────────────────────────────
  static const _btnBg = Color.fromARGB(128, 0, 0, 0); // 50 % black
  static const _pillRadius = 10.0;                        // corner roundness
  static const _pillPadding = 0.0;                       // shrinks the pill around the icon
  static const _pillMargin = 3.0;                        // gap between adjacent pills

  /// Wraps a widget (icon button, etc.) in a dark rounded container for contrast.
  Widget _wrapWithBackground(Widget w) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _pillMargin),
      decoration: BoxDecoration(
        color: _btnBg,
        borderRadius: BorderRadius.circular(_pillRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(_pillPadding),
        child: w,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap every action in the dark pill background
    final styledActions = actions?.map(_wrapWithBackground).toList();

    // Also wrap the leading widget (back button / filter) if present
    final styledLeading = leading != null ? _wrapWithBackground(leading!) : null;

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
      leading: styledLeading,
      actions: styledActions,
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