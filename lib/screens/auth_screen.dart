import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
import '../services/masking.dart';
import 'auth/email_sign_in_form.dart';
import 'auth/email_sign_up_form.dart';
import 'auth/resend_cooldown.dart';
import 'auth/sign_up_code_view.dart';

enum _AuthMode { register, login }

/// How the user signs in. Username is for existing accounts only.
enum _AuthMethod { phone, email, username }

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// Replaced whenever the mode or method changes, so the old and new forms
  /// never share a key while the switcher animates between them.
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  _AuthMode _mode = _AuthMode.register;
  _AuthMethod _method = _AuthMethod.phone;
  bool _obscurePassword = true;
  String _prefillEmail = '';
  final _resendCooldown = ResendCooldown();
  String? _lastChallengeId;

  bool get _otpRequested => widget.controller.phoneOtpChallengeId != null;
  bool get _isRegistration => _mode == _AuthMode.register;
  bool get _usesPhone => _method == _AuthMethod.phone;
  bool get _usesEmail => _method == _AuthMethod.email;

  /// Customers can create an account by phone or email. Username is for
  /// existing accounts only.
  List<_AuthMethod> get _methods => _isRegistration
      ? const [_AuthMethod.phone, _AuthMethod.email]
      : const [_AuthMethod.phone, _AuthMethod.email, _AuthMethod.username];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _method =
        _methodFromName(widget.controller.lastAuthMethod) ?? _AuthMethod.phone;
    if (!_methods.contains(_method)) _method = _AuthMethod.phone;
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  static _AuthMethod? _methodFromName(String? name) => switch (name) {
        'phone' => _AuthMethod.phone,
        'email' => _AuthMethod.email,
        'username' => _AuthMethod.username,
        _ => null,
      };

  static String _methodLabel(_AuthMethod method) => switch (method) {
        _AuthMethod.phone => 'Phone',
        _AuthMethod.email => 'Email',
        _AuthMethod.username => 'Username',
      };

  void _onControllerChanged() {
    final challengeId = widget.controller.phoneOtpChallengeId;
    if (challengeId != null && challengeId != _lastChallengeId) {
      _resendCooldown.start();
    }
    _lastChallengeId = challengeId;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _resendCooldown.dispose();
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_usesPhone) {
      await widget.controller.signIn(_username.text, _password.text);
      return;
    }
    if (_otpRequested) {
      await widget.controller.signInWithPhoneAuthOtp(
        phone: _phone.text,
        otp: _otp.text,
        name: _isRegistration ? _name.text : null,
      );
    } else {
      await widget.controller.requestPhoneAuthOtp(_phone.text);
    }
  }

  void _changeNumber() {
    _otp.clear();
    _resendCooldown.cancel();
    widget.controller.phoneOtpChallengeId = null;
    widget.controller.clearError();
  }

  void _selectMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _formKey = GlobalKey<FormState>();
      if (!_methods.contains(_method)) _method = _AuthMethod.phone;
    });
    widget.controller.clearError();
  }

  void _selectMethod(_AuthMethod method) {
    if (_method == method) return;
    if (method != _AuthMethod.phone) {
      widget.controller.phoneOtpChallengeId = null;
      _otp.clear();
      _resendCooldown.cancel();
    }
    setState(() {
      _method = method;
      _formKey = GlobalKey<FormState>();
    });
    widget.controller.rememberAuthMethod(method.name);
    widget.controller.clearError();
  }

  /// Opens sign-in with [email] filled in, for an address that already has an
  /// account.
  void _switchToSignIn(String email) {
    setState(() {
      _mode = _AuthMode.login;
      _method = _AuthMethod.email;
      _prefillEmail = email;
      _formKey = GlobalKey<FormState>();
    });
    widget.controller.rememberAuthMethod(_AuthMethod.email.name);
    widget.controller.clearError();
  }

  void _backToSignInFromCode() {
    final email = widget.controller.pendingEmailVerification ?? '';
    widget.controller.clearPendingEmailVerification();
    _switchToSignIn(email);
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit mobile number.';
    return null;
  }

  String? _validateOtp(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isRegistration) return null;
    if ((value ?? '').trim().length < 2) {
      return 'Enter your name to create a customer account.';
    }
    return null;
  }

  String? _validateRequired(String? value, String field) {
    if (value == null || value.trim().isEmpty) return 'Enter your $field.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final theme = Theme.of(context);
    final pendingEmail = controller.pendingEmailVerification;

    final title = pendingEmail != null
        ? 'Verify your email.'
        : _usesEmail
            ? _isRegistration
                ? 'Create your account.'
                : 'Welcome back.'
            : _otpRequested
                ? 'Verify your number.'
                : _isRegistration
                    ? 'Create your account.'
                    : _usesPhone
                        ? 'Welcome back.'
                        : 'Sign in.';
    final subtitle = pendingEmail != null
        ? 'One step left to finish.'
        : _usesEmail
            ? _isRegistration
                ? 'Create a customer account with your email and a password, '
                    'or with a one-time code.'
                : 'Sign in with your email and password, or with a one-time '
                    'code.'
            : _otpRequested
                ? 'Enter the 6-digit code sent to ${maskPhone(_phone.text)}.'
                : _isRegistration
                    ? 'Create a customer account with your mobile number and a one-time code.'
                    : _usesPhone
                        ? 'Sign in with a one-time code sent to your mobile number.'
                        : 'Use your registered username and password.';

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.xxl,
                AppSpace.gutter,
                AppSpace.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo()),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'URBAN TANKER',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpace.xl),
                    if (pendingEmail != null)
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: SignUpCodeView(
                          controller: controller,
                          email: pendingEmail,
                          onBackToSignIn: _backToSignInFromCode,
                        ),
                      )
                    else ...[
                      SegmentedTabs(
                        labels: const ['Sign in', 'Create account'],
                        selectedIndex: _isRegistration ? 1 : 0,
                        onChanged: controller.busy
                            ? null
                            : (index) => _selectMode(
                                  index == 1
                                      ? _AuthMode.register
                                      : _AuthMode.login,
                                ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          for (final method in _methods)
                            ChoiceChip(
                              label: Text(_methodLabel(method)),
                              selected: _method == method,
                              onSelected: controller.busy
                                  ? null
                                  : (_) => _selectMethod(method),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, AppMotion.base),
                          child: KeyedSubtree(
                            key: ValueKey('${_mode.name}-${_method.name}'),
                            child: _usesEmail
                                ? _isRegistration
                                    ? EmailSignUpForm(
                                        controller: controller,
                                        onAccountExists: _switchToSignIn,
                                      )
                                    : EmailSignInForm(
                                        controller: controller,
                                        initialEmail: _prefillEmail,
                                      )
                                : _phoneOrUsernameForm(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The phone and username forms. They keep their behaviour from before the
  /// email option was added.
  Widget _phoneOrUsernameForm(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final theme = Theme.of(context);
    final usePhone = _usesPhone;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (usePhone) ...[
            AppTextField(
              controller: _phone,
              enabled: !_otpRequested && !controller.busy,
              label: '10-digit mobile number',
              prefix: const Icon(Icons.phone_outlined),
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              textInputAction:
                  _otpRequested ? TextInputAction.next : TextInputAction.done,
              suffix: _otpRequested
                  ? IconButton(
                      tooltip: 'Change mobile number',
                      onPressed: controller.busy ? null : _changeNumber,
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
              validator: _validatePhone,
            ),
            if (_otpRequested) ...[
              const SizedBox(height: AppSpace.md),
              FormField<String>(
                validator: (_) => _validateOtp(_otp.text),
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verification code',
                        style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpace.sm),
                    IgnorePointer(
                      ignoring: controller.busy,
                      child: OtpField(
                        controller: _otp,
                        onChanged: (_) => field.didChange(_otp.text),
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
              if (_isRegistration) ...[
                const SizedBox(height: AppSpace.md),
                AppTextField(
                  controller: _name,
                  enabled: !controller.busy,
                  label: 'Full name',
                  prefix: const Icon(Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  validator: _validateName,
                ),
              ],
            ],
          ] else ...[
            AppTextField(
              controller: _username,
              enabled: !controller.busy,
              label: 'Username',
              prefix: const Icon(Icons.person_outline),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (value) => _validateRequired(value, 'username'),
            ),
            const SizedBox(height: AppSpace.md),
            AppTextField(
              controller: _password,
              enabled: !controller.busy,
              label: 'Password',
              prefix: const Icon(Icons.lock_outline),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) => _validateRequired(value, 'password'),
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
            label: !usePhone
                ? 'Sign in'
                : _otpRequested
                    ? _isRegistration
                        ? 'Verify code and create account'
                        : 'Verify code and sign in'
                    : 'Send verification code',
            loading: controller.busy,
            onPressed: controller.busy ? null : _submit,
          ),
          if (usePhone && _otpRequested)
            ListenableBuilder(
              listenable: _resendCooldown,
              builder: (context, _) => GhostButton(
                label: _resendCooldown.active
                    ? 'Send a new code in ${_resendCooldown.remaining}s'
                    : 'Send a new code',
                onPressed: controller.busy || _resendCooldown.active
                    ? null
                    : () async {
                        _otp.clear();
                        await controller.requestPhoneAuthOtp(_phone.text);
                      },
              ),
            ),
        ],
      ),
    );
  }
}
