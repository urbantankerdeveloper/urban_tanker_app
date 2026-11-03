import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../services/email_rules.dart';

/// Asks for the account email and sends reset instructions. The wording is
/// neutral on purpose: it never says whether the address has an account.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    required this.controller,
    required this.initialEmail,
    super.key,
  });

  final AppController controller;
  final String initialEmail;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.requestPasswordReset(normalizeEmail(_email.text));
    if (mounted && widget.controller.errorMessage == null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.busy;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reset your password', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Enter the email on your account. If it is registered, we '
                  'will send reset instructions.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.lg),
                AppTextField(
                  controller: _email,
                  enabled: !busy,
                  label: 'Email',
                  prefix: const Icon(Icons.mail_outline),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => isValidEmail(value ?? '')
                      ? null
                      : 'Enter a valid email address.',
                  onFieldSubmitted: (_) => _send(),
                ),
                if (widget.controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    widget.controller.errorMessage!,
                    style: TextStyle(color: colors.danger.fg),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                PrimaryButton(
                  label: 'Send reset instructions',
                  loading: busy,
                  onPressed: busy ? null : _send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
