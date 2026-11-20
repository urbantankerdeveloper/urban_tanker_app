import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/auth_feature_flags.dart';
import '../../app/app_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../services/api_client.dart';
import '../../services/friendly_error.dart';

Future<PhoneVerificationResult?> showPhoneVerifyDialog(
  BuildContext context, {
  required AppController controller,
  required bool allowSkip,
  bool requireProfileRefresh = false,
  String? initialPhone,
}) async {
  final result = await showDialog<PhoneVerificationResult>(
    context: context,
    barrierDismissible: allowSkip,
    builder: (_) => PhoneVerifyDialog(
      api: controller.api,
      initialPhone: initialPhone,
      allowSkip: allowSkip,
    ),
  );
  if (result == null) return null;

  controller.markPhoneVerified(result.phone);
  final refreshed = await controller.refreshUserProfile();
  if (!context.mounted) return result;
  final message = refreshed
      ? 'Phone number verified.'
      : 'Phone verified. Your profile could not refresh; please try again.';
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
  if (!refreshed && requireProfileRefresh) {
    throw StateError('Your profile could not refresh. Please try again.');
  }
  return result;
}

Future<T> runWithPhoneVerificationRetry<T>(
  BuildContext context, {
  required AppController controller,
  required Future<T> Function() action,
  bool? enabled,
}) async {
  try {
    return await action();
  } on ApiException catch (error) {
    if (!(enabled ?? AuthFeatureFlags.phoneVerifyDialog) ||
        error.code != 'PHONE_NOT_VERIFIED' ||
        !context.mounted) {
      rethrow;
    }
    final result = await showPhoneVerifyDialog(
      context,
      controller: controller,
      allowSkip: false,
      requireProfileRefresh: true,
      initialPhone: controller.user?.phone,
    );
    if (result == null || !context.mounted) rethrow;

    if (controller.user?.phoneVerified != true) {
      throw StateError('Verify your account phone number before continuing.');
    }
    return action();
  }
}

class PhoneVerifyDialog extends StatefulWidget {
  const PhoneVerifyDialog({
    required this.api,
    this.initialPhone,
    this.allowSkip = false,
    super.key,
  });

  final ApiClient api;
  final String? initialPhone;
  final bool allowSkip;

  @override
  State<PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends State<PhoneVerifyDialog> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _timer;
  Timer? _expiryTimer;
  Timer? _lockoutTimer;
  int _resendSeconds = 0;
  int _expiresSeconds = 0;
  int _lockoutSeconds = 0;
  bool _codeStep = false;
  bool _busy = false;
  late bool _canPop;
  String? _error;
  PhoneOtpChannel? _channel;

  @override
  void initState() {
    super.initState();
    _canPop = widget.allowSkip;
    _phoneController.text = _digits(widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    _lockoutTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _digits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }

  String get _phone => _digits(_phoneController.text);

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _startExpiryCountdown(int seconds) {
    _expiryTimer?.cancel();
    setState(() => _expiresSeconds = seconds);
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expiresSeconds <= 1) {
        timer.cancel();
        setState(() {
          _expiresSeconds = 0;
          _error = 'This code has expired. Request a new code.';
        });
      } else {
        setState(() => _expiresSeconds -= 1);
      }
    });
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() => _lockoutSeconds = 0);
      } else {
        setState(() => _lockoutSeconds -= 1);
      }
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = _errorMessage(error));
    if (error is ApiException &&
        (error.statusCode == 423 || error.statusCode == 429)) {
      _startLockoutCountdown(
        error.retryAfterSeconds ?? (error.statusCode == 423 ? 60 : 30),
      );
    }
  }

  String _formatCountdown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.requestAccountPhoneVerification(_phone);
      if (!mounted) return;
      _channel = result.channel;
      _codeController.clear();
      setState(() => _codeStep = true);
      _startCountdown(
        result.resendAfterSeconds > 0 ? result.resendAfterSeconds : 30,
      );
      _startExpiryCountdown(
        result.expiresInSeconds > 0
            ? result.expiresInSeconds.clamp(1, 300).toInt()
            : 300,
      );
      unawaited(HapticFeedback.selectionClick());
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.confirmAccountPhoneVerification(
        phone: _phone,
        code: _codeController.text,
      );
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) {
        setState(() => _canPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop(result);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(Object error) {
    return friendlyError(error);
  }

  void _changeNumber() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    _lockoutTimer?.cancel();
    _codeController.clear();
    setState(() {
      _codeStep = false;
      _resendSeconds = 0;
      _expiresSeconds = 0;
      _lockoutSeconds = 0;
      _error = null;
      _channel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return PopScope(
      canPop: _canPop,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify your phone number',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  _codeStep
                      ? 'Enter the 6-digit code sent to your phone.'
                      : 'Add a phone number so we can keep your account secure.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.lg),
                if (!_codeStep) ...[
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixText: '+91 ',
                      hintText: '10-digit mobile number',
                    ),
                    onChanged: (_) {
                      setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed:
                        _busy || _lockoutSeconds > 0 || _phone.length != 10
                            ? null
                            : _sendCode,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send code'),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        _channel == PhoneOtpChannel.sms
                            ? Icons.sms_outlined
                            : Icons.chat_rounded,
                        color: _channel == PhoneOtpChannel.whatsapp
                            ? const Color(0xFF25D366)
                            : colors.primary,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          'We sent a code via '
                          '${_channel == PhoneOtpChannel.sms ? 'SMS' : 'WhatsApp'} '
                          'to +91 $_phone.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    _expiresSeconds > 0
                        ? 'Code expires in ${_formatCountdown(_expiresSeconds)}.'
                        : 'Code expired. Request a new one.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  OtpField(
                    controller: _codeController,
                    onChanged: (_) {
                      setState(() => _error = null);
                    },
                    autofocus: true,
                    autofillOneTimeCode: false,
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed: _busy ||
                            _lockoutSeconds > 0 ||
                            _expiresSeconds == 0 ||
                            _codeController.text.length != 6
                        ? null
                        : _verify,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            _busy || _lockoutSeconds > 0 ? null : _changeNumber,
                        child: const Text('Change number'),
                      ),
                      TextButton(
                        onPressed:
                            _busy || _resendSeconds > 0 || _lockoutSeconds > 0
                                ? null
                                : _sendCode,
                        child: Text(
                          _resendSeconds > 0
                              ? 'Resend in $_resendSeconds s'
                              : 'Resend code',
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.danger.fg,
                    ),
                  ),
                ],
                if (_lockoutSeconds > 0) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Please wait $_lockoutSeconds seconds before trying again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.danger.fg,
                    ),
                  ),
                ],
                if (widget.allowSkip) ...[
                  const SizedBox(height: AppSpace.sm),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Skip for now'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
