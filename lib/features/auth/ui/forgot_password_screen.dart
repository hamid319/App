import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/widgets/primary_button.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/password_reset_controller.dart';

/// "Forgot password": asks for the email and sends Firebase's reset link.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.fromSettings = false,
  });

  /// Prefilled from the login form or the signed-in account.
  final String? initialEmail;

  /// Opened by a signed-in user from settings: "back" instead of "back to
  /// login".
  final bool fromSettings;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  /// Wait before the link can be sent again, so a double tap or impatience
  /// does not trip Firebase's rate limit.
  static const resendDelay = Duration(seconds: 30);

  late final _emailController =
      TextEditingController(text: widget.initialEmail?.trim() ?? '');
  final _formKey = GlobalKey<FormState>();
  Timer? _cooldown;
  int _secondsLeft = 0;

  /// Address of the last sent link; keeps the confirmation on screen while
  /// the link is sent again.
  String? _lastSentTo;

  @override
  void dispose() {
    _cooldown?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send({bool resend = false}) async {
    // On resend the form is not on screen; the address was validated before.
    if (!resend && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(passwordResetControllerProvider.notifier).send(
          _emailController.text,
          languageCode: Localizations.localeOf(context).languageCode,
        );
    if (mounted && ref.read(passwordResetControllerProvider).hasValue) {
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldown?.cancel();
    setState(() => _secondsLeft = resendDelay.inSeconds);
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetControllerProvider);
    if (state.value != null) _lastSentTo = state.value;
    final sentTo = state.value ?? (state.isLoading ? _lastSentTo : null);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: sentTo == null
              ? _buildForm(context, state)
              : _buildSent(context, sentTo, state.isLoading),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AsyncValue<String?> state) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = state.error;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.forgotPasswordTitle, style: text.headlineMedium),
          const SizedBox(height: AppSizes.space8),
          Text(
            l10n.forgotPasswordBody,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSizes.space32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _send(),
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return l10n.emailRequired;
              if (!email.contains('@')) return l10n.emailInvalid;
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: AppSizes.space16),
            Container(
              padding: const EdgeInsets.all(AppSizes.space12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                _errorText(l10n, error),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.space24),
          PrimaryButton(
            label: l10n.sendResetLink,
            isLoading: state.isLoading,
            onPressed: _send,
          ),
          const SizedBox(height: AppSizes.space8),
          TextButton(
            onPressed: _backToLogin,
            child: Text(widget.fromSettings ? l10n.back : l10n.backToLogin),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context, String email, bool sending) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final canResend = _secondsLeft <= 0 && !sending;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_outlined,
                size: 32, color: scheme.primary),
          ),
        ),
        const SizedBox(height: AppSizes.space24),
        Text(l10n.resetLinkSentTitle, style: text.headlineMedium),
        const SizedBox(height: AppSizes.space8),
        Text(
          l10n.resetLinkSentBody(email),
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSizes.space32),
        PrimaryButton(
          label: widget.fromSettings ? l10n.back : l10n.backToLogin,
          onPressed: _backToLogin,
        ),
        const SizedBox(height: AppSizes.space8),
        TextButton(
          onPressed: canResend ? () => _send(resend: true) : null,
          child: Text(
            canResend ? l10n.resendResetLink : l10n.resendIn(_secondsLeft),
          ),
        ),
        TextButton(
          onPressed: () =>
              ref.read(passwordResetControllerProvider.notifier).editAddress(),
          child: Text(l10n.useOtherEmail),
        ),
      ],
    );
  }

  String _errorText(AppLocalizations l10n, Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return l10n.authInvalidEmail;
        case 'too-many-requests':
          return l10n.authTooManyRequests;
        case 'network-request-failed':
          return l10n.authNetwork;
      }
    }
    return l10n.resetLinkFailed;
  }
}
