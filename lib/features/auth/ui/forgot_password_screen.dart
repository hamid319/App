import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
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
      // Scrollable so the keyboard cannot push the form off a small screen.
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
          const Align(
            alignment: Alignment.centerLeft,
            child: IconBadge(icon: Icons.lock_reset_rounded, size: 64),
          ),
          const SizedBox(height: 20),
          Text(l10n.forgotPasswordTitle, style: text.headlineMedium),
          const SizedBox(height: AppSizes.space8),
          Text(
            l10n.forgotPasswordBody,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Ticket(
            raised: true,
            padding: const EdgeInsets.all(AppSizes.space16 + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 20),
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.space16),
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: scheme.error,
                        width: AppSizes.edge,
                      ),
                    ),
                    child: Text(
                      userMessage(
                        error,
                        fallback: l10n.resetLinkFailed,
                        l10n: l10n,
                      ),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                PrimaryButton(
                  label: l10n.sendResetLink,
                  isLoading: state.isLoading,
                  onPressed: _send,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space16),
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
        const Align(
          alignment: Alignment.centerLeft,
          child: IconBadge(
            icon: Icons.mark_email_read_outlined,
            tone: ChipTone.mint,
            size: 64,
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.resetLinkSentTitle, style: text.headlineMedium),
        const SizedBox(height: AppSizes.space8),
        Text(
          l10n.resetLinkSentBody(email),
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
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
}
