import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design_system/design_system.dart';
import '../services/friendly_error.dart';
import '../services/api/partner_api.dart';
import '../services/api_client.dart';

const _partnerServices = [
  'Water tanker',
  'Sewage suction',
  'Drinking water supply',
  'Tank and sump cleaning',
  'Borewell services',
  'RMC mix / ready-mix concrete',
  'Empty tanker and bulk-liquid transport',
  'Emergency water and sewage',
];

const _partnerTypes = ['Fleet operator', 'Individual operator', 'Company'];

const _availabilityOptions = ['Full time', 'Part time', 'On call'];

class PartnerApplicationScreen extends StatefulWidget {
  const PartnerApplicationScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<PartnerApplicationScreen> createState() =>
      _PartnerApplicationScreenState();
}

class _PartnerApplicationScreenState extends State<PartnerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _zone = TextEditingController();
  final _address = TextEditingController();
  final _vehicleCount = TextEditingController(text: '1');
  final _registration = TextEditingController();
  final _capacity = TextEditingController();
  final _experience = TextEditingController();
  final _notes = TextEditingController();
  final _otp = TextEditingController();
  final _services = <String>{};

  bool _loadingFlags = true;
  bool _otpRequired = false;
  bool _requestingOtp = false;
  bool _verifyingOtp = false;
  bool _submitting = false;
  bool _phoneVerified = false;
  String? _challengeId;
  String? _error;
  String? _flagsError;
  String? _partnerType = _partnerTypes.first;
  String? _availability = _availabilityOptions.first;
  PartnerApplicationReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  @override
  void dispose() {
    _businessName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _zone.dispose();
    _address.dispose();
    _vehicleCount.dispose();
    _registration.dispose();
    _capacity.dispose();
    _experience.dispose();
    _notes.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _loadFlags() async {
    setState(() {
      _loadingFlags = true;
      _flagsError = null;
    });
    try {
      final required = await widget.api.partnerApplicationOtpRequired();
      if (!mounted) return;
      setState(() {
        _otpRequired = required;
        _loadingFlags = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _flagsError = friendlyError(error);
        _loadingFlags = false;
      });
    }
  }

  void _phoneChanged(String _) {
    if (_challengeId == null && !_phoneVerified) return;
    setState(() {
      _challengeId = null;
      _phoneVerified = false;
      _otp.clear();
      _error = null;
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number first.');
      return;
    }
    setState(() {
      _requestingOtp = true;
      _error = null;
    });
    try {
      final challengeId = await widget.api.requestPartnerApplicationOtp(phone);
      if (!mounted) return;
      setState(() {
        _challengeId = challengeId;
        _phoneVerified = false;
        _requestingOtp = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _requestingOtp = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final challengeId = _challengeId;
    if (challengeId == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _verifyingOtp = true;
      _error = null;
    });
    try {
      await widget.api.verifyPartnerApplicationOtp(
        phone: _phone.text.trim(),
        challengeId: challengeId,
        otp: _otp.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _phoneVerified = true;
        _verifyingOtp = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _verifyingOtp = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_services.isEmpty) {
      setState(() => _error = 'Select at least one service.');
      return;
    }
    if (_otpRequired && !_phoneVerified) {
      setState(() => _error = 'Verify your mobile number before continuing.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await widget.api.submitPartnerApplication(
        application: {
          'businessName': _businessName.text.trim(),
          'partnerType': _partnerType,
          'phone': _phone.text.trim(),
          if (_otpRequired) 'phoneChallengeId': _challengeId,
          'whatsapp': _whatsapp.text.trim(),
          'email': _email.text.trim(),
          'zone': _zone.text.trim(),
          'address': _address.text.trim(),
          'serviceCodes': _services.toList(),
          'vehicleCount': int.parse(_vehicleCount.text.trim()),
          'registration': _registration.text.trim(),
          'capacity': _capacity.text.trim(),
          if (_experience.text.trim().isNotEmpty)
            'experience': int.parse(_experience.text.trim()),
          'availability': _availability,
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFlags) {
      return const AppScaffold(
        title: 'Become a partner',
        body: Center(child: SkeletonBox(height: 340)),
      );
    }
    if (_flagsError != null) {
      return AppScaffold(
        title: 'Become a partner',
        body: ErrorState(
          error: _flagsError!,
          message: _flagsError,
          onRetry: _loadFlags,
        ),
      );
    }
    final receipt = _receipt;
    if (receipt != null) {
      return AppScaffold(
        title: 'Application submitted',
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: SurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: context.colors.success.fg,
                    size: 64,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Thanks for applying.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(receipt.message, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Reference: ${receipt.reference}',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  PrimaryButton(
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Become a partner',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          children: [
            Text(
              'Grow your business with Urban Tanker',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Share your business details. Our team will review your '
              'application and contact you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            _section(
              context,
              title: 'Business details',
              children: [
                _field(
                  _businessName,
                  'Business name',
                  validator: _required,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: _partnerType,
                  decoration: const InputDecoration(labelText: 'Partner type'),
                  items: [
                    for (final type in _partnerTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (value) => setState(() => _partnerType = value),
                ),
                const SizedBox(height: AppSpace.md),
                _field(
                  _zone,
                  'Service area',
                  validator: _required,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpace.md),
                _field(
                  _address,
                  'Business address',
                  validator: (value) => (value ?? '').trim().length < 5
                      ? 'Enter a complete address.'
                      : null,
                  capitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _section(
              context,
              title: 'Contact details',
              children: [
                _field(
                  _phone,
                  'Mobile number',
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) =>
                      RegExp(r'^\d{10}$').hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter a valid 10-digit mobile number.',
                  onChanged: _phoneChanged,
                ),
                if (_otpRequired) ...[
                  const SizedBox(height: AppSpace.md),
                  if (_phoneVerified)
                    StatusChip(
                      label: 'Mobile verified',
                      tone: context.colors.success,
                    )
                  else ...[
                    if (_challengeId == null)
                      SecondaryButton(
                        label: 'Send verification code',
                        icon: Icons.sms_outlined,
                        loading: _requestingOtp,
                        onPressed: _requestingOtp ? null : _requestOtp,
                      )
                    else ...[
                      _field(
                        _otp,
                        '6-digit verification code',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) =>
                            RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                            ? null
                            : 'Enter the 6-digit code.',
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Resend code',
                              loading: _requestingOtp,
                              onPressed: _requestingOtp ? null : _requestOtp,
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Verify',
                              loading: _verifyingOtp,
                              onPressed: _verifyingOtp ? null : _verifyOtp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: AppSpace.md),
                _field(
                  _whatsapp,
                  'WhatsApp number (optional)',
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    final phone = (value ?? '').trim();
                    if (phone.isNotEmpty &&
                        !RegExp(r'^\d{10}$').hasMatch(phone)) {
                      return 'Enter a valid 10-digit number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.md),
                _field(
                  _email,
                  'Email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = (value ?? '').trim();
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                        ? null
                        : 'Enter a valid email address.';
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _section(
              context,
              title: 'Services',
              children: [
                for (final service in _partnerServices)
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _services.contains(service),
                      title: Text(service),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _submitting
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _services.add(service);
                              } else {
                                _services.remove(service);
                              }
                            }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _section(
              context,
              title: 'Fleet and availability',
              children: [
                _field(
                  _vehicleCount,
                  'Number of vehicles',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    final count = int.tryParse((value ?? '').trim());
                    return count != null && count > 0 && count <= 250
                        ? null
                        : 'Enter a number from 1 to 250.';
                  },
                ),
                const SizedBox(height: AppSpace.md),
                _field(
                  _registration,
                  'Primary vehicle registration',
                  validator: (value) => (value ?? '').trim().length >= 3
                      ? null
                      : 'Enter a valid vehicle registration.',
                  capitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: AppSpace.md),
                _field(_capacity, 'Vehicle capacity', validator: _required),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: _availability,
                  decoration: const InputDecoration(labelText: 'Availability'),
                  items: [
                    for (final value in _availabilityOptions)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => _availability = value),
                ),
                const SizedBox(height: AppSpace.md),
                _field(
                  _experience,
                  'Years of experience (optional)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final years = int.tryParse(text);
                    return years != null && years <= 75
                        ? null
                        : 'Enter a value from 0 to 75.';
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _section(
              context,
              title: 'Additional information',
              children: [
                _field(
                  _notes,
                  'Notes (optional)',
                  capitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              _InlineError(message: _error!),
            ],
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: 'Submit application',
              icon: Icons.send_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpace.xl),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    FormFieldValidator<String>? validator,
    String? prefixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization capitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
    int? minLines,
    int maxLines = 1,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      validator: validator,
      prefixText: prefixText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: capitalization,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required.' : null;
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.danger;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(color: tone.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tone.fg),
          ),
        ),
      ),
    );
  }
}
