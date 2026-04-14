import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).login(
            emailController.text.trim(),
            passwordController.text,
          );
    } catch (e) {
      // Fehler wird durch den AsyncValue-State behandelt
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    // Listener für erfolgreichen Login
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && mounted) {
          context.go('/home');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie eine E-Mail ein';
                  }
                  if (!value.contains('@')) {
                    return 'Bitte geben Sie eine gültige E-Mail ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie ein Passwort ein';
                  }
                  if (value.length < 6) {
                    return 'Das Passwort muss mindestens 6 Zeichen lang sein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Fehleranzeige
              authState.when(
                data: (_) => const SizedBox.shrink(),
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _getErrorMessage(error),
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Don\'t have an account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // Firebase Auth Exception Codes
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Kein Benutzer mit dieser E-Mail gefunden';
        case 'wrong-password':
          return 'Falsches Passwort';
        case 'invalid-email':
          return 'Ungültige E-Mail-Adresse';
        case 'user-disabled':
          return 'Dieser Benutzer wurde deaktiviert';
        case 'too-many-requests':
          return 'Zu viele Versuche. Bitte versuchen Sie es später erneut';
        case 'network-request-failed':
          return 'Netzwerkfehler. Bitte überprüfen Sie Ihre Internetverbindung';
        case 'invalid-credential':
          return 'Ungültige Anmeldedaten';
        default:
          return 'Fehler: ${error.message ?? error.code}';
      }
    }
    
    // Fallback für String-basierte Fehlerprüfung
    if (errorString.contains('user-not-found')) {
      return 'Kein Benutzer mit dieser E-Mail gefunden';
    } else if (errorString.contains('wrong-password')) {
      return 'Falsches Passwort';
    } else if (errorString.contains('invalid-email')) {
      return 'Ungültige E-Mail-Adresse';
    } else if (errorString.contains('user-disabled')) {
      return 'Dieser Benutzer wurde deaktiviert';
    } else if (errorString.contains('too-many-requests')) {
      return 'Zu viele Versuche. Bitte versuchen Sie es später erneut';
    } else if (errorString.contains('network')) {
      return 'Netzwerkfehler. Bitte überprüfen Sie Ihre Internetverbindung';
    }
    return 'Ein Fehler ist aufgetreten: $error';
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
