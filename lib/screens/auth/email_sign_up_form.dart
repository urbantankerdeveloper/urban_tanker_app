import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_controller.dart';
import '../../app/auth_feature_flags.dart';
import '../../core/design_system/design_system.dart';
import '../../services/api/api_types.dart';
import '../../services/email_rules.dart';
import '../../services/photo_permissions.dart';
import 'password_rules.dart';
import 'resend_cooldown.dart';

const _signUpRoles = <String, String>{
  'customer': 'Customer',
  'vendor': 'Vendor (needs approval)',
  'admin': 'Admin (needs approval)',
};

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
  final _businessName = TextEditingController();
  final _serviceZone = TextEditingController();
  final _cooldown = ResendCooldown();
  bool _useCode = false;
  bool _obscurePassword = true;
  String? _lastChallengeId;
  String _role = 'customer';
  double? _latitude;
  double? _longitude;
  bool _capturingLocation = false;
  String? _locationMessage;
  XFile? _photo;
  String? _photoError;

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
    _businessName.dispose();
    _serviceZone.dispose();
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
      ? 'Enter your name to create an account.'
      : null;

  String? _validateVendorField(String? value, String message) =>
      _role == 'vendor' && (value ?? '').trim().length < 2 ? message : null;

  String? _validateEmail(String? value) =>
      isValidEmail(value ?? '') ? null : 'Enter a valid email address.';

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? null : 'Enter a valid 10-digit mobile number.';
  }

  String? _validatePassword(String? value) => isStrongPassword(value ?? '')
      ? null
      : 'Use at least 8 characters, including uppercase, lowercase, and a number.';

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
    final isVendor = _role == 'vendor';
    final photo = _photo;
    await widget.controller.signUp(
      email: normalizeEmail(_email.text),
      password: _password.text,
      name: _name.text,
      phone: normalizeIndianPhone(_phone.text),
      role: _role,
      businessName: isVendor ? _businessName.text : null,
      serviceZone: isVendor ? _serviceZone.text : null,
      latitude: isVendor ? _latitude : null,
      longitude: isVendor ? _longitude : null,
      selfieJpegBase64:
          photo == null ? null : base64Encode(await photo.readAsBytes()),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
        requestFullMetadata: pickerRequestsFullMetadata,
      );
      if (photo == null || !mounted) return;
      setState(() {
        _photo = photo;
        _photoError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = 'The photo could not be opened. Try again.');
      }
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturingLocation = true;
      _locationMessage = null;
    });
    String message;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        message = 'Turn on location services to add your location.';
      } else if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        message = 'Allow location access to add your location.';
      } else {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          _latitude = position.latitude;
          _longitude = position.longitude;
        }
        message = 'Location added.';
      }
    } catch (_) {
      _latitude = null;
      _longitude = null;
      message = 'Could not read your location. You can add it later.';
    }
    if (!mounted) return;
    setState(() {
      _capturingLocation = false;
      _locationMessage = message;
    });
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
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Account type',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: [
                      for (final entry in _signUpRoles.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _role = value ?? 'customer'),
                  ),
                  if (_role == 'vendor') ...[
                    const SizedBox(height: AppSpace.md),
                    AppTextField(
                      controller: _businessName,
                      enabled: !busy,
                      label: 'Business name',
                      prefix: const Icon(Icons.storefront_outlined),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _validateVendorField(
                        value,
                        'Enter your business name.',
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    AppTextField(
                      controller: _serviceZone,
                      enabled: !busy,
                      label: 'Service zone (city or area)',
                      prefix: const Icon(Icons.map_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) => _validateVendorField(
                        value,
                        'Enter the area you serve.',
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    GhostButton(
                      label: _latitude == null
                          ? 'Use my current location (optional)'
                          : 'Location added',
                      onPressed: busy || _capturingLocation
                          ? null
                          : _captureLocation,
                    ),
                    if (_locationMessage != null)
                      Text(
                        _locationMessage!,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _photo == null
                        ? 'Profile photo (optional)'
                        : 'Profile photo added',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Take a selfie',
                          onPressed: busy
                              ? null
                              : () => _pickPhoto(ImageSource.camera),
                        ),
                      ),
                      Expanded(
                        child: GhostButton(
                          label: 'Choose a photo',
                          onPressed: busy
                              ? null
                              : () => _pickPhoto(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  if (_photoError != null)
                    Text(
                      _photoError!,
                      style: TextStyle(color: colors.danger.fg),
                    ),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _password,
                    enabled: !busy,
                    label: 'Password',
                    prefix: const Icon(Icons.lock_outline),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
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
