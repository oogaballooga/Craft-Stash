import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:craft_stash/screens/create_account_page.dart';
import 'package:craft_stash/widgets/pattern_app_bar.dart';
import 'package:craft_stash/services/theme_controller.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _resetTimer;

  void rebuild(int i) {
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(seconds: i), () {
      setState(() {
        _formKey.currentState?.reset();
      });
    });
    setState(() {});
  }

  Future<void> _logIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCred.user;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logged in as: ${user.displayName ?? user.email}")),
        );
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Login failed. Please check your credentials.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: const PatternAppBar(title: 'Login'),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: h,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Theme toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.light_mode, color: Theme.of(context).colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  ListenableBuilder(
                                    listenable: ThemeController(),
                                    builder: (context, _) {
                                      return Switch(
                                        value: ThemeController().isDark,
                                        onChanged: (_) => ThemeController().toggle(),
                                        activeColor: Theme.of(context).colorScheme.primary,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onSurface),
                                ],
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.email),
                                ),
                                autofillHints: [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    rebuild(5);
                                    return 'Please enter your email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock),
                                ),
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (value) {
                                  if (_formKey.currentState!.validate()) {
                                    _logIn();
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    rebuild(5);
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: _logIn,
                                      child: const Text('Login'),
                                    ),
                              const SizedBox(height: 24),
                              Text("Don't have an account?\nCreate an account below", textAlign: TextAlign.center),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  FocusScope.of(context).requestFocus(FocusNode());
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CreateAccountPage()),
                                  );
                                },
                                child: const Text("Create Account"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}