import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/design_system/design_system.dart';
import '../models/account.dart';
import '../services/api_client.dart';
import '../services/friendly_error.dart';

enum _CodeKind { email, phone }

Future<void> showUserProfileDialog({
  required BuildContext context,
  required ApiClient api,
  required String name,
  required String role,
  String? username,
  String? email,
  String? phone,
  required Future<String?> profilePhotoUrl,
  String? initialProfilePhotoUrl,
  required Future<void> Function(CustomerProfile profile) onSaved,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ProfileDialog(
        api: api,
        name: name,
        role: role,
        username: username,
        email: email ?? '',
        phone: phone ?? '',
        profilePhotoUrl: profilePhotoUrl,
        initialProfilePhotoUrl: initialProfilePhotoUrl,
        onSaved: onSaved,
      ),
    );

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.api,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.profilePhotoUrl,
    required this.initialProfilePhotoUrl,
    required this.onSaved,
    this.username,
  });

  final ApiClient api;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String? username;
  final Future<String?> profilePhotoUrl;
  final String? initialProfilePhotoUrl;
  final Future<void> Function(CustomerProfile profile) onSaved;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late Future<String?> _profilePhotoUrl;
  late final TextEditingController _name =
      TextEditingController(text: widget.name);
  late final TextEditingController _email =
      TextEditingController(text: widget.email);
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone.replaceAll(RegExp(r'\D'), '').sliceLast10,
  );
  late final TextEditingController _username =
      TextEditingController(text: widget.username ?? '');
  final TextEditingController _otp = TextEditingController();
  String? _emailChallengeId;
  String? _phoneChallengeId;
  String? _error;
  String? _notice;
  String? _photoError;
  Uint8List? _photoBytes;
  bool _editing = false;
  bool _busy = false;
  bool _emailVerified = false;
  bool _phoneVerified = false;
  PhoneOtpChannel? _phoneChannel;
  _CodeKind? _codeKind;

  @override
  void initState() {
    super.initState();
    _profilePhotoUrl = widget.profilePhotoUrl;
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != widget.email.trim().toLowerCase();
  bool get _phoneChanged =>
      _phone.text.replaceAll(RegExp(r'\D'), '').sliceLast10 !=
      widget.phone.replaceAll(RegExp(r'\D'), '').sliceLast10;
  String get _normalizedPhone =>
      _phone.text.replaceAll(RegExp(r'\D'), '').sliceLast10;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _username.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        setState(() => _error = 'The photo is larger than 3 MB.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoError = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Future<void> _sendCode(_CodeKind kind) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (kind == _CodeKind.email) {
        _emailChallengeId =
            await widget.api.requestEmailLinkCode(_email.text.trim());
      } else {
        final challenge =
            await widget.api.requestBookingOtp(phone: _normalizedPhone);
        if (challenge.challengeId == null || challenge.channel == null) {
          throw const FormatException(
              'A code could not be sent to this number.');
        }
        _phoneChallengeId = challenge.challengeId;
        _phoneChannel = challenge.channel;
      }
      _otp.clear();
      setState(() => _codeKind = kind);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_codeKind == _CodeKind.email && _emailChallengeId != null) {
        await widget.api.confirmEmailLinkCode(
          email: _email.text.trim(),
          challengeId: _emailChallengeId!,
          otp: code,
        );
        _emailVerified = true;
        _notice = 'Email verified.';
      } else if (_codeKind == _CodeKind.phone && _phoneChallengeId != null) {
        await widget.api.verifyPhoneOtp(
          phone: _normalizedPhone,
          challengeId: _phoneChallengeId,
          otp: code,
        );
        _phoneVerified = true;
        _notice = 'Phone number verified.';
      } else {
        throw const FormatException('Request a new verification code.');
      }
      setState(() => _codeKind = null);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_emailChanged && !_emailVerified) {
      setState(() => _error = 'Verify the new email address before saving.');
      return;
    }
    if (_phoneChanged && !_phoneVerified) {
      setState(() => _error = 'Verify the new phone number before saving.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.api.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phoneChanged ? _normalizedPhone : null,
        phoneVerificationChallengeId: _phoneChanged ? _phoneChallengeId : null,
        emailVerificationChallengeId: _emailChanged ? _emailChallengeId : null,
      );
      await widget.onSaved(saved);
      if (_photoBytes != null) {
        try {
          await widget.api.uploadCustomerSelfie(bytes: _photoBytes!);
          _profilePhotoUrl = widget.api.profileSelfieUrl();
        } catch (error) {
          setState(() {
            _editing = false;
            _photoError =
                'Profile details saved, but the photo could not be saved: ${friendlyError(error)}';
          });
          return;
        }
      }
      setState(() {
        _editing = false;
        _photoBytes = null;
        _emailChallengeId = null;
        _phoneChallengeId = null;
        _emailVerified = false;
        _phoneVerified = false;
        _notice = 'Profile saved successfully.';
      });
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _name.text = widget.name;
      _email.text = widget.email;
      _phone.text = widget.phone.replaceAll(RegExp(r'\D'), '').sliceLast10;
      _photoBytes = null;
      _emailChallengeId = null;
      _phoneChallengeId = null;
      _emailVerified = false;
      _phoneVerified = false;
      _codeKind = null;
      _error = null;
      _notice = null;
      _photoError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              FutureBuilder<String?>(
                future: _profilePhotoUrl,
                builder: (context, snapshot) => Column(
                  children: [
                    if (_photoBytes != null)
                      ClipOval(
                        child: Image.memory(
                          _photoBytes!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      AppAvatar(
                        name: _name.text,
                        imageUrl:
                            snapshot.data ?? widget.initialProfilePhotoUrl,
                        size: 88,
                      ),
                    if (snapshot.hasError)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpace.sm),
                        child: Text('Profile photo could not be loaded.'),
                      ),
                  ],
                ),
              ),
              if (_editing)
                TextButton.icon(
                  onPressed: _busy ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Change profile picture'),
                ),
              Text(
                widget.role[0].toUpperCase() + widget.role.substring(1),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpace.md),
              _field('Full name', _name, enabled: _editing && !_busy),
              const SizedBox(height: AppSpace.sm),
              _field(
                'Email',
                _email,
                enabled: _editing && !_busy,
                keyboardType: TextInputType.emailAddress,
                suffix: _editing && _emailChanged
                    ? _verifyButton(
                        _emailVerified,
                        () => _sendCode(_CodeKind.email),
                      )
                    : null,
                onChanged: (_) => setState(() {
                  _emailVerified = false;
                  _emailChallengeId = null;
                }),
              ),
              const SizedBox(height: AppSpace.sm),
              _field(
                'Mobile number',
                _phone,
                enabled: _editing && !_busy,
                keyboardType: TextInputType.phone,
                prefix: const Padding(
                  padding: EdgeInsets.only(right: AppSpace.sm),
                  child: Text('+91'),
                ),
                suffix: _editing && _phoneChanged
                    ? _verifyButton(
                        _phoneVerified,
                        () => _sendCode(_CodeKind.phone),
                      )
                    : null,
                onChanged: (_) => setState(() {
                  _phoneVerified = false;
                  _phoneChallengeId = null;
                }),
              ),
              if (widget.username?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpace.sm),
                _field(
                  'Username',
                  _username,
                  enabled: false,
                ),
              ],
              if (_editing && _codeKind != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  _codeKind == _CodeKind.email
                      ? 'Enter the code sent to ${_email.text}.'
                      : 'Code sent via ${_phoneChannel == PhoneOtpChannel.whatsapp ? 'WhatsApp' : 'SMS'} to +91 $_normalizedPhone.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _otp,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    counterText: '',
                  ),
                ),
                PrimaryButton(
                  label: 'Verify code',
                  loading: _busy,
                  onPressed: _busy ? null : _verifyCode,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_error!, style: TextStyle(color: colors.danger.fg)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_notice!, style: TextStyle(color: colors.success.fg)),
              ],
              if (_photoError != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_photoError!, style: TextStyle(color: colors.danger.fg)),
              ],
              const SizedBox(height: AppSpace.lg),
              if (_editing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    PrimaryButton(
                      label: 'Save profile',
                      loading: _busy,
                      onPressed: _busy ? null : _save,
                    ),
                  ],
                )
              else
                PrimaryButton(
                  label: 'Edit profile',
                  onPressed: () => setState(() {
                    _editing = true;
                    _notice = null;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verifyButton(bool verified, VoidCallback onPressed) => TextButton(
        onPressed: _busy || verified ? null : onPressed,
        child: verified
            ? Icon(Icons.check_circle, color: context.colors.success.fg)
            : const Text('Send code'),
      );

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool enabled,
    TextInputType? keyboardType,
    Widget? prefix,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefix: prefix,
          suffixIcon: suffix,
        ),
      );
}

extension on String {
  String get sliceLast10 => length > 10 ? substring(length - 10) : this;
}
