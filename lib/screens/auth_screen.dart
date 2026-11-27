import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/auth_feature_flags.dart';
import '../core/design_system/design_system.dart';
import '../services/masking.dart';
import '../services/api/api_types.dart';
import 'auth/email_sign_in_form.dart';
import 'auth/email_sign_up_form.dart';
import 'auth/resend_cooldown.dart';
import 'auth/sign_up_code_view.dart';
import 'partner_application_screen.dart';

enum _AuthMode { register, login }

/// How the user signs in.
enum _AuthMethod { phone, email }

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

  _AuthMode _mode = _AuthMode.register;
  _AuthMethod _method = _AuthMethod.phone;
  String _prefillEmail = '';
  final _resendCooldown = ResendCooldown();
  String? _lastChallengeId;

  bool get _otpRequested => widget.controller.phoneOtpChallengeId != null;
  bool get _isRegistration => _mode == _AuthMode.register;
  bool get _usesEmail => _method == _AuthMethod.email;
  bool get _isMpinRecovery => widget.controller.pendingMpinReset;

  /// Customers can register by phone or email; sign-in accepts either email
  /// or username in the same identifier field.
  List<_AuthMethod> get _methods => _isMpinRecovery
      ? const [_AuthMethod.phone]
      : const [_AuthMethod.phone, _AuthMethod.email];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _mode = _AuthMode.login;
    _method = _isMpinRecovery
        ? _AuthMethod.phone
        : _methodFromName(widget.controller.lastAuthMethod) ??
              _AuthMethod.phone;
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
    'username' => _AuthMethod.email,
    _ => null,
  };

  String _methodLabel(_AuthMethod method) => switch (method) {
    _AuthMethod.phone => 'Phone',
    _AuthMethod.email => _isRegistration ? 'Email' : 'Email or username',
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otpRequested) {
      await widget.controller.signInWithPhoneAuthOtp(
        phone: _phone.text,
        otp: _otp.text,
        name: _isRegistration ? _name.text : null,
      );
      final statusCode = widget.controller.errorStatusCode;
      if (mounted &&
          AuthFeatureFlags.newUiEnabled &&
          (statusCode == 400 || statusCode == 401 || statusCode == 422)) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (screenContext) => FailureStateScreen(
              kind: FailureScreenKind.wrongOtp,
              onPrimary: () => Navigator.of(screenContext).pop(),
              onSecondary: () {
                Navigator.of(screenContext).pop();
                _changeNumber();
              },
            ),
          ),
        );
      }
    } else {
      await widget.controller.requestPhoneAuthOtp(_phone.text);
    }
  }

  void _changeNumber() {
    _otp.clear();
    _resendCooldown.cancel();
    widget.controller.phoneOtpChallengeId = null;
    widget.controller.phoneOtpChannel = null;
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
      widget.controller.phoneOtpChannel = null;
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final theme = Theme.of(context);
    final pendingEmail = controller.pendingEmailVerification;

    final title = pendingEmail != null
        ? 'Check your inbox.'
        : _isMpinRecovery
        ? 'Recover your account.'
        : _usesEmail
        ? _isRegistration
              ? 'Create your account.'
              : 'Welcome back.'
        : _otpRequested
        ? 'Verify your number.'
        : _isRegistration
        ? 'Create your account.'
        : 'Welcome back.';
    final subtitle = pendingEmail != null
        ? 'One step left to finish.'
        : _isMpinRecovery
        ? 'Verify your phone number with a one-time code to reset your MPIN.'
        : _usesEmail
        ? _isRegistration
              ? 'Create a customer account with your email and a password, '
                    'or with a one-time code.'
              : 'Sign in with your email or username and password. '
                    'Email one-time codes are also available.'
        : _otpRequested
        ? 'Enter the verification code below.'
        : _isRegistration
        ? 'Create a customer account with your mobile number and a one-time code.'
        : 'Sign in with a one-time code sent to your mobile number.';

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
                      if (!_isMpinRecovery) ...[
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
                      ],
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
                                          initialIdentifier: _prefillEmail,
                                        )
                                : _phoneForm(context),
                          ),
                        ),
                      ),
                      if (!_isMpinRecovery)
                        Align(
                          alignment: AlignmentDirectional.center,
                          child: TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => _selectMode(
                                    _isRegistration
                                        ? _AuthMode.login
                                        : _AuthMode.register,
                                  ),
                            child: Text(
                              _isRegistration
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create an account',
                            ),
                          ),
                        ),
                      if (AuthFeatureFlags.newUiEnabled &&
                          !_isMpinRecovery &&
                          !_otpRequested)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PartnerApplicationScreen(
                                  api: controller.api,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Become a partner'),
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

  Widget _phoneForm(BuildContext context) {
    final controller = widget.controller;
    final colors = context.colors;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _phone,
            enabled: !_otpRequested && !controller.busy,
            label: '10-digit mobile number',
            prefix: const Icon(Icons.phone_outlined),
            prefixText: '+91 ',
            keyboardType: TextInputType.phone,
            textInputAction: _otpRequested
                ? TextInputAction.next
                : TextInputAction.done,
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
            if (controller.phoneOtpChannel != null)
              Row(
                children: [
                  Icon(
                    controller.phoneOtpChannel == PhoneOtpChannel.whatsapp
                        ? Icons.chat_outlined
                        : Icons.sms_outlined,
                    color:
                        controller.phoneOtpChannel == PhoneOtpChannel.whatsapp
                        ? const Color(0xFF25D366)
                        : colors.primary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'We sent a code via ${controller.phoneOtpChannel == PhoneOtpChannel.whatsapp ? 'WhatsApp' : 'SMS'} to +91 ${maskPhone(_phone.text)}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpace.md),
            FormField<String>(
              validator: (_) => _validateOtp(_otp.text),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verification code', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpace.sm),
                  IgnorePointer(
                    ignoring: controller.busy,
                    child: OtpField(
                      controller: _otp,
                      autofillOneTimeCode:
                          controller.phoneOtpChannel == PhoneOtpChannel.sms,
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
            label: _otpRequested
                ? _isRegistration
                      ? 'Verify code and create account'
                      : 'Verify code and sign in'
                : 'Send verification code',
            loading: controller.busy,
            onPressed: controller.busy ? null : _submit,
          ),
          if (_otpRequested)
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
