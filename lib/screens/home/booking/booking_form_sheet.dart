import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/app_controller.dart';
import '../../../app/auth_feature_flags.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../models/booking.dart';
import '../../../models/booking_service_details.dart';
import '../../../models/booking_service_form.dart';
import '../../../models/service.dart';
import '../../../services/api_client.dart';
import '../../../services/friendly_error.dart';
import '../../../services/masking.dart';
import '../../../services/payment/online_payment_flow.dart';
import '../../../services/payment/payment_checkout.dart';
import '../../../services/service_area.dart';
import '../../booking_details_screen.dart';
import '../../common/booking_format.dart';
import '../../auth/phone_verify_dialog.dart';
import 'booking_fields.dart';
import 'live_quote_summary.dart';

typedef _VerifiedBookingContact = ({String phone, String? challengeId});

Future<_VerifiedBookingContact?> _showBookingPhoneVerificationDialog(
  BuildContext context,
  ApiClient api,
  String initialPhone,
  String? fallbackEmail,
) {
  return showDialog<_VerifiedBookingContact>(
    context: context,
    builder: (_) => _BookingPhoneVerificationDialog(
      api: api,
      initialPhone: initialPhone,
      fallbackEmail: fallbackEmail,
    ),
  );
}

class _BookingPhoneVerificationDialog extends StatefulWidget {
  const _BookingPhoneVerificationDialog({
    required this.api,
    required this.initialPhone,
    required this.fallbackEmail,
  });

  final ApiClient api;
  final String initialPhone;
  final String? fallbackEmail;

  @override
  State<_BookingPhoneVerificationDialog> createState() =>
      _BookingPhoneVerificationDialogState();
}

class _BookingPhoneVerificationDialogState
    extends State<_BookingPhoneVerificationDialog> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone);
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  String? _challengeId;
  String? _emailChallengeId;
  PhoneOtpChannel? _channel;
  bool _usingEmailFallback = false;
  String? _error;
  bool _busy = false;
  int _resendSeconds = 0;

  String get _otp => _digits.map((digit) => digit.text).join();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_sendCode());
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    for (final digit in _digits) {
      digit.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _clearCode() {
    for (final digit in _digits) {
      digit.clear();
    }
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      for (var offset = 0;
          offset < digits.length && index + offset < 6;
          offset++) {
        _digits[index + offset].text = digits[offset];
      }
      final nextIndex = (index + digits.length).clamp(0, 5).toInt();
      _focusNodes[nextIndex].requestFocus();
    } else if (digits.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _error = null);
  }

  Future<void> _sendCode() async {
    final phone = normalizeIndianPhone(_phone.text);
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.requestBookingOtp(phone: phone);
      if (!mounted) return;
      if (result.challengeId == null) {
        setState(() => _error = 'A code could not be sent to this number.');
        return;
      }
      setState(() {
        _challengeId = result.challengeId;
        _emailChallengeId = null;
        _usingEmailFallback = false;
        _channel = result.channel;
        _clearCode();
      });
      _startResendTimer(result.resendAfterSeconds);
    } catch (error) {
      final canUseEmailFallback = widget.fallbackEmail != null &&
          widget.fallbackEmail!.trim().isNotEmpty &&
          error is ApiException &&
          error.statusCode == 503 &&
          (error.message == 'Mobile verification is not configured yet.' ||
              error.message == 'OTP delivery failed.');
      if (!canUseEmailFallback) {
        if (mounted) setState(() => _error = friendlyError(error));
        return;
      }
      try {
        final emailChallengeId =
            await widget.api.requestRegisteredBookingEmailOtp(phone: phone);
        if (!mounted) return;
        setState(() {
          _challengeId = null;
          _emailChallengeId = emailChallengeId;
          _usingEmailFallback = true;
          _channel = null;
          _clearCode();
        });
        _startResendTimer(30);
      } catch (fallbackError) {
        if (mounted) setState(() => _error = friendlyError(fallbackError));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final challengeId = _challengeId;
    final emailChallengeId = _emailChallengeId;
    final phone = normalizeIndianPhone(_phone.text);
    if (challengeId == null && emailChallengeId == null) {
      setState(() => _error = 'Send a verification code first.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_otp)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.verifyPhoneOtp(
        phone: phone,
        challengeId: challengeId,
        otp: challengeId == null ? null : _otp,
        email: _usingEmailFallback ? widget.fallbackEmail : null,
        emailChallengeId: emailChallengeId,
        emailOtp: _usingEmailFallback ? _otp : null,
      );
      if (mounted) {
        Navigator.pop(
          context,
          (
            phone: phone,
            challengeId: challengeId,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        title: 'Verify booking phone',
        message: 'Verify the contact number before confirming your booking.',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phone,
              enabled: _challengeId == null && !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number'),
              onChanged: (_) => setState(() {
                _resendTimer?.cancel();
                _resendSeconds = 0;
                _challengeId = null;
                _emailChallengeId = null;
                _channel = null;
                _usingEmailFallback = false;
                _clearCode();
                _error = null;
              }),
            ),
            if (_challengeId != null || _emailChallengeId != null) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Icon(
                    _channel == PhoneOtpChannel.whatsapp
                        ? Icons.chat_outlined
                        : Icons.sms_outlined,
                    color: _channel == PhoneOtpChannel.whatsapp
                        ? const Color(0xFF25D366)
                        : context.colors.primary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      _usingEmailFallback
                          ? 'Phone delivery is unavailable. We sent a code to ${widget.fallbackEmail}.'
                          : 'We sent a code${_channel == null ? '' : ' via ${_channel == PhoneOtpChannel.whatsapp ? 'WhatsApp' : 'SMS'}'} to +91 ${maskPhone(_phone.text)}.',
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _challengeId = null;
                            _emailChallengeId = null;
                            _channel = null;
                            _usingEmailFallback = false;
                            _error = null;
                            _resendTimer?.cancel();
                            _resendSeconds = 0;
                            _clearCode();
                          }),
                  child: const Text('Change number'),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < _digits.length; index++)
                    SizedBox(
                      width: 42,
                      child: TextField(
                        key: Key('booking-otp-digit-$index'),
                        controller: _digits[index],
                        focusNode: _focusNodes[index],
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofillHints:
                            index == 0 && _channel == PhoneOtpChannel.sms
                                ? const [AutofillHints.oneTimeCode]
                                : null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpace.md,
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy || _resendSeconds > 0 ? null : _sendCode,
                  child: Text(_resendSeconds > 0
                      ? 'Resend in $_resendSeconds s'
                      : 'Resend code'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                _error!,
                style: TextStyle(color: context.colors.danger.fg),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: _busy ||
                    _resendSeconds > 0 ||
                    (_challengeId != null || _emailChallengeId != null)
                ? null
                : _sendCode,
            child: Text(_challengeId == null && _emailChallengeId == null
                ? 'Send code'
                : 'Code sent'),
          ),
          PrimaryButton(
            label: 'Verify number',
            loading: _busy,
            onPressed: _busy ? null : _verify,
          ),
        ],
      );
}

class _BookingFormControllerScope extends StatefulWidget {
  const _BookingFormControllerScope({
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_BookingFormControllerScope> createState() =>
      _BookingFormControllerScopeState();
}

class _BookingFormControllerScopeState
    extends State<_BookingFormControllerScope> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _paymentMethodLabel(String method) => switch (method) {
      'wallet' => 'Wallet',
      'gateway' => 'Online payment',
      _ => 'Cash on delivery',
    };

Future<void> openBookingForm(
  BuildContext context, {
  required AppController controller,
  required List<TankerService> serviceCatalog,
  Booking? previousBooking,
  VoidCallback? onReturnHome,
  VoidCallback? onBookingCompleted,
}) async {
  if (serviceCatalog.isEmpty) return;
  List<AccountRecord> addresses = const [];
  try {
    addresses = await controller.api.addresses();
  } catch (_) {
    // Saved addresses are optional; manual entry remains available.
  }
  if (!context.mounted) return;
  final couponController = TextEditingController();
  final notesController =
      TextEditingController(text: previousBooking?.notes ?? '');
  final phoneController = TextEditingController();
  String? selectedAddress;
  final previousDetails = {
    for (final detail in previousBooking?.services ?? <BookingServiceDetails>[])
      detail.serviceId: detail,
  };
  final serviceFields = {
    for (final service in serviceCatalog)
      service.id: BookingServiceFields(
        quantity: previousDetails[service.id]?.quantity ??
            (previousBooking == null && service.capacityOptions.isNotEmpty
                ? service.capacityOptions.first
                : AuthFeatureFlags.multiServiceOrders &&
                        service.minQuantity != null
                    ? service.minQuantity!.toString()
                    : ''),
        details: previousDetails[service.id]?.details ?? '',
        location: previousDetails[service.id]?.location ??
            (previousBooking?.location ?? selectedAddress ?? ''),
        deliveryDate: previousDetails[service.id]?.deliveryDate ??
            dateOnly(previousBooking?.deliveryDate ??
                DateTime.now().add(const Duration(days: 1))),
        latitude: previousDetails[service.id]?.latitude,
        longitude: previousDetails[service.id]?.longitude,
        waterType: previousDetails[service.id]?.waterType ?? '',
        tankerCount: previousDetails[service.id]?.tankerCount ?? '',
      ),
  };
  final previousServiceIds = previousDetails.keys
      .where((id) => serviceCatalog.any((service) => service.id == id))
      .toSet();
  if (previousServiceIds.isEmpty &&
      previousBooking?.serviceId != null &&
      serviceCatalog
          .any((service) => service.id == previousBooking!.serviceId)) {
    previousServiceIds.add(previousBooking!.serviceId!);
    final previousService = previousDetails[previousBooking.serviceId];
    if (previousService != null) {
      serviceFields[previousBooking.serviceId]!
        ..quantity.text = previousService.quantity
        ..details.text = previousService.details;
    } else if (previousBooking.capacity.isNotEmpty) {
      serviceFields[previousBooking.serviceId]!.quantity.text =
          previousBooking.capacity;
    }
  }
  final selectedServices =
      previousServiceIds.isNotEmpty ? previousServiceIds : <String>{};
  for (final address in addresses) {
    if (address.detail == previousBooking?.location) {
      selectedAddress = address.detail;
      break;
    }
  }
  AccountRecord? selectedAddressRecord;
  for (final address in addresses) {
    if (address.detail == selectedAddress) {
      selectedAddressRecord = address;
      break;
    }
  }
  for (final fields in serviceFields.values) {
    if (fields.location.text.trim().isEmpty && selectedAddress != null) {
      fields.location.text = selectedAddress;
    }
    if (fields.latitude == null && selectedAddressRecord != null) {
      fields.latitude = selectedAddressRecord.latitude;
      fields.longitude = selectedAddressRecord.longitude;
    }
  }
  Map<String, dynamic>? validatedCoupon;
  String? couponMessage;
  String? bookingFormError;
  String? bookingFormNotice;
  String? phoneChallengeId;
  String? verifiedPhone;
  var phoneVerified = false;
  var validatingCoupon = false;
  var submittingBooking = false;
  var requestingPhoneCode = false;
  var bookingContactPhone = '';
  var bookingContactEmail = '';
  String? bookingKey;
  String? bookingKeyFingerprint;
  String? paymentMethod;
  void disposeFormControllers() {
    couponController.dispose();
    notesController.dispose();
    phoneController.dispose();
    for (final fields in serviceFields.values) {
      fields.dispose();
    }
  }

  verifiedPhone = null;
  phoneVerified = false;
  final user = controller.user;
  if (AuthFeatureFlags.phoneVerifyDialog &&
      user != null &&
      user.phoneVerified != true) {
    final verified = await showPhoneVerifyDialog(
      context,
      controller: controller,
      allowSkip: user.phoneVerificationRequired == false,
      initialPhone: '',
    );
    if (!context.mounted) {
      disposeFormControllers();
      return;
    }
    if (verified == null && user.phoneVerificationRequired != false) {
      disposeFormControllers();
      return;
    }
    if (verified != null) {
      phoneController.text = verified.phone;
    }
  }
  if (!context.mounted) {
    disposeFormControllers();
    return;
  }
  bool serviceHasMissingFields(String id) {
    final fields = serviceFields[id]!;
    final service = serviceCatalog.firstWhere((item) => item.id == id);
    final serviceSpecificMissing = id == 'water_tanker'
        ? fields.waterType.text.trim().isEmpty ||
            fields.tankerCount.text.trim().isEmpty
        : fields.details.text.trim().isEmpty;
    final quantity = double.tryParse(fields.quantity.text.trim());
    final quantityValid = service.capacityOptions.isNotEmpty
        ? service.capacityOptions.contains(fields.quantity.text)
        : AuthFeatureFlags.multiServiceOrders &&
            quantity != null &&
            quantity >= (service.minQuantity ?? 1) &&
            quantity <= (service.maxQuantity ?? double.infinity);
    return !quantityValid ||
        serviceSpecificMissing ||
        fields.location.text.trim().isEmpty ||
        !isChennaiLocation(
          address: fields.location.text,
          latitude: fields.latitude,
          longitude: fields.longitude,
        ) ||
        DateTime.tryParse(fields.deliveryDate.text.trim()) == null ||
        (id == 'water_tanker' &&
            (!service.waterTypeOptions.contains(fields.waterType.text) ||
                !service.tankerCountOptions.contains(fields.tankerCount.text)));
  }

  List<BookingServiceDetails> buildServiceDetails() =>
      selectedServices.map((serviceId) {
        final fields = serviceFields[serviceId]!;
        return BookingServiceDetails(
          serviceId: serviceId,
          quantity: fields.quantity.text,
          waterType: fields.waterType.text,
          tankerCount: fields.tankerCount.text,
          details: fields.details.text,
          deliveryDate: fields.deliveryDate.text.trim(),
          location: fields.location.text.trim(),
          latitude: fields.latitude,
          longitude: fields.longitude,
        );
      }).toList(growable: false);

  final steps = [
    'Contact',
    'Services',
    'Location',
    'Date',
    'Payment',
    'Review',
  ];
  // One form per step. Next validates only the step on screen, and every
  // field is checked again before a booking is submitted.
  final stepKeys = [
    for (var i = 0; i < steps.length; i++) GlobalKey<FormState>()
  ];
  var step = 0;
  double? quoteTotal;

  final result = await showAppBottomSheet<Map<String, dynamic>>(
    context,
    builder: (context) => _BookingFormControllerScope(
      controllers: [
        couponController,
        notesController,
        phoneController,
        for (final fields in serviceFields.values) ...[
          fields.quantity,
          fields.waterType,
          fields.tankerCount,
          fields.details,
          fields.location,
          fields.deliveryDate,
        ],
      ],
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = context.colors;
          final theme = Theme.of(context);
          final lastStep = steps.length - 1;

          void goTo(int next) => setSheetState(() {
                step = next;
                bookingFormError = null;
              });

          void goNext() {
            final form = stepKeys[step].currentState;
            if (form != null && !form.validate()) return;
            if (step == 1 && selectedServices.isEmpty) {
              setSheetState(
                () => bookingFormError = 'Select at least one service.',
              );
              return;
            }
            goTo(step + 1);
          }

          bool canSubmit() => !(submittingBooking ||
              paymentMethod == null ||
              selectedServices.isEmpty ||
              !phoneVerified ||
              selectedServices.any(serviceHasMissingFields));

          Future<void> submit() async {
            if (selectedServices.isEmpty) {
              setSheetState(
                () => bookingFormError = 'Select at least one service.',
              );
              return;
            }
            final form = stepKeys[step].currentState;
            if (form != null && !form.validate()) return;
            final method = paymentMethod;
            if (method == null) {
              setSheetState(() {
                bookingFormError = 'Choose a payment method.';
                step = steps.indexOf('Payment');
              });
              return;
            }
            setSheetState(() => submittingBooking = true);
            var bookingContactRecoveryUsed = false;
            try {
              final services = buildServiceDetails();
              final quotePreview = await runWithPhoneVerificationRetry(
                context,
                controller: controller,
                action: () => controller.api.previewBookingQuote(
                  serviceId: services.first.serviceId,
                  capacity: services.first.quantity,
                  services: services,
                  location: services.first.location ?? '',
                  deliveryDate: services.first.deliveryDate ?? '',
                  notes: notesController.text,
                  paymentMethod: method,
                  latitude: services.first.latitude,
                  longitude: services.first.longitude,
                  couponCode: validatedCoupon == null
                      ? null
                      : couponController.text.trim(),
                  phone: phoneController.text,
                  phoneVerificationChallengeId: phoneChallengeId,
                ),
              );
              if (!context.mounted) return;
              final quote = quotePreview['quote'];
              final selectedServiceNames = selectedServices.map(
                (id) => serviceCatalog
                    .firstWhere((service) => service.id == id)
                    .name,
              );
              while (true) {
                if (!context.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AppDialog(
                    title: 'Confirm booking quote',
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var index = 0;
                              index < services.length;
                              index++) ...[
                            Text(
                              selectedServiceNames.elementAt(index),
                              style: theme.textTheme.titleSmall,
                            ),
                            if (services[index].quantity.trim().isNotEmpty)
                              Text(
                                'Quantity/capacity: ${services[index].quantity.trim()}',
                              ),
                            if (services[index].waterType?.trim().isNotEmpty ==
                                true)
                              Text('Water type: ${services[index].waterType}'),
                            if (services[index]
                                    .tankerCount
                                    ?.trim()
                                    .isNotEmpty ==
                                true)
                              Text(
                                  'Tanker count: ${services[index].tankerCount}'),
                            Text('Details: ${services[index].details.trim()}'),
                            const SizedBox(height: AppSpace.sm),
                          ],
                          Text(formatQuoteSummary(quote)),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Review'),
                      ),
                      SizedBox(
                        width: 240,
                        height: AppSize.buttonHeight,
                        child: SlideToConfirm(
                          label: 'confirm booking',
                          onConfirmed: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;

                final keyFingerprint = jsonEncode([
                  for (final service in services) service.toJson(),
                  notesController.text,
                  phoneController.text,
                  validatedCoupon == null ? null : couponController.text.trim(),
                  method,
                  phoneChallengeId,
                ]);
                if (keyFingerprint != bookingKeyFingerprint) {
                  bookingKeyFingerprint = keyFingerprint;
                  bookingKey = newIdempotencyKey();
                }
                try {
                  final booking = await runWithPhoneVerificationRetry(
                    context,
                    controller: controller,
                    action: () async {
                      if (AuthFeatureFlags.multiServiceOrders) {
                        final order =
                            await controller.api.createMultiServiceOrder(
                          idempotencyKey: bookingKey!,
                          paymentMethod: method,
                          phone: phoneController.text,
                          phoneVerificationChallengeId: phoneChallengeId,
                          couponCode: validatedCoupon == null
                              ? null
                              : couponController.text.trim(),
                          items: [
                            for (final service in services)
                              {
                                'serviceId': service.serviceId,
                                'quantity': int.tryParse(
                                      service.tankerCount ?? service.quantity,
                                    ) ??
                                    1,
                                'capacity': service.quantity,
                                'location': service.location ?? '',
                                'deliveryDate': service.deliveryDate ?? '',
                                if (service.preferredTime != null &&
                                    service.preferredTime!.isNotEmpty)
                                  'slot': service.preferredTime,
                                if (service.latitude != null)
                                  'latitude': service.latitude,
                                if (service.longitude != null)
                                  'longitude': service.longitude,
                                'details': {
                                  'details': service.details,
                                  if (service.waterType != null)
                                    'waterType': service.waterType,
                                  if (service.tankerCount != null)
                                    'tankerCount': service.tankerCount,
                                },
                                if (service.waterType != null)
                                  'waterType': service.waterType,
                                if (service.tankerCount != null)
                                  'quantityText': service.tankerCount,
                              },
                          ],
                        );
                        final compatibilityId =
                            order['legacyBookingId']?.toString();
                        if (compatibilityId == null ||
                            compatibilityId.isEmpty) {
                          throw const FormatException(
                            'The multi-service order response was missing its payment booking.',
                          );
                        }
                        return {
                          ...order,
                          'order_id': order['id'],
                          'id': compatibilityId,
                        };
                      }
                      return controller.api.createBooking(
                        serviceId: services.first.serviceId,
                        capacity: services.first.quantity,
                        services: services,
                        location: services.first.location ?? '',
                        deliveryDate: services.first.deliveryDate ?? '',
                        notes: notesController.text,
                        paymentMethod: method,
                        latitude: services.first.latitude,
                        longitude: services.first.longitude,
                        couponCode: validatedCoupon == null
                            ? null
                            : couponController.text.trim(),
                        phone: phoneController.text,
                        phoneVerificationChallengeId: phoneChallengeId,
                        idempotencyKey: bookingKey,
                      );
                    },
                  );
                  booking['service_details'] =
                      services.map((service) => service.toJson()).toList();
                  booking['service_names'] = {
                    for (final serviceId in selectedServices)
                      serviceId: serviceCatalog
                          .firstWhere((service) => service.id == serviceId)
                          .name,
                  };
                  booking['coupon_code'] = validatedCoupon == null
                      ? null
                      : couponController.text.trim();
                  booking['customer_name'] =
                      controller.user?.name ?? booking['customer_name'];
                  booking['customer_phone'] = phoneController.text.trim();
                  final contactEmail = controller.user?.email?.trim();
                  if (contactEmail != null && contactEmail.isNotEmpty) {
                    booking['customer_email'] = contactEmail;
                  }
                  bookingContactPhone = phoneController.text.trim();
                  bookingContactEmail = contactEmail ?? '';
                  booking['location'] = services.first.location;
                  booking['scheduled_for'] = services.first.deliveryDate;
                  if (context.mounted) Navigator.pop(context, booking);
                  return;
                } on ApiException catch (error) {
                  const contactVerificationError =
                      'Verify the contact number for booking contact before booking.';
                  if (error.statusCode != 400 ||
                      error.message != contactVerificationError ||
                      bookingContactRecoveryUsed) {
                    rethrow;
                  }
                  bookingContactRecoveryUsed = true;
                  if (!context.mounted) return;
                  final verified = await _showBookingPhoneVerificationDialog(
                    context,
                    controller.api,
                    phoneController.text,
                    controller.user?.email,
                  );
                  if (verified == null || !context.mounted) return;
                  setSheetState(() {
                    phoneController.text = verified.phone;
                    phoneChallengeId = verified.challengeId;
                    phoneVerified = true;
                    verifiedPhone = verified.phone;
                    bookingFormError = null;
                  });
                }
              }
            } catch (error) {
              if (context.mounted) {
                showAppSnack(
                  context,
                  friendlyError(error),
                  variant: AppSnackVariant.error,
                );
              }
            } finally {
              if (context.mounted) {
                setSheetState(() => submittingBooking = false);
              }
            }
          }

          Future<void> applyCoupon() async {
            final code = couponController.text.trim();
            if (code.isEmpty) {
              setSheetState(() {
                validatedCoupon = null;
                couponMessage = 'Enter a coupon code first.';
              });
              return;
            }
            if (selectedServices.isEmpty) {
              setSheetState(
                () => couponMessage = 'Add a service before applying a coupon.',
              );
              return;
            }
            setSheetState(() {
              validatingCoupon = true;
              couponMessage = null;
            });
            try {
              final serviceId = selectedServices.first;
              final coupon = await controller.api.validateCoupon(
                code: code,
                serviceCode: serviceId,
                amount: 0,
              );
              setSheetState(() {
                validatedCoupon = coupon;
                couponMessage =
                    '${coupon['title'] ?? coupon['code'] ?? code} is valid.';
              });
            } catch (error) {
              setSheetState(() {
                validatedCoupon = null;
                couponMessage = friendlyError(error);
              });
            } finally {
              if (context.mounted) {
                setSheetState(() => validatingCoupon = false);
              }
            }
          }

          Widget couponEntry() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Coupon', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpace.sm),
                  TextFormField(
                    controller: couponController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setSheetState(() {
                      validatedCoupon = null;
                      couponMessage = null;
                    }),
                    decoration: InputDecoration(
                      labelText: 'Coupon code',
                      hintText: 'Enter code',
                      suffixIcon: validatingCoupon
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpace.md),
                              child: SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : validatedCoupon != null
                              ? IconButton(
                                  tooltip: 'Remove coupon',
                                  onPressed: () => setSheetState(() {
                                    couponController.clear();
                                    validatedCoupon = null;
                                    couponMessage = null;
                                  }),
                                  icon: const Icon(Icons.close),
                                )
                              : TextButton(
                                  onPressed: applyCoupon,
                                  child: const Text('Apply'),
                                ),
                    ),
                  ),
                  if (couponMessage != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      couponMessage!,
                      style: TextStyle(
                        color: validatedCoupon == null
                            ? colors.danger.fg
                            : colors.success.fg,
                      ),
                    ),
                  ],
                ],
              );

          Widget serviceEditor(TankerService service) {
            final fields = serviceFields[service.id]!;
            final form = BookingServiceForm.forService(service.id);
            final quantityLabel = service.unit?.trim().isNotEmpty == true
                ? service.unit!
                : form.quantityLabel;
            return SurfaceCard(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove ${service.name}',
                        onPressed: () => setSheetState(() {
                          selectedServices.remove(service.id);
                          validatedCoupon = null;
                          couponMessage = null;
                          bookingFormError = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (AuthFeatureFlags.multiServiceOrders &&
                      service.capacityOptions.isEmpty)
                    TextFormField(
                      controller: fields.quantity,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: quantityLabel,
                        helperText: service.minQuantity == null &&
                                service.maxQuantity == null
                            ? null
                            : 'Allowed range: ${service.minQuantity ?? 1} to ${service.maxQuantity ?? 'no maximum'}',
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    )
                  else
                    ServiceDropdownField(
                      controller: fields.quantity,
                      label: form.quantityLabel,
                      options: service.capacityOptions,
                      emptyMessage: 'No capacity options are configured.',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  if (service.id == 'water_tanker') ...[
                    const SizedBox(height: AppSpace.sm),
                    ServiceDropdownField(
                      controller: fields.waterType,
                      label: 'Water type',
                      options: service.waterTypeOptions,
                      emptyMessage: 'No water type options are configured.',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    ServiceDropdownField(
                      controller: fields.tankerCount,
                      label: 'Tanker count',
                      options: service.tankerCountOptions,
                      emptyMessage: 'No tanker count options are configured.',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpace.sm),
                    if (AuthFeatureFlags.multiServiceOrders &&
                        service.detailOptions.isEmpty)
                      TextFormField(
                        controller: fields.details,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: form.detailsLabel,
                          hintText: form.detailsHint,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      )
                    else
                      ServiceDropdownField(
                        controller: fields.details,
                        label: form.detailsLabel,
                        options: service.detailOptions,
                        emptyMessage:
                            'No service detail options are configured.',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                  ],
                ],
              ),
            );
          }

          Widget contactStep() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your mobile number',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'This number is shared across all selected services.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('booking-phone-number'),
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Booking phone number',
                            helperText: 'Shared across all selected services',
                            suffixIcon: phoneVerified
                                ? Icon(Icons.verified, color: colors.success.fg)
                                : null,
                          ),
                          onChanged: (_) => setSheetState(() {
                            final normalized =
                                normalizeIndianPhone(phoneController.text);
                            phoneVerified = verifiedPhone != null &&
                                normalized == verifiedPhone;
                            if (!phoneVerified) {
                              phoneChallengeId = null;
                              bookingFormNotice = null;
                            }
                            bookingFormError = null;
                          }),
                          validator: (value) {
                            final normalized =
                                normalizeIndianPhone(value ?? '');
                            return RegExp(r'^\d{10}$').hasMatch(normalized)
                                ? null
                                : 'Enter a valid 10-digit mobile number.';
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: OutlinedButton(
                          onPressed: requestingPhoneCode
                              ? null
                              : () async {
                                  setSheetState(
                                    () => requestingPhoneCode = true,
                                  );
                                  try {
                                    final verified =
                                        await _showBookingPhoneVerificationDialog(
                                      context,
                                      controller.api,
                                      phoneController.text,
                                      controller.user?.email,
                                    );
                                    if (verified != null && context.mounted) {
                                      setSheetState(() {
                                        phoneController.text = verified.phone;
                                        phoneChallengeId = verified.challengeId;
                                        phoneVerified = true;
                                        verifiedPhone = verified.phone;
                                        bookingFormError = null;
                                        bookingFormNotice =
                                            'Phone number verified.';
                                      });
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(
                                        () => requestingPhoneCode = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(
                            requestingPhoneCode ? 'Sending...' : 'Send code',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (phoneVerified)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              color: colors.success.fg),
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            'Number verified',
                            style: TextStyle(
                              color: colors.success.fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!phoneVerified) ...[
                    if (bookingFormError != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        bookingFormError!,
                        style: TextStyle(color: colors.danger.fg),
                      ),
                    ],
                    if (bookingFormNotice != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        bookingFormNotice!,
                        style: TextStyle(color: colors.success.fg),
                      ),
                    ],
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Verify this shared number before reviewing your booking.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              );

          Widget servicesStep() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Select services', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Add each service you need, then choose its quantity.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final service in serviceCatalog.where(
                    (service) => selectedServices.contains(service.id),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: serviceEditor(service),
                    ),
                  Builder(
                    builder: (context) {
                      final availableServices = serviceCatalog
                          .where((service) =>
                              !selectedServices.contains(service.id))
                          .toList();
                      if (availableServices.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return OutlinedButton.icon(
                        onPressed: () async {
                          final pickedId = await showAppBottomSheet<String>(
                            context,
                            builder: (pickerContext) => SafeArea(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableServices.length,
                                itemBuilder: (_, index) {
                                  final service = availableServices[index];
                                  return AppListRow(
                                    title: service.name,
                                    subtitle: service.description,
                                    onTap: () => Navigator.of(pickerContext)
                                        .pop(service.id),
                                  );
                                },
                              ),
                            ),
                          );
                          if (pickedId == null) return;
                          setSheetState(() {
                            selectedServices.add(pickedId);
                            validatedCoupon = null;
                            couponMessage = null;
                            bookingFormError = null;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          selectedServices.isEmpty
                              ? 'Add service'
                              : 'Add another service',
                        ),
                      );
                    },
                  ),
                  if (bookingFormError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Text(
                        bookingFormError!,
                        style: TextStyle(color: colors.danger.fg),
                      ),
                    ),
                ],
              );

          Widget perServiceStep(
              String heading,
              String hint,
              Widget Function(
                BookingServiceFields fields,
              ) field) {
            final chosen = serviceCatalog
                .where((service) => selectedServices.contains(service.id))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(heading, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(hint, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpace.md),
                if (chosen.isEmpty)
                  const Text('Select a service first.')
                else
                  for (final service in chosen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(service.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpace.sm),
                          field(serviceFields[service.id]!),
                        ],
                      ),
                    ),
              ],
            );
          }

          Widget paymentStep() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Payment', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpace.md),
                  TextFormField(
                    controller: notesController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Delivery access notes (optional)',
                      hintText: 'Gate, parking, timing, or access instructions',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text('Want to pay online', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpace.sm),
                  FormField<String>(
                    initialValue: paymentMethod,
                    validator: (value) =>
                        value == null ? 'Choose a payment method.' : null,
                    builder: (field) => LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600 ? 2 : 1;
                        const methods = [
                          ('wallet', 'Wallet', 'Use your Urban Tanker balance'),
                          ('gateway', 'Online payment', 'Pay securely online'),
                          (
                            'cod',
                            'Cash on delivery',
                            'Pay when the service arrives'
                          ),
                        ];
                        return RadioGroup<String>(
                          groupValue: paymentMethod,
                          onChanged: (next) {
                            setSheetState(() {
                              paymentMethod = next;
                              field.didChange(next);
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GridView.count(
                                crossAxisCount: columns,
                                childAspectRatio: columns == 1 ? 4.2 : 3.8,
                                mainAxisSpacing: AppSpace.sm,
                                crossAxisSpacing: AppSpace.sm,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final (value, label, description)
                                      in methods)
                                    Card(
                                      margin: EdgeInsets.zero,
                                      child: RadioListTile<String>(
                                        value: value,
                                        title: Text(label),
                                        subtitle: Text(description),
                                      ),
                                    ),
                                ],
                              ),
                              if (field.hasError)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppSpace.xs),
                                  child: Text(
                                    field.errorText!,
                                    style: TextStyle(color: colors.danger.fg),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );

          Widget reviewStep() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    bookingReviewTitle(selectedServices.length),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final service in serviceCatalog.where(
                    (service) => selectedServices.contains(service.id),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.name,
                                style: theme.textTheme.titleSmall),
                            Text(
                              [
                                if (serviceFields[service.id]!
                                    .quantity
                                    .text
                                    .trim()
                                    .isNotEmpty)
                                  serviceFields[service.id]!
                                      .quantity
                                      .text
                                      .trim(),
                                if (serviceFields[service.id]!
                                    .location
                                    .text
                                    .trim()
                                    .isNotEmpty)
                                  serviceFields[service.id]!
                                      .location
                                      .text
                                      .trim(),
                                if (serviceFields[service.id]!
                                    .deliveryDate
                                    .text
                                    .trim()
                                    .isNotEmpty)
                                  serviceFields[service.id]!
                                      .deliveryDate
                                      .text
                                      .trim(),
                              ].join(' • '),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpace.md),
                  couponEntry(),
                  if (!phoneVerified)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Text(
                        'Verify your mobile number on the first step to submit.',
                        style: TextStyle(color: colors.danger.fg),
                      ),
                    ),
                ],
              );

          Widget stepContent() => switch (step) {
                0 => contactStep(),
                1 => servicesStep(),
                2 => perServiceStep(
                    'Delivery location',
                    'Choose where each service should be delivered.',
                    (fields) => DeliveryLocationField(
                      fields: fields,
                      onChanged: () => setSheetState(() {}),
                    ),
                  ),
                3 => perServiceStep(
                    'Delivery date',
                    'Pick a date for each service.',
                    (fields) => DeliveryDateField(
                      controller: fields.deliveryDate,
                      onChanged: () => setSheetState(() {}),
                    ),
                  ),
                4 => paymentStep(),
                _ => reviewStep(),
              };

          final isLast = step == lastStep;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final leave = await showAppConfirmDialog(
                context,
                title: 'Leave booking?',
                message: 'Your booking draft will be cleared if you leave.',
                confirmLabel: 'Leave',
                cancelLabel: 'Stay',
              );
              if (leave && context.mounted) Navigator.pop(context);
            },
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      0,
                      AppSpace.xl,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Book a delivery',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              'Step ${step + 1} of ${steps.length}: ${steps[step]}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        ClipRRect(
                          borderRadius: AppRadius.pillBorder,
                          child: LinearProgressIndicator(
                            value: (step + 1) / steps.length,
                            minHeight: 4,
                            color: colors.primary,
                            backgroundColor: colors.hairline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                      ),
                      child: Form(
                        key: stepKeys[step],
                        child: stepContent(),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !isLast,
                    child: Padding(
                      padding:
                          AppPageInsets.section.copyWith(top: 0, bottom: 0),
                      child: LiveQuoteSummary(
                        api: controller.api,
                        services: phoneVerified &&
                                paymentMethod != null &&
                                selectedServices.isNotEmpty &&
                                !selectedServices.any(serviceHasMissingFields)
                            ? buildServiceDetails()
                            : const [],
                        phone: normalizeIndianPhone(phoneController.text),
                        paymentMethod: paymentMethod,
                        couponCode: validatedCoupon == null
                            ? null
                            : couponController.text.trim(),
                        onTotal: (total) =>
                            setSheetState(() => quoteTotal = total),
                      ),
                    ),
                  ),
                  Padding(
                    padding: AppPageInsets.section.copyWith(
                      top: AppSpace.md,
                      bottom: AppSpace.lg,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated total',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    quoteTotal == null
                                        ? Text(
                                            'Shown once the details are complete.',
                                            style: theme.textTheme.bodyMedium,
                                          )
                                        : AnimatedAmount(
                                            value: quoteTotal!,
                                            format: formatRupees,
                                            style: theme.textTheme.titleLarge,
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.md),
                          Row(
                            children: [
                              if (step > 0) ...[
                                Expanded(
                                  child: SecondaryButton(
                                    label: 'Back',
                                    icon: Icons.arrow_back,
                                    onPressed: () => goTo(step - 1),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.md),
                              ],
                              Expanded(
                                child: isLast
                                    ? PrimaryButton(
                                        label: 'Submit booking',
                                        loading: submittingBooking,
                                        onPressed: canSubmit() ? submit : null,
                                      )
                                    : PrimaryButton(
                                        label: step == 4
                                            ? bookingReviewTitle(
                                                selectedServices.length,
                                              )
                                            : 'Next',
                                        icon: Icons.arrow_forward,
                                        onPressed: goNext,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  final contactPhone = bookingContactPhone;
  final contactEmail = bookingContactEmail;
  final chosenMethod = paymentMethod;
  if (result != null && context.mounted && chosenMethod != null) {
    Map<String, dynamic> booking = result;
    var resolvedMethod = chosenMethod;
    String? paidNote;
    if (chosenMethod == 'gateway' && booking['id'] != null) {
      final payment = await _runOnlinePaymentStep(
        context,
        controller.api,
        booking,
        contactPhone,
        contactEmail,
      );
      if (!context.mounted) return;
      final paidBooking = payment.booking;
      if (paidBooking == null) {
        if (payment.note != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(payment.note!)),
          );
        }
        return;
      }
      booking = paidBooking;
      resolvedMethod = payment.method;
      paidNote = payment.note;
    }
    final quote = booking['quote'];
    await showBookingSuccess(
      context,
      booking,
      quote is Map<String, dynamic> ? quote : null,
      resolvedMethod,
      api: controller.api,
      paidNote: paidNote,
      onReturnHome: onReturnHome,
    );
    onBookingCompleted?.call();
  }
}

enum _PaymentChoice {
  retryPayment,
  retryConfirmation,
  cashOnDelivery,
  payLater,
}

/// Runs Razorpay checkout for a booking that was just created. Cancelling the
/// checkout removes the booking. A failed or unconfirmed payment keeps it, so
/// the customer can retry or switch to cash on delivery. Returns a null
/// [booking] when no booking was kept.
Future<({Map<String, dynamic>? booking, String method, String? note})>
    _runOnlinePaymentStep(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic> booking,
  String phone,
  String email,
) async {
  final bookingId = booking['id']?.toString();
  if (bookingId == null || bookingId.isEmpty) {
    return (booking: null, method: 'gateway', note: 'Booking was not created.');
  }
  final flow = OnlinePaymentFlow(api: api, checkout: RazorpayPaymentCheckout());

  Future<OnlinePaymentOutcome> startPayment() => flow.pay(
        bookingId: bookingId,
        name: 'Urban Tanker',
        description: 'Urban Tanker booking',
        contact: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
      );

  var outcome = await startPayment();

  while (true) {
    switch (outcome.status) {
      case OnlinePaymentStatus.paid:
        return (
          booking: booking,
          method: 'gateway',
          note: await _paidNote(flow, bookingId),
        );
      case OnlinePaymentStatus.verificationPending:
        if (!context.mounted) {
          return (booking: null, method: 'gateway', note: null);
        }
        final choice = await _showPaymentRecoveryDialog(
          context,
          title: 'Payment confirmation pending',
          message: outcome.message ?? 'Please retry confirmation.',
          options: const [
            (_PaymentChoice.retryConfirmation, 'Retry confirmation'),
            (_PaymentChoice.payLater, 'Later'),
          ],
        );
        if (choice != _PaymentChoice.retryConfirmation ||
            outcome.pendingSuccess == null) {
          return (
            booking: null,
            method: 'gateway',
            note:
                'Payment received. Check My Bookings shortly to see your booking.',
          );
        }
        outcome = await flow.confirm(outcome.pendingSuccess!);
        continue;
      case OnlinePaymentStatus.cancelled:
        try {
          await api.cancelOnlinePayment(
            bookingId,
            couponCode: booking['coupon_code']?.toString(),
          );
        } on Object catch (error) {
          return (booking: null, method: 'gateway', note: friendlyError(error));
        }
        return (
          booking: null,
          method: 'gateway',
          note: 'Payment was cancelled, so the booking was not created.',
        );
      case OnlinePaymentStatus.failed:
        if (!context.mounted) {
          return (booking: booking, method: 'gateway', note: null);
        }
        final choice = await _showPaymentRecoveryDialog(
          context,
          title: 'Payment not completed',
          message: outcome.message ??
              'Your booking is saved. Try again or choose cash on delivery.',
          options: const [
            (_PaymentChoice.retryPayment, 'Try again'),
            (_PaymentChoice.cashOnDelivery, 'Cash on delivery'),
            (_PaymentChoice.payLater, 'Pay later'),
          ],
        );
        if (choice == _PaymentChoice.retryPayment) {
          outcome = await startPayment();
        } else if (choice == _PaymentChoice.cashOnDelivery) {
          try {
            await api.switchBookingToCashOnDelivery(bookingId);
            return (booking: booking, method: 'cod', note: null);
          } on Object catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(friendlyError(error))),
              );
            }
          }
        } else {
          return (
            booking: booking,
            method: 'gateway',
            note:
                'Your booking is saved with payment pending. You can pay from My Bookings.',
          );
        }
        continue;
    }
  }
}

Future<String?> _paidNote(OnlinePaymentFlow flow, String bookingId) async {
  try {
    final receipt = await flow.receipt(bookingId);
    if (receipt == null || !receipt.isPaid) return 'Payment received.';
    return 'Paid ${formatRupees(receipt.amountPaise / 100)} via ${receipt.methodLabel}';
  } on Object {
    return 'Payment received.';
  }
}

Future<_PaymentChoice?> _showPaymentRecoveryDialog(
  BuildContext context, {
  required String title,
  required String message,
  required List<(_PaymentChoice, String)> options,
}) {
  return showDialog<_PaymentChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        for (final (choice, label) in options)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, choice),
            child: Text(label),
          ),
      ],
    ),
  );
}

/// Rupee text for amounts shown on the booking flow.
String formatRupees(double value) => '₹${value.toStringAsFixed(2)}';

/// Success sheet after a booking is submitted: a check animation, the
/// itemized summary, and a way to open the new booking.
Future<void> showBookingSuccess(
  BuildContext context,
  Map<String, dynamic> booking,
  Map<String, dynamic>? quote,
  String paymentMethod, {
  required ApiClient api,
  String? paidNote,
  VoidCallback? onReturnHome,
}) async {
  String? money(Object? value) {
    if (value is! num) return null;
    return '₹${(value / 100).toStringAsFixed(2)}';
  }

  final serviceDetails = (booking['service_details'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(BookingServiceDetails.fromJson)
      .toList();
  final serviceNames =
      booking['service_names'] as Map<String, dynamic>? ?? const {};
  final lines = [
    if (quote?['subtotalPaise'] != null)
      ('Subtotal', money(quote!['subtotalPaise'])),
    if (quote?['gstPaise'] != null) ('GST', money(quote!['gstPaise'])),
    if (quote?['discountPaise'] != null)
      ('Discount', money(quote!['discountPaise'])),
    if (quote?['totalPaise'] != null) ('Total', money(quote!['totalPaise'])),
  ];
  final tracked = _bookingFromResponse(booking);
  await showAppBottomSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: LottieOrIcon(
                asset: 'assets/lottie/success.json',
                size: 96,
                repeat: false,
                fallback: Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: sheetContext.colors.success.fg,
                ),
              ),
            ),
            Text(
              'Booking confirmed',
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            if (booking['reference'] != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                'Reference ${booking['reference']}',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 600 ? 2 : 1;
                      final width = columns == 2
                          ? (constraints.maxWidth - AppSpace.md) / 2
                          : constraints.maxWidth;
                      final details = <(String, String)>[
                        if ((booking['customer_name'] ??
                                    booking['customerName'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          (
                            'Customer',
                            (booking['customer_name'] ??
                                    booking['customerName'])
                                .toString()
                          ),
                        if ((booking['customer_phone'] ??
                                    booking['customer_phone_e164'] ??
                                    booking['phone'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          (
                            'Contact',
                            (booking['customer_phone'] ??
                                    booking['customer_phone_e164'] ??
                                    booking['phone'])
                                .toString()
                          ),
                        if ((booking['customer_email'] ??
                                    booking['customerEmail'] ??
                                    booking['email'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          (
                            'Email',
                            (booking['customer_email'] ??
                                    booking['customerEmail'] ??
                                    booking['email'])
                                .toString()
                          ),
                        if ((booking['location'] ??
                                    booking['delivery_location'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          (
                            'Delivery location',
                            (booking['location'] ??
                                    booking['delivery_location'])
                                .toString()
                          ),
                        if ((booking['scheduled_for'] ??
                                    booking['delivery_date'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          (
                            'Delivery schedule',
                            (booking['scheduled_for'] ??
                                    booking['delivery_date'])
                                .toString()
                          ),
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Wrap(
                          spacing: AppSpace.md,
                          runSpacing: AppSpace.md,
                          children: [
                            for (final (label, value) in details)
                              SizedBox(
                                width: width,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    Text(value),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  for (final service in serviceDetails) ...[
                    Text(
                      (serviceNames[service.serviceId] ?? service.serviceId)
                          .toString(),
                      style: Theme.of(sheetContext).textTheme.titleSmall,
                    ),
                    if (service.quantity.trim().isNotEmpty)
                      Text('Quantity/capacity: ${service.quantity}'),
                    if (service.waterType?.trim().isNotEmpty == true)
                      Text('Water type: ${service.waterType}'),
                    if (service.tankerCount?.trim().isNotEmpty == true)
                      Text('Tanker count: ${service.tankerCount}'),
                    Text('Details: ${service.details}'),
                    if (service.location?.trim().isNotEmpty == true)
                      Text('Delivery location: ${service.location}'),
                    if (service.deliveryDate?.trim().isNotEmpty == true)
                      Text('Delivery date: ${service.deliveryDate}'),
                    if (service.preferredTime?.trim().isNotEmpty == true)
                      Text('Preferred time: ${service.preferredTime}'),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  for (final (label, value) in lines)
                    if (value != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.xs,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(label)),
                            AmountText(
                              value,
                              style: label == 'Total'
                                  ? Theme.of(sheetContext).textTheme.titleMedium
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: AppSpace.xs),
                  Text('Payment: ${_paymentMethodLabel(paymentMethod)}'),
                  if (paidNote != null) Text(paidNote),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (tracked != null)
              PrimaryButton(
                label: 'Track this booking',
                icon: Icons.local_shipping_outlined,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingDetailsScreen(booking: tracked),
                    ),
                  );
                },
              ),
            if (tracked != null) const SizedBox(height: AppSpace.sm),
            if (tracked != null)
              SecondaryButton(
                label: 'Share tracking link',
                icon: Icons.share_outlined,
                onPressed: () async {
                  try {
                    final trackingUrl =
                        await api.bookingTrackingLink(tracked.id);
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Track Urban Tanker booking ${tracked.reference}: $trackingUrl',
                      ),
                    );
                  } catch (error) {
                    if (sheetContext.mounted) {
                      showAppSnack(
                        sheetContext,
                        friendlyError(error),
                        variant: AppSnackVariant.error,
                      );
                    }
                  }
                },
              ),
            if (tracked != null) const SizedBox(height: AppSpace.sm),
            SecondaryButton(
              label: 'Return home',
              icon: Icons.home_outlined,
              onPressed: () {
                Navigator.pop(sheetContext);
                onReturnHome?.call();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// The created booking as a [Booking], or null when the response lacks an id.
Booking? _bookingFromResponse(Map<String, dynamic> response) {
  try {
    final booking = Booking.fromJson(response);
    return booking.id.isEmpty ? null : booking;
  } catch (_) {
    return null;
  }
}
