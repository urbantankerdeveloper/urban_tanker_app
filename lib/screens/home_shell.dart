import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../models/service.dart';
import '../models/booking_service_details.dart';
import '../models/booking_service_form.dart';
import '../models/booking.dart';
import '../models/session.dart';
import '../models/account.dart';
import '../models/notification.dart';
import 'notification_inbox.dart';
import 'bookings_screen.dart';
import 'invoice_detail_screen.dart';
import 'support_request_detail_screen.dart';
import 'customer_account_screen.dart';
import 'vendor_workspace.dart';
import 'admin_workspace.dart';
import 'dispatcher_workspace.dart';
import '../services/service_area.dart';
import '../services/api_client.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  List<TankerService> _services = const [];
  bool _loadingServices = false;
  String? _serviceError;
  late Future<List<NotificationItem>>? _notifications;

  WorkspaceRole get role => widget.controller.user!.role;

  @override
  void initState() {
    super.initState();
    _notifications = role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.admin
        ? widget.controller.api.notifications(role.name)
        : null;
    if (role == WorkspaceRole.customer) _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _serviceError = null;
    });
    try {
      _services = await widget.controller.api.services();
    } catch (error) {
      _serviceError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _createBooking({Booking? previousBooking}) async {
    if (_services.isEmpty) return;
    List<AccountRecord> addresses = const [];
    try {
      addresses = await widget.controller.api.addresses();
    } catch (_) {
      // Saved addresses are optional; manual entry remains available.
    }
    final couponController = TextEditingController();
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedAddress;
    final previousDetails = {
      for (final detail
          in previousBooking?.services ?? <BookingServiceDetails>[])
        detail.serviceId: detail,
    };
    final serviceFields = {
      for (final service in _services)
        service.id: _BookingServiceFields(
          quantity: previousDetails[service.id]?.quantity ??
              (previousBooking == null && service.id == 'water_tanker'
                  ? '5000'
                  : ''),
          details: previousDetails[service.id]?.details ?? '',
          location: previousDetails[service.id]?.location ??
              (previousBooking?.location ?? selectedAddress ?? ''),
          deliveryDate: previousDetails[service.id]?.deliveryDate ??
              _dateOnly(previousBooking?.deliveryDate ??
                  DateTime.now().add(const Duration(days: 1))),
          latitude: previousDetails[service.id]?.latitude,
          longitude: previousDetails[service.id]?.longitude,
        ),
    };
    final previousServiceIds = previousDetails.keys
        .where((id) => _services.any((service) => service.id == id))
        .toSet();
    if (previousServiceIds.isEmpty &&
        previousBooking?.serviceId != null &&
        _services.any((service) => service.id == previousBooking!.serviceId)) {
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
    final selectedServices = previousServiceIds.isNotEmpty
        ? previousServiceIds
        : <String>{_services.first.id};
    for (final address in addresses) {
      if (address.detail == previousBooking?.location) {
        selectedAddress = address.detail;
        break;
      }
    }
    selectedAddress ??= previousBooking == null && addresses.isNotEmpty
        ? addresses.first.detail
        : null;
    for (final fields in serviceFields.values) {
      if (fields.location.text.trim().isEmpty && selectedAddress != null) {
        fields.location.text = selectedAddress;
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
    try {
      final savedPhone = await widget.controller.api.phoneVerification();
      phoneController.text = savedPhone.phone;
      verifiedPhone = savedPhone.verified ? savedPhone.phone : null;
      phoneVerified = savedPhone.verified && savedPhone.phone.isNotEmpty;
    } catch (_) {
      // The booking form still permits verification when the number is changed.
    } finally {
      loadingPhoneVerification = false;
    }
    if (!mounted) {
      couponController.dispose();
      phoneController.dispose();
      otpController.dispose();
      for (final fields in serviceFields.values) {
        fields.dispose();
      }
      return;
    }
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
                        phoneVerified = verifiedPhone != null &&
                            normalized == verifiedPhone;
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
                              decoration:
                                  const InputDecoration(labelText: 'OTP'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                final normalized =
                                    normalizeIndianPhone(phoneController.text);
                                final challenge = await widget.controller.api
                                    .requestPhoneOtp(normalized);
                                setSheetState(() {
                                  phoneChallengeId = challenge;
                                  bookingFormError =
                                      'OTP sent. Enter it to verify this number.';
                                });
                              } catch (error) {
                                setSheetState(
                                    () => bookingFormError = error.toString());
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
                                await widget.controller.api.verifyPhoneOtp(
                                  challengeId: phoneChallengeId!,
                                  phone: phoneController.text,
                                  otp: otpController.text,
                                );
                                setSheetState(() {
                                  phoneVerified = true;
                                  verifiedPhone = normalizeIndianPhone(
                                      phoneController.text);
                                  bookingFormError = null;
                                });
                              } catch (error) {
                                setSheetState(
                                    () => bookingFormError = error.toString());
                              }
                            },
                            child: const Text('Verify OTP'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    for (final service in _services) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selectedServices.contains(service.id),
                        title: Text(service.name),
                        subtitle: Text(service.description),
                        onChanged: (selected) {
                          setSheetState(() {
                            if (selected == true) {
                              selectedServices.add(service.id);
                            } else {
                              selectedServices.remove(service.id);
                            }
                            validatedCoupon = null;
                            couponMessage = null;
                            bookingFormError = null;
                          });
                        },
                      ),
                      if (selectedServices.contains(service.id))
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(service.name,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller:
                                      serviceFields[service.id]!.quantity,
                                  maxLength: 30,
                                  decoration: InputDecoration(
                                    labelText: BookingServiceForm.forService(
                                            service.id)
                                        .quantityLabel,
                                    hintText: BookingServiceForm.forService(
                                            service.id)
                                        .quantityHint,
                                  ),
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller:
                                      serviceFields[service.id]!.details,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 1000,
                                  decoration: InputDecoration(
                                    labelText: BookingServiceForm.forService(
                                            service.id)
                                        .detailsLabel,
                                    hintText: BookingServiceForm.forService(
                                            service.id)
                                        .detailsHint,
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Enter details for ${service.name}.'
                                          : null,
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                                const SizedBox(height: 8),
                                _DeliveryLocationField(
                                  fields: serviceFields[service.id]!,
                                  onChanged: () => setSheetState(() {}),
                                ),
                                const SizedBox(height: 8),
                                _DeliveryDateField(
                                  controller:
                                      serviceFields[service.id]!.deliveryDate,
                                  onChanged: () => setSheetState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
                                  setSheetState(() {
                                    validatingCoupon = true;
                                    couponMessage = null;
                                  });
                                  try {
                                    final serviceId = selectedServices.first;
                                    final coupon = await widget.controller.api
                                        .validateCoupon(
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
                                      couponMessage = error.toString();
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
                    FilledButton(
                      onPressed: loadingPhoneVerification ||
                              selectedServices.isEmpty ||
                              !phoneVerified ||
                              selectedServices.any((id) =>
                                  serviceFields[id]!
                                      .quantity
                                      .text
                                      .trim()
                                      .isEmpty ||
                                  serviceFields[id]!
                                      .details
                                      .text
                                      .trim()
                                      .isEmpty ||
                                  serviceFields[id]!
                                      .location
                                      .text
                                      .trim()
                                      .isEmpty ||
                                  !isChennaiLocation(
                                    address: serviceFields[id]!.location.text,
                                    latitude: serviceFields[id]!.latitude,
                                    longitude: serviceFields[id]!.longitude,
                                  ) ||
                                  DateTime.tryParse(serviceFields[id]!
                                          .deliveryDate
                                          .text
                                          .trim()) ==
                                      null)
                          ? null
                          : () async {
                              if (selectedServices.isEmpty) {
                                setSheetState(() => bookingFormError =
                                    'Select at least one service.');
                                return;
                              }
                              if (!formKey.currentState!.validate()) return;
                              try {
                                final services = selectedServices
                                    .map((serviceId) => BookingServiceDetails(
                                          serviceId: serviceId,
                                          quantity: serviceFields[serviceId]!
                                              .quantity
                                              .text,
                                          details: serviceFields[serviceId]!
                                              .details
                                              .text,
                                          deliveryDate:
                                              serviceFields[serviceId]!
                                                  .deliveryDate
                                                  .text
                                                  .trim(),
                                          location: serviceFields[serviceId]!
                                              .location
                                              .text
                                              .trim(),
                                          latitude: serviceFields[serviceId]!
                                              .latitude,
                                          longitude: serviceFields[serviceId]!
                                              .longitude,
                                        ))
                                    .toList(growable: false);
                                final quotePreview = await widget.controller.api
                                    .previewBookingQuote(
                                  serviceId: services.first.serviceId,
                                  capacity: services.first.quantity,
                                  services: services,
                                  location: services.first.location ?? '',
                                  deliveryDate:
                                      services.first.deliveryDate ?? '',
                                  couponCode: validatedCoupon == null
                                      ? null
                                      : couponController.text.trim(),
                                  phone: phoneController.text,
                                  phoneVerificationChallengeId:
                                      phoneChallengeId,
                                );
                                if (!context.mounted) return;
                                final quote = quotePreview['quote'];
                                final selectedServiceNames =
                                    selectedServices.map(
                                  (id) => _services
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
                                            Text(
                                                'Details: ${services[index].details.trim()}'),
                                            const SizedBox(height: 8),
                                          ],
                                          Text(_quoteSummary(quote)),
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
                                final booking =
                                    await widget.controller.api.createBooking(
                                  serviceId: services.first.serviceId,
                                  capacity: services.first.quantity,
                                  services: services,
                                  location: services.first.location ?? '',
                                  deliveryDate:
                                      services.first.deliveryDate ?? '',
                                  couponCode: validatedCoupon == null
                                      ? null
                                      : couponController.text.trim(),
                                  phone: phoneController.text,
                                  phoneVerificationChallengeId:
                                      phoneChallengeId,
                                );
                                booking['service_details'] = services
                                    .map((service) => service.toJson())
                                    .toList();
                                booking['service_names'] = {
                                  for (final serviceId in selectedServices)
                                    serviceId: _services
                                        .firstWhere((service) =>
                                            service.id == serviceId)
                                        .name,
                                };
                                if (context.mounted) {
                                  Navigator.pop(context, booking);
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
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
    phoneController.dispose();
    otpController.dispose();
    for (final fields in serviceFields.values) {
      fields.dispose();
    }
    if (result != null && mounted) {
      final quote = result['quote'];
      await _showBookingConfirmation(
        result,
        quote is Map<String, dynamic> ? quote : null,
      );
    }
  }

  String _quoteSummary(Object? quote) {
    if (quote is! Map<String, dynamic>) return 'Quote unavailable.';
    String money(Object? value) =>
        value is num ? '₹${(value / 100).toStringAsFixed(2)}' : 'Unavailable';
    return [
      'Subtotal: ${money(quote['subtotalPaise'])}',
      'Discount: ${money(quote['discountPaise'])}',
      'GST: ${money(quote['gstPaise'])}',
      'Total: ${money(quote['totalPaise'])}',
    ].join('\n');
  }

  Future<void> _showBookingConfirmation(
    Map<String, dynamic> booking,
    Map<String, dynamic>? quote,
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
                Text('Details: ${service.details}'),
                const SizedBox(height: 8),
              ],
              for (final line in lines) Text(line),
              const Text('Payment: Cash on delivery'),
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

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final tabs = _tabsForRole(role);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForRole(role)),
        actions: [
          FutureBuilder<List<NotificationItem>>(
            future: _notifications,
            builder: (context, snapshot) {
              final unread = snapshot.data
                      ?.where((notification) => !notification.read)
                      .length ??
                  0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationInbox(
                        controller: widget.controller,
                        role: role.name,
                        onNotificationSelected: _selectNotification,
                      ),
                    ),
                  );
                  if (mounted &&
                      (role == WorkspaceRole.customer ||
                          role == WorkspaceRole.vendor ||
                          role == WorkspaceRole.admin)) {
                    setState(() {
                      _notifications =
                          widget.controller.api.notifications(role.name);
                    });
                  }
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () => _showThemePicker(context),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.controller.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: tabs.map((tab) => _pageFor(tab, user)).toList(),
      ),
      floatingActionButton: role == WorkspaceRole.customer && _index == 0
          ? FloatingActionButton.extended(
              onPressed:
                  _loadingServices || _services.isEmpty ? null : _createBooking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Book water'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }

  List<_Tab> _tabsForRole(WorkspaceRole role) {
    return switch (role) {
      WorkspaceRole.customer => const [
          _Tab('Overview', Icons.home_outlined),
          _Tab('Bookings', Icons.receipt_long_outlined),
          _Tab('Account', Icons.person_outline),
        ],
      WorkspaceRole.vendor => const [
          _Tab('Operations', Icons.dashboard_outlined),
          _Tab('Fleet', Icons.local_shipping_outlined),
          _Tab('Earnings', Icons.payments_outlined),
        ],
      WorkspaceRole.dispatcher => const [
          _Tab('Dispatch', Icons.alt_route_outlined),
          _Tab('Live', Icons.radar_outlined),
          _Tab('Alerts', Icons.warning_amber_outlined),
        ],
      WorkspaceRole.admin => const [
          _Tab('Pulse', Icons.dashboard_outlined),
          _Tab('Operations', Icons.monitor_outlined),
          _Tab('Reports', Icons.analytics_outlined),
        ],
    };
  }

  Widget _pageFor(_Tab tab, SessionUser user) {
    if (role == WorkspaceRole.customer && tab.label == 'Overview') {
      return _customerOverview(user);
    }
    if (role == WorkspaceRole.customer && tab.label == 'Bookings') {
      return BookingsScreen(
        onBookAgain: (booking) => _createBooking(previousBooking: booking),
      );
    }
    if (role == WorkspaceRole.customer && tab.label == 'Account') {
      return const CustomerAccountScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Operations') {
      return const VendorOperationsScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Fleet') {
      return const VendorFleetScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Earnings') {
      return const VendorEarningsScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Pulse') {
      return const AdminPulseScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Operations') {
      return const AdminOperationsScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Reports') {
      return const AdminReportsScreen();
    }
    if (role == WorkspaceRole.dispatcher && tab.label == 'Dispatch') {
      return const DispatcherDispatchScreen();
    }
    if (role == WorkspaceRole.dispatcher && tab.label == 'Live') {
      return const DispatcherLiveScreen();
    }
    if (role == WorkspaceRole.dispatcher && tab.label == 'Alerts') {
      return const DispatcherAlertsScreen();
    }
    return _workspacePage(tab, user);
  }

  Widget _customerOverview(SessionUser user) {
    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Good to see you, ${user.name.split(' ').first}.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Reliable water delivery, without the runaround.'),
          const SizedBox(height: 22),
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF17454D)
                : ink,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEXT DELIVERY',
                      style: TextStyle(color: mint, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('Book a tanker when you need it.',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _services.isEmpty ? null : _createBooking,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Start a booking'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Available services',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loadingServices)
            const Center(child: CircularProgressIndicator())
          else if (_serviceError != null)
            _ErrorCard(message: _serviceError!, onRetry: _loadServices)
          else if (_services.isEmpty)
            const _EmptyCard(message: 'No services are available right now.')
          else
            ..._services.map((service) => _ServiceCard(service: service)),
        ],
      ),
    );
  }

  Widget _workspacePage(_Tab tab, SessionUser user) {
    final copy = switch (role) {
      WorkspaceRole.vendor =>
        'Manage assigned work, fleet, drivers, and payouts.',
      WorkspaceRole.dispatcher =>
        'Coordinate active deliveries and resolve operational exceptions.',
      WorkspaceRole.admin =>
        'Review platform operations, records, finance, and system health.',
      WorkspaceRole.customer => 'Your account activity and saved details.',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(tab.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(copy),
        const SizedBox(height: 22),
        _MetricCard(label: 'Signed in as', value: user.role.name),
        const SizedBox(height: 12),
        _MetricCard(label: 'Realtime', value: 'Connected'),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Native workspace ready'),
            subtitle: Text(
              'This role can only access server-authorized ${user.role.name} operations.',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showThemePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: widget.controller.themeMode,
          onChanged: (value) {
            if (value != null) widget.controller.setThemeMode(value);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (mode) => RadioListTile<ThemeMode>(
                    title: Text(
                      mode.name[0].toUpperCase() + mode.name.substring(1),
                    ),
                    value: mode,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _selectNotification(NotificationItem item) {
    final hasTarget = item.bookingId != null ||
        item.invoiceId != null ||
        item.supportRequestId != null;
    if (!hasTarget) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification has no valid destination.'),
        ),
      );
      return;
    }
    setState(() {
      _index = role == WorkspaceRole.vendor
          ? (item.bookingId != null ? 0 : 2)
          : (item.bookingId != null ? 1 : 2);
    });
    Navigator.of(context).pop();
    unawaited(_openNotificationTarget(item));
  }

  Future<void> _openNotificationTarget(NotificationItem item) async {
    if (role != WorkspaceRole.customer) {
      final target = item.bookingId != null ? 'Operations' : 'this section';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$target selected.')),
      );
      return;
    }
    try {
      final Widget page;
      if (item.bookingId != null) {
        final bookings = await widget.controller.api.bookings();
        final matches =
            bookings.where((booking) => booking.id == item.bookingId);
        if (matches.isEmpty) {
          throw StateError('This booking is no longer available.');
        }
        page = BookingDetailsScreen(booking: matches.first);
      } else if (item.invoiceId != null) {
        page = InvoiceDetailScreen(invoiceId: item.invoiceId!);
      } else if (item.supportRequestId != null) {
        page = SupportRequestDetailScreen(
          requestId: item.supportRequestId!,
        );
      } else {
        throw StateError('This notification has no valid destination.');
      }
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _Tab {
  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _BookingServiceFields {
  _BookingServiceFields({
    required String quantity,
    String details = '',
    String location = '',
    String deliveryDate = '',
    this.latitude,
    this.longitude,
  })  : quantity = TextEditingController(text: quantity),
        details = TextEditingController(text: details),
        location = TextEditingController(text: location),
        deliveryDate = TextEditingController(text: deliveryDate);

  final TextEditingController quantity;
  final TextEditingController details;
  final TextEditingController location;
  final TextEditingController deliveryDate;
  double? latitude;
  double? longitude;

  void dispose() {
    quantity.dispose();
    details.dispose();
    location.dispose();
    deliveryDate.dispose();
  }
}

class _DeliveryLocationField extends StatelessWidget {
  const _DeliveryLocationField({
    required this.fields,
    required this.onChanged,
  });

  final _BookingServiceFields fields;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: fields.location,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: 'Delivery location',
          helperText: fields.latitude == null
              ? 'Chennai addresses only'
              : 'Chennai location selected',
          prefixIcon: IconButton(
            tooltip: 'Choose delivery location',
            onPressed: () async {
              final controller =
                  TextEditingController(text: fields.location.text);
              final value = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Choose delivery location'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Chennai address',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Use location'),
                    ),
                  ],
                ),
              );
              controller.dispose();
              if (value == null) return;
              fields.location.text = value;
              fields.latitude = null;
              fields.longitude = null;
              onChanged();
            },
            icon: const Icon(Icons.map_outlined),
          ),
          suffixIcon: IconButton(
            tooltip: 'Use current location',
            onPressed: () async {
              try {
                if (!await Geolocator.isLocationServiceEnabled()) {
                  throw const FormatException(
                    'Turn on location services first.',
                  );
                }
                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                if (permission == LocationPermission.denied ||
                    permission == LocationPermission.deniedForever) {
                  throw const FormatException(
                    'Location permission is required.',
                  );
                }
                final position = await Geolocator.getCurrentPosition();
                if (!isChennaiLocation(
                  latitude: position.latitude,
                  longitude: position.longitude,
                )) {
                  throw const FormatException(
                    'This location is undeliverable. Select a location inside Chennai.',
                  );
                }
                fields.latitude = position.latitude;
                fields.longitude = position.longitude;
                fields.location.text = 'Current location, Chennai';
                onChanged();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.my_location_outlined),
          ),
          errorMaxLines: 2,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.length < 3) return 'Enter a delivery location.';
          if (!isChennaiLocation(
            address: text,
            latitude: fields.latitude,
            longitude: fields.longitude,
          )) {
            return 'This location is undeliverable. Choose Chennai.';
          }
          return null;
        },
        onChanged: (_) {
          fields.latitude = null;
          fields.longitude = null;
          onChanged();
        },
      );
}

class _DeliveryDateField extends StatelessWidget {
  const _DeliveryDateField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () async {
          final now = DateTime.now();
          final firstDate = DateTime(now.year, now.month, now.day)
              .add(const Duration(days: 1));
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? firstDate,
            firstDate: firstDate,
            lastDate: firstDate.add(const Duration(days: 365)),
          );
          if (picked != null) {
            controller.text = _dateOnly(picked);
            onChanged();
          }
        },
        decoration: const InputDecoration(
          labelText: 'Delivery date',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        validator: (value) {
          final selected = DateTime.tryParse(value?.trim() ?? '');
          final today = DateTime.now();
          final firstDate = DateTime(today.year, today.month, today.day)
              .add(const Duration(days: 1));
          return selected == null || selected.isBefore(firstDate)
              ? 'Choose a future delivery date.'
              : null;
        },
      );
}

String _titleForRole(WorkspaceRole role) => switch (role) {
      WorkspaceRole.customer => 'Urban Tanker',
      WorkspaceRole.vendor => 'Vendor workspace',
      WorkspaceRole.dispatcher => 'Dispatch workspace',
      WorkspaceRole.admin => 'Admin workspace',
    };

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final TankerService service;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: mint,
            child: Icon(Icons.water_drop_outlined, color: ink),
          ),
          title: Text(service.name),
          subtitle: Text(service.description.isEmpty
              ? service.category
              : service.description),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error),
          title: const Text('Could not load services'),
          subtitle: Text(message),
          trailing:
              IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ),
      );
}
