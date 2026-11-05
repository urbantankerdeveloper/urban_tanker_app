import 'dart:convert';

import 'package:flutter/material.dart';
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
import '../../../services/service_area.dart';
import '../../booking_details_screen.dart';
import 'booking_fields.dart';
import 'live_quote_summary.dart';

typedef _VerifiedBookingContact = ({String phone, String challengeId});

Future<_VerifiedBookingContact?> _showBookingPhoneVerificationDialog(
  BuildContext context,
  ApiClient api,
  String initialPhone,
) {
  return showDialog<_VerifiedBookingContact>(
    context: context,
    builder: (_) => _BookingPhoneVerificationDialog(
      api: api,
      initialPhone: initialPhone,
    ),
  );
}

class _BookingPhoneVerificationDialog extends StatefulWidget {
  const _BookingPhoneVerificationDialog({
    required this.api,
    required this.initialPhone,
  });

  final ApiClient api;
  final String initialPhone;

  @override
  State<_BookingPhoneVerificationDialog> createState() =>
      _BookingPhoneVerificationDialogState();
}

class _BookingPhoneVerificationDialogState
    extends State<_BookingPhoneVerificationDialog> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone);
  final _otp = TextEditingController();
  String? _challengeId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
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
        _otp.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final challengeId = _challengeId;
    final phone = normalizeIndianPhone(_phone.text);
    if (challengeId == null) {
      setState(() => _error = 'Send a verification code first.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
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
        otp: _otp.text,
      );
      if (mounted) {
        Navigator.pop(
          context,
          (phone: phone, challengeId: challengeId),
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
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number'),
              onChanged: (_) => setState(() {
                _challengeId = null;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '6-digit verification code',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
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
            onPressed: _busy ? null : _sendCode,
            child: const Text('Send code'),
          ),
          PrimaryButton(
            label: 'Verify number',
            loading: _busy,
            onPressed: _busy ? null : _verify,
          ),
        ],
      );
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
}) async {
  if (serviceCatalog.isEmpty) return;
  List<AccountRecord> addresses = const [];
  try {
    addresses = await controller.api.addresses();
  } catch (_) {
    // Saved addresses are optional; manual entry remains available.
  }
  final couponController = TextEditingController();
  final notesController =
      TextEditingController(text: previousBooking?.notes ?? '');
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final emailController = TextEditingController();
  final emailOtpController = TextEditingController();
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
  selectedAddress ??= previousBooking == null && addresses.isNotEmpty
      ? addresses.first.detail
      : null;
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
  String? phoneChallengeId;
  String? emailChallengeId;
  String? verifiedPhone;
  var phoneVerified = false;
  var phoneVerificationRequired = true;
  var loadingPhoneVerification = true;
  var validatingCoupon = false;
  var submittingBooking = false;
  String? bookingKey;
  String? bookingKeyFingerprint;
  var paymentMethod = 'cod';
  try {
    final savedPhone = await controller.api.phoneVerification();
    phoneController.text = savedPhone.phone;
    verifiedPhone = savedPhone.verified ? savedPhone.phone : null;
    phoneVerified = savedPhone.verified && savedPhone.phone.isNotEmpty;
    phoneVerificationRequired = savedPhone.required;
  } catch (_) {
    // The booking form still permits verification when the number is changed.
  } finally {
    loadingPhoneVerification = false;
  }
  if (!context.mounted) {
    couponController.dispose();
    notesController.dispose();
    phoneController.dispose();
    otpController.dispose();
    emailController.dispose();
    emailOtpController.dispose();
    for (final fields in serviceFields.values) {
      fields.dispose();
    }
    return;
  }
  bool serviceHasMissingFields(String id) {
    final fields = serviceFields[id]!;
    final service = serviceCatalog.firstWhere((item) => item.id == id);
    final serviceSpecificMissing = id == 'water_tanker'
        ? fields.waterType.text.trim().isEmpty ||
            fields.tankerCount.text.trim().isEmpty
        : fields.details.text.trim().isEmpty;
    return fields.quantity.text.trim().isEmpty ||
        serviceSpecificMissing ||
        fields.location.text.trim().isEmpty ||
        !isChennaiLocation(
          address: fields.location.text,
          latitude: fields.latitude,
          longitude: fields.longitude,
        ) ||
        DateTime.tryParse(fields.deliveryDate.text.trim()) == null ||
        service.capacityOptions.contains(fields.quantity.text) == false ||
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
    builder: (context) => StatefulBuilder(
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

        bool canSubmit() => !(loadingPhoneVerification ||
            submittingBooking ||
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
          setSheetState(() => submittingBooking = true);
          var bookingContactRecoveryUsed = false;
          try {
            final services = buildServiceDetails();
            final quotePreview = await controller.api.previewBookingQuote(
              serviceId: services.first.serviceId,
              capacity: services.first.quantity,
              services: services,
              location: services.first.location ?? '',
              deliveryDate: services.first.deliveryDate ?? '',
              notes: notesController.text,
              paymentMethod: paymentMethod,
              latitude: services.first.latitude,
              longitude: services.first.longitude,
              couponCode:
                  validatedCoupon == null ? null : couponController.text.trim(),
              phone: phoneController.text,
              phoneVerificationChallengeId: phoneChallengeId,
            );
            if (!context.mounted) return;
            final quote = quotePreview['quote'];
            final selectedServiceNames = selectedServices.map(
              (id) =>
                  serviceCatalog.firstWhere((service) => service.id == id).name,
            );
            while (context.mounted) {
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
                          if (services[index].tankerCount?.trim().isNotEmpty ==
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
                paymentMethod,
                phoneChallengeId,
              ]);
              if (keyFingerprint != bookingKeyFingerprint) {
                bookingKeyFingerprint = keyFingerprint;
                bookingKey = newIdempotencyKey();
              }
              try {
                final booking = await controller.api.createBooking(
                  serviceId: services.first.serviceId,
                  capacity: services.first.quantity,
                  services: services,
                  location: services.first.location ?? '',
                  deliveryDate: services.first.deliveryDate ?? '',
                  notes: notesController.text,
                  paymentMethod: paymentMethod,
                  latitude: services.first.latitude,
                  longitude: services.first.longitude,
                  couponCode: validatedCoupon == null
                      ? null
                      : couponController.text.trim(),
                  phone: phoneController.text,
                  phoneVerificationChallengeId: phoneChallengeId,
                  idempotencyKey: bookingKey,
                );
                booking['service_details'] =
                    services.map((service) => service.toJson()).toList();
                booking['service_names'] = {
                  for (final serviceId in selectedServices)
                    serviceId: serviceCatalog
                        .firstWhere((service) => service.id == serviceId)
                        .name,
                };
                if (context.mounted) Navigator.pop(context, booking);
                return;
              } on ApiException catch (error) {
                const contactVerificationError =
                    'Verify the contact number for booking contact before booking.';
                if (!phoneVerificationRequired ||
                    error.statusCode != 400 ||
                    error.message != contactVerificationError ||
                    bookingContactRecoveryUsed) {
                  rethrow;
                }
                bookingContactRecoveryUsed = true;
                final verified = await _showBookingPhoneVerificationDialog(
                  context,
                  controller.api,
                  phoneController.text,
                );
                if (verified == null || !context.mounted) return;
                setSheetState(() {
                  phoneController.text = verified.phone;
                  phoneChallengeId = verified.challengeId;
                  emailChallengeId = null;
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                ServiceDropdownField(
                  controller: fields.quantity,
                  label:
                      BookingServiceForm.forService(service.id).quantityLabel,
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
                  ServiceDropdownField(
                    controller: fields.details,
                    label:
                        BookingServiceForm.forService(service.id).detailsLabel,
                    options: service.detailOptions,
                    emptyMessage: 'No service detail options are configured.',
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
                Text('Your mobile number', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'This number is shared across all selected services.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.md),
                if (phoneVerificationRequired)
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Booking phone number',
                      helperText: 'Shared across all selected services',
                    ),
                    onChanged: (_) => setSheetState(() {
                      final normalized =
                          normalizeIndianPhone(phoneController.text);
                      phoneVerified =
                          verifiedPhone != null && normalized == verifiedPhone;
                      if (!phoneVerified) {
                        phoneChallengeId = null;
                        emailChallengeId = null;
                        otpController.clear();
                        emailOtpController.clear();
                      }
                      bookingFormError = null;
                    }),
                    validator: (value) {
                      final normalized = normalizeIndianPhone(value ?? '');
                      return RegExp(r'^\d{10}$').hasMatch(normalized)
                          ? null
                          : 'Enter a valid 10-digit mobile number.';
                    },
                  )
                else if (phoneController.text.isNotEmpty)
                  Text(
                    'Using your account phone: ${phoneController.text}',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  Text(
                    'Add a mobile number to your account before booking.',
                    style: TextStyle(color: colors.danger.fg),
                  ),
                if (loadingPhoneVerification)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpace.md),
                    child: Text('Checking your saved number...'),
                  ),
                if (phoneVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: Row(
                      children: [
                        Icon(Icons.verified_outlined, color: colors.success.fg),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          phoneVerificationRequired
                              ? 'Number verified'
                              : 'Using your account phone',
                          style: TextStyle(
                            color: colors.success.fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (phoneVerificationRequired &&
                    !phoneVerified &&
                    !loadingPhoneVerification) ...[
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailChallengeId == null
                              ? otpController
                              : emailOtpController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: emailChallengeId != null
                                ? 'Email code'
                                : AuthFeatureFlags.emailOtp
                                    ? 'SMS code'
                                    : 'OTP',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            final normalized =
                                normalizeIndianPhone(phoneController.text);
                            final challenge =
                                await controller.api.requestBookingOtp(
                              phone: normalized,
                            );
                            setSheetState(() {
                              phoneChallengeId = challenge.challengeId;
                              emailChallengeId = challenge.emailChallengeId;
                              bookingFormError =
                                  'OTP sent. Enter it to verify this number.';
                            });
                          } catch (error) {
                            final accountEmail = controller.user?.email;
                            final canUseEmailFallback = accountEmail != null &&
                                accountEmail.trim().isNotEmpty &&
                                error is ApiException &&
                                error.statusCode == 503 &&
                                error.message ==
                                    'Mobile verification is not configured yet.';
                            if (!canUseEmailFallback) {
                              setSheetState(() =>
                                  bookingFormError = friendlyError(error));
                              return;
                            }
                            try {
                              final challengeId = await controller.api
                                  .requestRegisteredBookingEmailOtp(
                                phone: normalizeIndianPhone(
                                  phoneController.text,
                                ),
                              );
                              setSheetState(() {
                                emailController.text = accountEmail.trim();
                                phoneChallengeId = null;
                                emailChallengeId = challengeId;
                                bookingFormError = 'SMS is unavailable. A '
                                    'verification code was sent to your '
                                    'registered email.';
                              });
                            } catch (fallbackError) {
                              setSheetState(() => bookingFormError =
                                  friendlyError(fallbackError));
                            }
                          }
                        },
                        child: const Text('Send OTP'),
                      ),
                    ],
                  ),
                  if (bookingFormError != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      bookingFormError!,
                      style: TextStyle(color: colors.danger.fg),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Verify this shared number before reviewing your booking.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (phoneChallengeId != null || emailChallengeId != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () async {
                          final enteredPhoneOtp = phoneChallengeId != null &&
                              otpController.text.trim().isNotEmpty;
                          final enteredEmailOtp = emailChallengeId != null &&
                              emailOtpController.text.trim().isNotEmpty;
                          if (!enteredPhoneOtp && !enteredEmailOtp) {
                            setSheetState(
                              () => bookingFormError =
                                  'Enter the code sent to your phone or email.',
                            );
                            return;
                          }
                          try {
                            await controller.api.verifyPhoneOtp(
                              phone: phoneController.text,
                              challengeId:
                                  enteredPhoneOtp ? phoneChallengeId : null,
                              otp: enteredPhoneOtp ? otpController.text : null,
                              email: enteredEmailOtp
                                  ? emailController.text.trim()
                                  : null,
                              emailChallengeId:
                                  enteredEmailOtp ? emailChallengeId : null,
                              emailOtp: enteredEmailOtp
                                  ? emailOtpController.text
                                  : null,
                            );
                            setSheetState(() {
                              phoneVerified = true;
                              verifiedPhone =
                                  normalizeIndianPhone(phoneController.text);
                              bookingFormError = null;
                            });
                          } catch (error) {
                            setSheetState(
                              () => bookingFormError = friendlyError(error),
                            );
                          }
                        },
                        child: const Text('Verify OTP'),
                      ),
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
                        .where(
                            (service) => !selectedServices.contains(service.id))
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
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration:
                      const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                    DropdownMenuItem(
                      value: 'gateway',
                      child: Text('Online payment'),
                    ),
                    DropdownMenuItem(
                      value: 'cod',
                      child: Text('Cash on delivery'),
                    ),
                  ],
                  onChanged: (value) => setSheetState(
                    () => paymentMethod = value ?? 'cod',
                  ),
                ),
              ],
            );

        Widget reviewStep() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Review and submit', style: theme.textTheme.titleMedium),
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
                          Text(service.name, style: theme.textTheme.titleSmall),
                          Text(
                            [
                              if (serviceFields[service.id]!
                                  .quantity
                                  .text
                                  .trim()
                                  .isNotEmpty)
                                serviceFields[service.id]!.quantity.text.trim(),
                              if (serviceFields[service.id]!
                                  .location
                                  .text
                                  .trim()
                                  .isNotEmpty)
                                serviceFields[service.id]!.location.text.trim(),
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
                if (!phoneVerified && !loadingPhoneVerification)
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
                    padding: AppPageInsets.section.copyWith(top: 0, bottom: 0),
                    child: LiveQuoteSummary(
                      api: controller.api,
                      services: phoneVerified &&
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
                                      label: 'Next',
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
  );
  couponController.dispose();
  notesController.dispose();
  phoneController.dispose();
  otpController.dispose();
  emailController.dispose();
  emailOtpController.dispose();
  for (final fields in serviceFields.values) {
    fields.dispose();
  }
  if (result != null && context.mounted) {
    final quote = result['quote'];
    await showBookingSuccess(
      context,
      result,
      quote is Map<String, dynamic> ? quote : null,
      paymentMethod,
    );
  }
}

/// Rupee text for amounts shown on the booking flow.
String formatRupees(double value) => '₹${value.toStringAsFixed(2)}';

/// Success sheet after a booking is submitted: a check animation, the
/// itemized summary, and a way to open the new booking.
Future<void> showBookingSuccess(
  BuildContext context,
  Map<String, dynamic> booking,
  Map<String, dynamic>? quote,
  String paymentMethod,
) async {
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
              'Booking submitted',
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
            SecondaryButton(
              label: 'Done',
              onPressed: () => Navigator.pop(sheetContext),
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
