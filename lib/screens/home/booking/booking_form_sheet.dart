import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../models/account.dart';
import '../../../models/booking.dart';
import '../../../models/booking_service_details.dart';
import '../../../models/booking_service_form.dart';
import '../../../models/service.dart';
import '../../../services/api_client.dart';
import '../../../services/friendly_error.dart';
import '../../../services/service_area.dart';
import 'booking_fields.dart';
import 'live_quote_summary.dart';

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
  final formKey = GlobalKey<FormState>();
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
  String? verifiedPhone;
  var phoneVerified = false;
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

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Leave booking?'),
              content: const Text(
                  'Your booking draft will be cleared if you leave.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
          if (leave == true && context.mounted) Navigator.pop(context);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Form(
              key: formKey,
              child: ListView(
                children: [
                  Text('Book a delivery',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text('Select services',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
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
                      if (!phoneVerified) phoneChallengeId = null;
                      bookingFormError = null;
                    }),
                    validator: (value) {
                      final normalized = normalizeIndianPhone(value ?? '');
                      return RegExp(r'^\d{10}$').hasMatch(normalized)
                          ? null
                          : 'Enter a valid 10-digit mobile number.';
                    },
                  ),
                  if (!phoneVerified && !loadingPhoneVerification) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: otpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'OTP'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              final normalized =
                                  normalizeIndianPhone(phoneController.text);
                              final challenge = await controller.api
                                  .requestPhoneOtp(normalized);
                              setSheetState(() {
                                phoneChallengeId = challenge;
                                bookingFormError =
                                    'OTP sent. Enter it to verify this number.';
                              });
                            } catch (error) {
                              setSheetState(() =>
                                  bookingFormError = friendlyError(error));
                            }
                          },
                          child: const Text('Send OTP'),
                        ),
                      ],
                    ),
                    if (!phoneVerified && !loadingPhoneVerification)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Verify this shared number before reviewing your booking.'),
                      ),
                    if (phoneChallengeId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            try {
                              await controller.api.verifyPhoneOtp(
                                challengeId: phoneChallengeId!,
                                phone: phoneController.text,
                                otp: otpController.text,
                              );
                              setSheetState(() {
                                phoneVerified = true;
                                verifiedPhone =
                                    normalizeIndianPhone(phoneController.text);
                                bookingFormError = null;
                              });
                            } catch (error) {
                              setSheetState(() =>
                                  bookingFormError = friendlyError(error));
                            }
                          },
                          child: const Text('Verify OTP'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  for (final service in serviceCatalog.where(
                      (service) => selectedServices.contains(service.id)))
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(service.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                ),
                                IconButton(
                                  tooltip: 'Remove ${service.name}',
                                  onPressed: () {
                                    setSheetState(() {
                                      selectedServices.remove(service.id);
                                      validatedCoupon = null;
                                      couponMessage = null;
                                      bookingFormError = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ServiceDropdownField(
                              controller: serviceFields[service.id]!.quantity,
                              label: BookingServiceForm.forService(service.id)
                                  .quantityLabel,
                              options: service.capacityOptions,
                              emptyMessage:
                                  'No capacity options are configured.',
                              onChanged: (_) => setSheetState(() {}),
                            ),
                            if (service.id == 'water_tanker') ...[
                              const SizedBox(height: 8),
                              ServiceDropdownField(
                                controller:
                                    serviceFields[service.id]!.waterType,
                                label: 'Water type',
                                options: service.waterTypeOptions,
                                emptyMessage:
                                    'No water type options are configured.',
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ],
                            if (service.id == 'water_tanker') ...[
                              const SizedBox(height: 8),
                              ServiceDropdownField(
                                controller:
                                    serviceFields[service.id]!.tankerCount,
                                label: 'Tanker count',
                                options: service.tankerCountOptions,
                                emptyMessage:
                                    'No tanker count options are configured.',
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (service.id != 'water_tanker')
                              ServiceDropdownField(
                                controller: serviceFields[service.id]!.details,
                                label: BookingServiceForm.forService(service.id)
                                    .detailsLabel,
                                options: service.detailOptions,
                                emptyMessage:
                                    'No service detail options are configured.',
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            const SizedBox(height: 8),
                            DeliveryLocationField(
                              fields: serviceFields[service.id]!,
                              onChanged: () => setSheetState(() {}),
                            ),
                            const SizedBox(height: 8),
                            DeliveryDateField(
                              controller:
                                  serviceFields[service.id]!.deliveryDate,
                              onChanged: () => setSheetState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
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
                          final pickedId = await showModalBottomSheet<String>(
                            context: context,
                            showDragHandle: true,
                            builder: (pickerContext) => SafeArea(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableServices.length,
                                itemBuilder: (_, index) {
                                  final service = availableServices[index];
                                  return ListTile(
                                    title: Text(service.name),
                                    subtitle: Text(service.description),
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
                        label: Text(selectedServices.isEmpty
                            ? 'Add service'
                            : 'Add another service'),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration:
                        const InputDecoration(labelText: 'Payment method'),
                    items: const [
                      DropdownMenuItem(
                        value: 'wallet',
                        child: Text('Wallet'),
                      ),
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
                  if (bookingFormError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        bookingFormError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Coupon code (optional)',
                      suffixIcon: TextButton(
                        onPressed: validatingCoupon
                            ? null
                            : () async {
                                final code = couponController.text.trim();
                                if (code.isEmpty) {
                                  setSheetState(() {
                                    validatedCoupon = null;
                                    couponMessage =
                                        'Enter a coupon code first.';
                                  });
                                  return;
                                }
                                if (selectedServices.isEmpty) {
                                  setSheetState(() => couponMessage =
                                      'Add a service before applying a coupon.');
                                  return;
                                }
                                setSheetState(() {
                                  validatingCoupon = true;
                                  couponMessage = null;
                                });
                                try {
                                  final serviceId = selectedServices.first;
                                  final coupon =
                                      await controller.api.validateCoupon(
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
                                    setSheetState(
                                        () => validatingCoupon = false);
                                  }
                                }
                              },
                        child: validatingCoupon
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Apply'),
                      ),
                    ),
                  ),
                  if (couponMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        couponMessage!,
                        style: TextStyle(
                          color: validatedCoupon == null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  LiveQuoteSummary(
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
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: loadingPhoneVerification ||
                            submittingBooking ||
                            selectedServices.isEmpty ||
                            !phoneVerified ||
                            selectedServices.any(serviceHasMissingFields)
                        ? null
                        : () async {
                            if (selectedServices.isEmpty) {
                              setSheetState(() => bookingFormError =
                                  'Select at least one service.');
                              return;
                            }
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => submittingBooking = true);
                            try {
                              final services = buildServiceDetails();
                              final quotePreview =
                                  await controller.api.previewBookingQuote(
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
                              );
                              if (!context.mounted) return;
                              final quote = quotePreview['quote'];
                              final selectedServiceNames = selectedServices.map(
                                (id) => serviceCatalog
                                    .firstWhere((service) => service.id == id)
                                    .name,
                              );
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm booking quote'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var index = 0;
                                            index < services.length;
                                            index++) ...[
                                          Text(
                                              selectedServiceNames
                                                  .elementAt(index),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall),
                                          if (services[index]
                                              .quantity
                                              .trim()
                                              .isNotEmpty)
                                            Text(
                                                'Quantity/capacity: ${services[index].quantity.trim()}'),
                                          if (services[index]
                                                  .waterType
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true)
                                            Text(
                                                'Water type: ${services[index].waterType}'),
                                          if (services[index]
                                                  .tankerCount
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true)
                                            Text(
                                                'Tanker count: ${services[index].tankerCount}'),
                                          Text(
                                              'Details: ${services[index].details.trim()}'),
                                          const SizedBox(height: 8),
                                        ],
                                        Text(formatQuoteSummary(quote)),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Review'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Confirm booking'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) {
                                return;
                              }
                              // One key per distinct submission. A retry of the
                              // same form reuses it, so the server can dedupe it.
                              final keyFingerprint = jsonEncode([
                                for (final service in services)
                                  service.toJson(),
                                notesController.text,
                                phoneController.text,
                                validatedCoupon == null
                                    ? null
                                    : couponController.text.trim(),
                                paymentMethod,
                                phoneChallengeId,
                              ]);
                              if (keyFingerprint != bookingKeyFingerprint) {
                                bookingKeyFingerprint = keyFingerprint;
                                bookingKey = newIdempotencyKey();
                              }
                              final booking =
                                  await controller.api.createBooking(
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
                              booking['service_details'] = services
                                  .map((service) => service.toJson())
                                  .toList();
                              booking['service_names'] = {
                                for (final serviceId in selectedServices)
                                  serviceId: serviceCatalog
                                      .firstWhere(
                                          (service) => service.id == serviceId)
                                      .name,
                              };
                              if (context.mounted) {
                                Navigator.pop(context, booking);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendlyError(error))),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => submittingBooking = false);
                              }
                            }
                          },
                    child: const Text('Submit booking'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  couponController.dispose();
  notesController.dispose();
  phoneController.dispose();
  otpController.dispose();
  for (final fields in serviceFields.values) {
    fields.dispose();
  }
  if (result != null && context.mounted) {
    final quote = result['quote'];
    await showBookingConfirmation(
      context,
      result,
      quote is Map<String, dynamic> ? quote : null,
      paymentMethod,
    );
  }
}

Future<void> showBookingConfirmation(
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
    if (booking['reference'] != null) 'Reference: ${booking['reference']}',
    if (quote?['subtotalPaise'] != null)
      'Subtotal: ${money(quote!['subtotalPaise'])}',
    if (quote?['gstPaise'] != null) 'GST: ${money(quote!['gstPaise'])}',
    if (quote?['discountPaise'] != null)
      'Discount: ${money(quote!['discountPaise'])}',
    if (quote?['totalPaise'] != null) 'Total: ${money(quote!['totalPaise'])}',
  ];
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Booking submitted'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final service in serviceDetails) ...[
              Text(
                (serviceNames[service.serviceId] ?? service.serviceId)
                    .toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (service.quantity.trim().isNotEmpty)
                Text('Quantity/capacity: ${service.quantity}'),
              if (service.waterType?.trim().isNotEmpty == true)
                Text('Water type: ${service.waterType}'),
              if (service.tankerCount?.trim().isNotEmpty == true)
                Text('Tanker count: ${service.tankerCount}'),
              Text('Details: ${service.details}'),
              const SizedBox(height: 8),
            ],
            for (final line in lines) Text(line),
            Text('Payment: ${_paymentMethodLabel(paymentMethod)}'),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
