import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
import '../app/theme.dart';

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
    final usePhone = _usesPhone;
    final title = _otpRequested
        ? 'Verify your number.'
        : _isRegistration
            ? 'Create your account.'
            : usePhone
                ? 'Welcome back.'
                : 'Sign in.';
    final subtitle = _otpRequested
        ? 'Enter the 6-digit code sent to ${_phone.text}.'
        : _isRegistration
            ? 'Create a customer account with your mobile number and a one-time code.'
            : usePhone
                ? 'Sign in with a one-time code sent to your mobile number.'
                : 'Use your registered username and password.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppPageInsets.standard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'URBAN TANKER',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: aqua,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    if (!_isRegistration) ...[
                      const SizedBox(height: 20),
                      SegmentedButton<_LoginMethod>(
                        segments: const [
                          ButtonSegment(
                            value: _LoginMethod.phone,
                            icon: Icon(Icons.phone_outlined),
                            label: Text('Phone OTP'),
                          ),
                          ButtonSegment(
                            value: _LoginMethod.usernamePassword,
                            icon: Icon(Icons.person_outline),
                            label: Text('Username'),
                          ),
                        ],
                        selected: {_loginMethod},
                        onSelectionChanged: controller.busy
                            ? null
                            : (selection) =>
                                _selectLoginMethod(selection.first),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (usePhone) ...[
                      TextFormField(
                        controller: _phone,
                        enabled: !_otpRequested && !controller.busy,
                        keyboardType: TextInputType.phone,
                        textInputAction: _otpRequested
                            ? TextInputAction.next
                            : TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: '10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: '+91 ',
                          suffixIcon: _otpRequested
                              ? IconButton(
                                  tooltip: 'Change mobile number',
                                  onPressed:
                                      controller.busy ? null : _changeNumber,
                                  icon: const Icon(Icons.edit_outlined),
                                )
                              : null,
                        ),
                        validator: _validatePhone,
                      ),
                      if (_otpRequested) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _otp,
                          enabled: !controller.busy,
                          keyboardType: TextInputType.number,
                          textInputAction: _isRegistration
                              ? TextInputAction.next
                              : TextInputAction.done,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            prefixIcon: Icon(Icons.password_outlined),
                            counterText: '',
                          ),
                          validator: (value) => value == null ||
                                  !RegExp(r'^\d{6}$').hasMatch(value.trim())
                              ? 'Enter the 6-digit code.'
                              : null,
                        ),
                        if (_isRegistration) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _name,
                            enabled: !controller.busy,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: _validateName,
                          ),
                        ],
                      ],
                    ] else ...[
                      TextFormField(
                        controller: _username,
                        enabled: !controller.busy,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            _validateRequired(value, 'username'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !controller.busy,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            _validateRequired(value, 'password'),
                      ),
                    ],
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        AppStateView.isNetworkError(controller.errorMessage!)
                            ? 'No network connection. Check your internet connection and try again.'
                            : controller.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (controller.successMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.successMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: controller.busy ? null : _submit,
                      child: controller.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              !usePhone
                                  ? 'Sign in'
                                  : _otpRequested
                                      ? _isRegistration
                                          ? 'Verify code and create account'
                                          : 'Verify code and sign in'
                                      : 'Send verification code',
                            ),
                    ),
                    if (usePhone && _otpRequested)
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () async {
                                _otp.clear();
                                await controller
                                    .requestPhoneAuthOtp(_phone.text);
                              },
                        child: const Text('Send a new code'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: controller.busy
                          ? null
                          : () => _selectMode(
                                _isRegistration
                                    ? _AuthMode.login
                                    : _AuthMode.register,
                              ),
                      child: Text(
                        _isRegistration
                            ? 'Already a user? Log in'
                            : 'New to Urban Tanker? Create an account',
                      ),
                    ),
                    Text(
                      'Public registration is for customer accounts. Existing vendor and admin accounts can sign in with their registered phone number or credentials.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
