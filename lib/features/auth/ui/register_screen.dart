import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/user_message.dart';
import '../logic/auth_controller.dart';
import '../../../l10n/l10n.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Navigate home once registration succeeds
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      next.whenData((user) {
        // A guest session is not a finished sign-in; wait for a real account.
        if (user != null && !user.isAnonymous && mounted) {
          context.go('/home');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.registerButton)),
      // Scrollable so the keyboard cannot push the form off a small screen.
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.nameLabel,
                    hintText: context.l10n.nameHint,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.nameRequired;
                    }
                    if (value.trim().length < 2) {
                      return context.l10n.nameTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: context.l10n.emailLabel),
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
                  decoration: InputDecoration(labelText: context.l10n.passwordLabel),
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
                const SizedBox(height: 24),
                // Error message
                authState.when(
                  data: (_) => const SizedBox.shrink(),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      userMessage(error, fallback: context.l10n.signupFailed, l10n: context.l10n),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleRegister,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.registerButton),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.pushReplacement('/login'),
                  child: Text(context.l10n.haveAccountLogin),
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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).signup(
            emailController.text.trim(),
            passwordController.text,
            displayName: nameController.text.trim(),
          );
    } catch (e) {
      // Errors are surfaced through the AsyncValue state
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
