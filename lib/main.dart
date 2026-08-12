/*
 * This file is the main entry point for the app
 * This file is responsible for initializing the app and setting up the main navigation bar
 * It is the root of the widget tree
 * All pages are attached to this root and displayed when necessary
*/

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/navBarScreens.dart';
import 'widgets/main_nav_bar.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeController().init();
  runApp(Main(key: Main.stateKey));
}

class Main extends StatefulWidget {
  const Main({super.key});

  static final GlobalKey<MainState> stateKey = GlobalKey<MainState>();

  /// Switches the bottom nav to the Profile tab from any child widget.
  static void switchToProfile() {
    stateKey.currentState?._switchToTab(3);
  }

  @override
  MainState createState() => MainState();
}

class MainState extends State<Main> {
  int _selectedIndex = 1;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Calendar tab
    GlobalKey<NavigatorState>(), // Stash tab
    GlobalKey<NavigatorState>(), // Build tab
    GlobalKey<NavigatorState>(), // Profile tab
  ];

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();

    final User? currentUser = FirebaseAuth.instance.currentUser;
    _pages = [
      const CalendarPage(),
      const FabricStashPage(),
      const BuildPage(),
      currentUser == null ? const LoginPage() : const AccountPage(),
    ];

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _pages = [
          const CalendarPage(),
          const FabricStashPage(),
          const BuildPage(),
          user == null ? const LoginPage() : const AccountPage(),
        ];
      });
    });
  }

  void _switchToTab(int index) {
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _onTabSelected(int index) {
    _switchToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController(),
      builder: (context, _) {
        final tc = ThemeController();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 69, 148, 214),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 69, 148, 214),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 69, 148, 214),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 69, 148, 214),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          themeMode: tc.mode,
          home: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: List.generate(
                _pages.length,
                (index) => Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      builder: (context) => _pages[index],
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: MainNavBar(
              enabled: true,
              selectedIndex: _selectedIndex,
              onTap: _onTabSelected,
            ),
          ),
        );
      },
    );
  }
}