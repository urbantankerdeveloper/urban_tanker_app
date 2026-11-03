import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
import '../services/masking.dart';

enum _AuthMode { register, login }

enum _LoginMethod { phone, usernamePassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  _AuthMode _mode = _AuthMode.register;
  _LoginMethod _loginMethod = _LoginMethod.phone;
  bool _obscurePassword = true;

  bool get _otpRequested => widget.controller.phoneOtpChallengeId != null;
  bool get _isRegistration => _mode == _AuthMode.register;
  bool get _usesPhone => _isRegistration || _loginMethod == _LoginMethod.phone;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
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
    widget.controller.phoneOtpChallengeId = null;
    widget.controller.clearError();
  }

  void _selectMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _AuthMode.register) _loginMethod = _LoginMethod.phone;
    });
    widget.controller.clearError();
  }

  void _selectLoginMethod(_LoginMethod method) {
    if (_loginMethod == method) return;
    if (method == _LoginMethod.usernamePassword) {
      widget.controller.phoneOtpChallengeId = null;
      _otp.clear();
    }
    setState(() => _loginMethod = method);
    widget.controller.clearError();
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
    final usePhone = _usesPhone;
    final title = _otpRequested
        ? 'Verify your number.'
        : _isRegistration
            ? 'Create your account.'
            : usePhone
                ? 'Welcome back.'
                : 'Sign in.';
    final subtitle = _otpRequested
        ? 'Enter the 6-digit code sent to ${maskPhone(_phone.text)}.'
        : _isRegistration
            ? 'Create a customer account with your mobile number and a one-time code.'
            : usePhone
                ? 'Sign in with a one-time code sent to your mobile number.'
                : 'Use your registered username and password.';

    final fields = <Widget>[
      if (!_isRegistration) ...[
        SegmentedTabs(
          labels: const ['Phone OTP', 'Username'],
          selectedIndex: _loginMethod == _LoginMethod.phone ? 0 : 1,
          onChanged: controller.busy
              ? null
              : (index) => _selectLoginMethod(
                    index == 0
                        ? _LoginMethod.phone
                        : _LoginMethod.usernamePassword,
                  ),
        ),
        const SizedBox(height: AppSpace.xl),
      ],
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
                Text('Verification code', style: theme.textTheme.labelLarge),
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
        GhostButton(
          label: 'Send a new code',
          onPressed: controller.busy
              ? null
              : () async {
                  _otp.clear();
                  await controller.requestPhoneAuthOtp(_phone.text);
                },
        ),
    ];

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
                child: Form(
                  key: _formKey,
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
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: fields,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      GhostButton(
                        label: _isRegistration
                            ? 'Already a user? Log in'
                            : 'New to Urban Tanker? Create an account',
                        onPressed: controller.busy
                            ? null
                            : () => _selectMode(
                                  _isRegistration
                                      ? _AuthMode.login
                                      : _AuthMode.register,
                                ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Public registration is for customer accounts. Existing vendor and admin accounts can sign in with their registered phone number or credentials.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
