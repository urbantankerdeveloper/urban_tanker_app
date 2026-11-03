import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/auth_feature_flags.dart';
import '../../core/design_system/design_system.dart';
import '../../services/api/api_types.dart';
import '../../services/email_rules.dart';
import 'password_rules.dart';
import 'password_strength_meter.dart';
import 'resend_cooldown.dart';

/// Email sign-up for customer accounts. Password mode is the default. Code mode
/// collects the same details and then checks a one-time code sent to the
/// address.
class EmailSignUpForm extends StatefulWidget {
  const EmailSignUpForm({
    required this.controller,
    required this.onAccountExists,
    super.key,
  });

  final AppController controller;

  /// Called with the address when it is already registered, so the screen can
  /// switch to sign-in with it filled in.
  final ValueChanged<String> onAccountExists;

  @override
  State<EmailSignUpForm> createState() => _EmailSignUpFormState();
}

class _EmailSignUpFormState extends State<EmailSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final challengeId = widget.controller.emailOtpChallengeId;
    if (challengeId != null && challengeId != _lastChallengeId) {
      _cooldown.start();
    }
    _lastChallengeId = challengeId;
  }

  String? _validateName(String? value) => (value ?? '').trim().length < 2
      ? 'Enter your name to create a customer account.'
      : null;

  String? _validateEmail(String? value) =>
      isValidEmail(value ?? '') ? null : 'Enter a valid email address.';

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? null : 'Enter a valid 10-digit mobile number.';
  }

  String? _validatePassword(String? value) => isStrongPassword(value ?? '')
      ? null
      : 'Choose a password that meets every rule below.';

  String? _validateConfirm(String? value) =>
      (value ?? '').isEmpty || value == _password.text
          ? null
          : 'Passwords do not match.';

  String? _validateOtp(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim())
          ? null
          : 'Enter the 6-digit code.';

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.signUp(
      email: normalizeEmail(_email.text),
      password: _password.text,
      name: _name.text,
      phone: normalizeIndianPhone(_phone.text),
    );
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    _otp.clear();
    await widget.controller.requestEmailAuthOtp(normalizeEmail(_email.text));
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.signInWithEmailAuthOtp(
      email: normalizeEmail(_email.text),
      otp: _otp.text,
      name: _name.text.trim(),
      phone: normalizeIndianPhone(_phone.text),
    );
  }

  void _toggleMode() {
    setState(() => _useCode = !_useCode);
    widget.controller.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final theme = Theme.of(context);
    final codeAvailable =
        AuthFeatureFlags.emailOtp && controller.emailOtpAvailable;
    final showCode = _useCode && codeAvailable;

    return ListenableBuilder(
      listenable: Listenable.merge([controller, _cooldown]),
      builder: (context, _) {
        final busy = controller.busy;
        final codeRequested = controller.emailOtpChallengeId != null;
        final accountExists = controller.errorStatusCode == 409 && !showCode;
        final VoidCallback? onSubmit = busy
            ? null
            : !showCode
                ? _createAccount
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
                  controller: _name,
                  enabled: !busy && !codeRequested,
                  label: 'Full name',
                  prefix: const Icon(Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: _validateName,
                ),
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _email,
                  enabled: !busy && !codeRequested,
                  label: 'Email',
                  prefix: const Icon(Icons.mail_outline),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _phone,
                  enabled: !busy && !codeRequested,
                  label: '10-digit mobile number',
                  prefix: const Icon(Icons.phone_outlined),
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  validator: _validatePhone,
                ),
                if (!showCode) ...[
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _password,
                    enabled: !busy,
                    label: 'Password',
                    prefix: const Icon(Icons.lock_outline),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
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
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PasswordStrengthMeter(password: _password.text),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _confirm,
                    enabled: !busy,
                    label: 'Confirm password (optional)',
                    prefix: const Icon(Icons.lock_outline),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _validateConfirm,
                    onFieldSubmitted: (_) => _createAccount(),
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
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        IgnorePointer(
                          ignoring: busy,
                          child: OtpField(
                            controller: _otp,
                            autofocus: true,
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
                if (accountExists) ...[
                  const SizedBox(height: AppSpace.xs),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => widget.onAccountExists(
                              normalizeEmail(_email.text),
                            ),
                    child: const Text('Sign in instead'),
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: !showCode
                      ? 'Create account'
                      : codeRequested
                          ? 'Verify code and create account'
                          : 'Send code',
                  loading: busy,
                  onPressed: onSubmit,
                ),
                if (showCode && codeRequested)
                  GhostButton(
                    label: _cooldown.active
                        ? 'Send a new code in ${_cooldown.remaining}s'
                        : 'Send a new code',
                    onPressed: busy || _cooldown.active ? null : _sendCode,
                  ),
                if (codeAvailable)
                  GhostButton(
                    label: _useCode
                        ? 'Use a password instead'
                        : 'Prefer a code? Sign up with an email code',
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
