import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/auth_feature_flags.dart';
import '../../core/design_system/design_system.dart';
import '../../services/email_rules.dart';
import 'forgot_password_sheet.dart';
import 'resend_cooldown.dart';

/// Email or username sign-in. Password mode accepts either identifier; code
/// mode is available for email addresses.
class EmailSignInForm extends StatefulWidget {
  const EmailSignInForm({
    required this.controller,
    this.initialIdentifier = '',
    super.key,
  });

  final AppController controller;
  final String initialIdentifier;

  @override
  State<EmailSignInForm> createState() => _EmailSignInFormState();
}

class _EmailSignInFormState extends State<EmailSignInForm> {
  final _formKey = GlobalKey<FormState>();
  late final _identifier =
      TextEditingController(text: widget.initialIdentifier);
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _cooldown = ResendCooldown();
  bool _useCode = false;
  bool _obscurePassword = true;
  String? _lastChallengeId;

  @override
  void initState() {
    super.initState();
    _lastChallengeId = widget.controller.emailOtpChallengeId;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _cooldown.dispose();
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  /// A new code starts the resend countdown. A failed send does not, because
  /// it creates no challenge.
  void _onControllerChanged() {
    final challengeId = widget.controller.emailOtpChallengeId;
    if (challengeId != null && challengeId != _lastChallengeId) {
      _cooldown.start();
    }
    _lastChallengeId = challengeId;
  }

  String? _validateIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'Enter your email or username.';
    if (_useCode && !isValidEmail(identifier)) {
      return 'Enter a valid email address to receive a code.';
    }
    return null;
  }

  String get _normalizedIdentifier {
    final identifier = _identifier.text.trim();
    return isValidEmail(identifier) ? normalizeEmail(identifier) : identifier;
  }

  String? _validateOtp(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim())
          ? null
          : 'Enter the 6-digit code.';

  Future<void> _signInWithPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.signIn(_normalizedIdentifier, _password.text);
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    _otp.clear();
    await widget.controller.requestEmailAuthOtp(
      normalizeEmail(_identifier.text),
    );
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.signInWithEmailAuthOtp(
      email: normalizeEmail(_identifier.text),
      otp: _otp.text,
    );
  }

  void _changeIdentifier() {
    _otp.clear();
    _cooldown.cancel();
    widget.controller.emailOtpChallengeId = null;
    widget.controller.clearError();
  }

  void _toggleMode() {
    setState(() => _useCode = !_useCode);
    widget.controller.clearError();
  }

  void _forgotPassword() {
    showAppBottomSheet<void>(
      context,
      builder: (_) => ForgotPasswordSheet(
        controller: widget.controller,
        initialEmail: isValidEmail(_identifier.text) ? _identifier.text : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final codeAvailable =
        AuthFeatureFlags.emailOtp && controller.emailOtpAvailable;
    // Without the code endpoints, password is the only way in.
    final showCode = _useCode && codeAvailable;

    return ListenableBuilder(
      listenable: Listenable.merge([controller, _cooldown]),
      builder: (context, _) {
        final busy = controller.busy;
        final codeRequested = controller.emailOtpChallengeId != null;
        final VoidCallback? onSubmit = busy
            ? null
            : !showCode
                ? _signInWithPassword
                : !codeRequested
                    ? _sendCode
                    : _verifyCode;
        return AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _identifier,
                  enabled: !busy && !codeRequested,
                  label: 'Email or username',
                  prefix: const Icon(Icons.mail_outline),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction:
                      showCode ? TextInputAction.done : TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  validator: _validateIdentifier,
                  suffix: codeRequested
                      ? IconButton(
                          tooltip: 'Change email or username',
                          onPressed: busy ? null : _changeIdentifier,
                          icon: const Icon(Icons.edit_outlined),
                        )
                      : null,
                ),
                if (!showCode) ...[
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _password,
                    enabled: !busy,
                    label: 'Password',
                    prefix: const Icon(Icons.lock_outline),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _signInWithPassword(),
                    suffix: IconButton(
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Enter your password.' : null,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ] else if (codeRequested) ...[
                  const SizedBox(height: AppSpace.md),
                  FormField<String>(
                    validator: (_) => _validateOtp(_otp.text),
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification code',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        IgnorePointer(
                          ignoring: busy,
                          child: OtpField(
                            controller: _otp,
                            autofocus: true,
                            autofillOneTimeCode: true,
                            onChanged: (_) => field.didChange(_otp.text),
                            onCompleted: (_) => _verifyCode(),
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
                ],
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
                  label: !showCode
                      ? 'Sign in'
                      : codeRequested
                          ? 'Verify code and sign in'
                          : 'Send code',
                  loading: busy,
                  onPressed: onSubmit,
                ),
                if (showCode && codeRequested) ...[
                  GhostButton(
                    label: _cooldown.active
                        ? 'Send a new code in ${_cooldown.remaining}s'
                        : 'Send a new code',
                    onPressed: busy || _cooldown.active ? null : _sendCode,
                  ),
                ],
                if (codeAvailable)
                  GhostButton(
                    label: _useCode ? 'Use password' : 'Email me a code',
                    onPressed: busy ? null : _toggleMode,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
