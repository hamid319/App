import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_controller.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../../../common/widgets/wordmark.dart';

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
      // Errors are surfaced through the AsyncValue state
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Navigate home once login succeeds
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      next.whenData((user) {
        // A guest session is not a finished sign-in; wait for a real account.
        if (user != null && !user.isAnonymous && mounted) {
          context.go('/trips');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(),
      // Scrollable so the keyboard cannot push the form off a small screen.
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Wordmark(size: 22),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.loginHeadline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.loginSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                Ticket(
                  raised: true,
                  padding: const EdgeInsets.all(AppSizes.space16 + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                      labelText: context.l10n.emailLabel,
                      prefixIcon: const Icon(Icons.mail_outline)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.emailRequired;
                    }
                    if (!value.contains('@')) {
                      return context.l10n.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                      labelText: context.l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.passwordRequired;
                    }
                    if (value.length < 6) {
                      return context.l10n.passwordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Error message
                authState.when(
                  data: (_) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stack) => Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                        width: AppSizes.edge,
                      ),
                    ),
                    child: Text(
                      _getErrorMessage(error),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
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
                        : Text(context.l10n.loginButton),
                  ),
                ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.space16),
                TextButton(
                  onPressed: () => context.pushReplacement('/register'),
                  child: Text(context.l10n.noAccountRegister),
                ),
                if (authState.value?.isAnonymous ?? false)
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(context.l10n.continueAsGuest),
                  ),
              ],
            ),
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
          return context.l10n.authUserNotFound;
        case 'wrong-password':
          return context.l10n.authWrongPassword;
        case 'invalid-email':
          return context.l10n.authInvalidEmail;
        case 'user-disabled':
          return context.l10n.authUserDisabled;
        case 'too-many-requests':
          return context.l10n.authTooManyRequests;
        case 'network-request-failed':
          return context.l10n.authNetwork;
        case 'invalid-credential':
          return context.l10n.authInvalidCredential;
        default:
          return context.l10n.loginFailed;
      }
    }

    // Fallback for string-based error matching
    if (errorString.contains('user-not-found')) {
      return context.l10n.authUserNotFound;
    } else if (errorString.contains('wrong-password')) {
      return context.l10n.authWrongPassword;
    } else if (errorString.contains('invalid-email')) {
      return context.l10n.authInvalidEmail;
    } else if (errorString.contains('user-disabled')) {
      return context.l10n.authUserDisabled;
    } else if (errorString.contains('too-many-requests')) {
      return context.l10n.authTooManyRequests;
    } else if (errorString.contains('network')) {
      return context.l10n.authNetwork;
    }
    return context.l10n.errorGeneric;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
