import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/design_system/design_system.dart';
import 'resend_cooldown.dart';

/// Second step of email sign-up. The account exists but is not confirmed, so
/// the user enters the 6-digit code sent to their email. It replaces the form
/// on the same screen.
class SignUpCodeView extends StatefulWidget {
  const SignUpCodeView({
    required this.controller,
    required this.email,
    required this.onBackToSignIn,
    super.key,
  });

  final AppController controller;
  final String email;
  final VoidCallback onBackToSignIn;

  @override
  State<SignUpCodeView> createState() => _SignUpCodeViewState();
}

class _SignUpCodeViewState extends State<SignUpCodeView> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  final _cooldown = ResendCooldown();

  @override
  void initState() {
    super.initState();
    // The code was sent when the account was created, so the first resend
    // waits for the cooldown.
    _cooldown.start();
  }

  @override
  void dispose() {
    _cooldown.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _validateOtp(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim())
          ? null
          : 'Enter the 6-digit code.';

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.signInWithEmailAuthOtp(
      email: widget.email,
      otp: _otp.text,
    );
  }

  Future<void> _resend() async {
    _otp.clear();
    await widget.controller.requestEmailAuthOtp(widget.email);
    if (widget.controller.emailOtpChallengeId != null) {
      _cooldown.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _cooldown]),
      builder: (context, _) {
        final controller = widget.controller;
        final busy = controller.busy;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LottieOrIcon(
                  asset: 'assets/lottie/mail.json',
                  repeat: false,
                  fallback: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: colors.primary,
                  ),
                  size: 120,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'Enter your verification code',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'We sent a 6-digit code to this address. Enter it to finish '
                'creating your account. If it is not in your inbox, check your '
                'spam folder.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.md),
              FormField<String>(
                validator: (_) => _validateOtp(_otp.text),
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification code',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    IgnorePointer(
                      ignoring: busy,
                      child: OtpField(
                        controller: _otp,
                        autofocus: true,
                        onChanged: (_) => field.didChange(_otp.text),
                        onCompleted: (_) => _verify(),
                      ),
                    ),
                    if (field.hasError) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        field.errorText!,
                        style: TextStyle(color: colors.danger.fg),
                      ),
                    ],
                  ],
                ),
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: colors.danger.fg),
                ),
              ],
              if (controller.successMessage != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  controller.successMessage!,
                  style: TextStyle(color: colors.success.fg),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: 'Verify and continue',
                loading: busy,
                onPressed: busy ? null : _verify,
              ),
              GhostButton(
                label: _cooldown.active
                    ? 'Send a new code in ${_cooldown.remaining}s'
                    : 'Send a new code',
                onPressed: busy || _cooldown.active ? null : _resend,
              ),
              GhostButton(
                label: 'Back to sign in',
                onPressed: busy ? null : widget.onBackToSignIn,
              ),
            ],
          ),
        );
      },
    );
  }
}
