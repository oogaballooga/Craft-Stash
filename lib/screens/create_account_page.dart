import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:craft_stash/widgets/pattern_app_bar.dart';
import 'package:craft_stash/services/theme_controller.dart';
import 'dart:async';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false; // Show loading indicator during login process
  String? _errorMessage; // Display authentication errors
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_passwordController.text.length < 6) {
        throw "Password must be at least 6 characters long.";
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        throw "Passwords do not match.";
      }
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCred.user;

      if (user != null) {
        await user.updateDisplayName(_nicknameController.text.trim());
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account Created: ${user?.email}")),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        String msg = e.toString();
        _errorMessage = msg.substring(msg.indexOf(']') + 1).trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: const PatternAppBar(title: 'Create Account'),
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // ✅ Disables scrolling unless forced
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // ✅ Prevents overflow with keyboard
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Align(
              alignment: Alignment(0, -0.4),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 35),
                        TextFormField( // Email
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
                            rebuild(5);
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nicknameController,
                          decoration: const InputDecoration(
                            labelText: 'Nickname',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            rebuild(5);
                            if (value == null || value.isEmpty) {
                              return 'Please enter your nickname';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        TextFormField( // Password
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            rebuild(5);
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        TextFormField( // Confirm Password
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sync_lock),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            rebuild(5);
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
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
                                onPressed: _signUp,
                                child: const Text('Sign Up'),
                              ),

                        const SizedBox(height: 80),

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
                        const SizedBox(height: 50),

                        const Text(
                          "Already have an account?\nLog in below!",
                          textAlign: TextAlign.center,
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Log In"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}