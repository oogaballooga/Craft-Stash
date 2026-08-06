import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/pattern_app_bar.dart';
import '../services/theme_controller.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _nickname = "...";

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await Future.delayed(Duration(milliseconds: 500));
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      setState(() {
        _nickname = user?.displayName ?? "NULL displayName";
      });
    } else {
      setState(() {
        _nickname = "NULL user";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = ThemeController();

    return Scaffold(
      appBar: const PatternAppBar(title: 'Account'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Hello, $_nickname!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),

            // Theme toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.light_mode, color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: tc,
                  builder: (context, _) {
                    return Switch(
                      value: tc.isDark,
                      onChanged: (_) => tc.toggle(),
                      activeColor: theme.colorScheme.primary,
                    );
                  },
                ),
                const SizedBox(width: 8),
                Icon(Icons.dark_mode, color: theme.colorScheme.onSurface),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tc.isDark ? 'Dark Mode' : 'Light Mode',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                setState(() {});
              },
              child: const Text("Sign Out"),
            ),
          ],
        ),
      ),
    );
  }
}