import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/booking.dart';
import '../models/booking_service_form.dart';
import '../services/realtime_service.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({this.onBookAgain, super.key});

  final Future<void> Function(Booking booking)? onBookAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return bookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _BookingMessage(
        icon: Icons.cloud_off_outlined,
        message: error.toString(),
        action: () => ref.invalidate(bookingsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _BookingMessage(
            icon: Icons.receipt_long_outlined,
            message: 'Your bookings will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(bookingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _BookingTile(
              booking: items[index],
              onBookAgain: onBookAgain,
            ),
          ),
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, this.onBookAgain});

  final Booking booking;
  final Future<void> Function(Booking booking)? onBookAgain;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconForStatus(booking.status)),
        ),
        title: Text(booking.reference),
        subtitle: Text(
          '${booking.status.replaceAll('_', ' ')}\n${booking.location}',
        ),
        isThreeLine: true,
        trailing: onBookAgain == null
            ? const Icon(Icons.chevron_right)
            : Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Book these services again',
                    icon: const Icon(Icons.replay_outlined),
                    onPressed: () => onBookAgain!(booking),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(booking: booking),
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen>
    with WidgetsBindingObserver {
  Booking get booking => widget.booking;

  RealtimeService? _realtime;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _refreshTimer;
  bool _liveUpdatesConnected = false;
  String? _liveUpdatesError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
    _connectRealtime();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshTracking(),
    );
  }

  void _connectRealtime() {
    try {
      final controller = ref.read(appControllerProvider);
      final realtime = controller.realtime;
      if (realtime == null) {
        setState(() => _liveUpdatesError = 'Realtime connection unavailable.');
        return;
      }
      _realtime = realtime;
      _liveUpdatesConnected = realtime.isConnected;
      _realtimeSubscription = realtime.events.listen(
        (event) => _onRealtimeEvent(event.name, event.payload),
      );
      realtime.joinBooking(widget.booking.id);
    } catch (error) {
      if (mounted) setState(() => _liveUpdatesError = error.toString());
    }
  }

  void _onRealtimeEvent(String event, dynamic payload) {
    if (event == 'disconnect' || event == 'connect_error') {
      if (mounted) {
        setState(() {
          _liveUpdatesConnected = false;
          _liveUpdatesError = payload.toString();
        });
      }
      return;
    }
    if (event == 'connected') {
      _realtime?.joinBooking(widget.booking.id);
      if (mounted) {
        setState(() {
          _liveUpdatesConnected = true;
          _liveUpdatesError = null;
        });
      }
      return;
    }
    if (payload is! Map ||
        payload['bookingId']?.toString() != widget.booking.id) {
      return;
    }
    if (event == 'booking.location.updated' ||
        event == 'booking.updated' ||
        event == 'notification.created') {
      _refreshTracking();
      if (event != 'booking.location.updated') {
        ref.invalidate(bookingsProvider);
      }
    }
  }

  void _refreshTracking() {
    if (!mounted) return;
    ref.invalidate(bookingTrackingProvider(widget.booking.id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTracking();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final tracking = ref.watch(bookingTrackingProvider(booking.id));
    final currentStatus = tracking.value?.status ?? booking.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(booking.reference),
        actions: [
          IconButton(
            tooltip: 'Refresh tracking',
            onPressed: _refreshTracking,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            currentStatus.replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(booking.location,
              style: Theme.of(context).textTheme.headlineSmall),
          if (booking.latitude != null && booking.longitude != null)
            Text(
              'Delivery coordinates: ${booking.latitude!.toStringAsFixed(5)}, '
              '${booking.longitude!.toStringAsFixed(5)}',
            ),
          if (booking.notes != null && booking.notes!.trim().isNotEmpty)
            Text('Access notes: ${booking.notes}'),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                if (booking.services.isNotEmpty) ...[
                  for (final service in booking.services)
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        BookingServiceForm.forService(service.serviceId)
                            .serviceName,
                      ),
                      subtitle: Text([
                        if (service.quantity.trim().isNotEmpty)
                          'Quantity/capacity: ${service.quantity}',
                        if (service.waterType?.trim().isNotEmpty == true)
                          'Water type: ${service.waterType}',
                        if (service.tankerCount?.trim().isNotEmpty == true)
                          'Tanker count: ${service.tankerCount}',
                        if (service.details.trim().isNotEmpty)
                          'Details: ${service.details}',
                      ].join('\n')),
                      isThreeLine: true,
                    ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('Capacity'),
                  subtitle: Text(
                    booking.capacity.isEmpty
                        ? 'Not specified'
                        : '${booking.capacity} litres',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Delivery date'),
                  subtitle: Text(_formatDate(booking.deliveryDate)),
                ),
                if (booking.quotedAmountRupees != null)
                  ListTile(
                    leading: const Icon(Icons.currency_rupee_outlined),
                    title: const Text('Quoted amount'),
                    subtitle: Text(
                      '₹${booking.quotedAmountRupees!.toStringAsFixed(2)}',
                    ),
                  ),
                if (booking.paymentStatus != null &&
                    booking.paymentStatus!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Payment status'),
                    subtitle:
                        Text(_paymentLabel(booking.normalizedPaymentStatus)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Live tracking',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text(
                _liveUpdatesConnected ? 'Live' : 'Auto-refresh',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (_liveUpdatesError != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Live updates unavailable; checking periodically.'),
            ),
          const SizedBox(height: 8),
          tracking.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Tracking unavailable'),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (snapshot) => Card(
              child: ListTile(
                leading: Icon(
                  snapshot.trackingAvailable
                      ? Icons.location_on_outlined
                      : Icons.location_searching_outlined,
                ),
                title: Text(
                  snapshot.trackingAvailable
                      ? 'Vendor location available'
                      : 'Waiting for vendor location',
                ),
                subtitle: Text([
                  if (snapshot.driver != null) 'Driver: ${snapshot.driver}',
                  if (snapshot.vehicle != null) 'Vehicle: ${snapshot.vehicle}',
                  if (snapshot.latitude != null && snapshot.longitude != null)
                    'Location: ${snapshot.latitude!.toStringAsFixed(5)}, '
                        '${snapshot.longitude!.toStringAsFixed(5)}',
                  if (snapshot.accuracy != null)
                    'Accuracy: ${snapshot.accuracy!.round()} m',
                  if (snapshot.recordedAt != null)
                    'Updated: ${_formatDate(snapshot.recordedAt)}',
                ].join('\n')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!['delivered', 'cancelled'].contains(currentStatus))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Reschedule'),
                  onPressed: () => _reschedule(context, ref),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                  onPressed: () => _cancel(context, ref),
                ),
              ],
            ),
          if (currentStatus == 'arrived')
            FilledButton.icon(
              icon: const Icon(Icons.password_outlined),
              label: const Text('Request delivery OTP'),
              onPressed: () => _requestOtp(context, ref),
            ),
          if (currentStatus == 'delivered')
            FilledButton.icon(
              icon: const Icon(Icons.star_outline),
              label: const Text('Rate delivery'),
              onPressed: () => _rate(context, ref),
            ),
        ],
      ),
    );
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'cod':
        return 'Cash on delivery • Payment due at delivery';
      case 'paid':
        return 'Paid successfully';
      case 'failed':
        return 'Failed • Please contact support to retry payment';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending confirmation';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
            'This action is sent to the server and cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel booking')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.cancelBooking(booking.id);
      ref.invalidate(bookingsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.rescheduleBooking(
            booking.id,
            DateTime(selected.year, selected.month, selected.day, 9),
          );
      ref.invalidate(bookingsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _requestOtp(BuildContext context, WidgetRef ref) async {
    try {
      final expiresAt = await ref
          .read(appControllerProvider)
          .api
          .requestDeliveryOtp(booking.id);
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delivery OTP requested'),
            content: Text(
                'The OTP was sent to your registered mobile number and expires at ${expiresAt.toLocal()}.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'))
            ],
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final review = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: rating,
                items: [1, 2, 3, 4, 5]
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text('$value stars')))
                    .toList(),
                onChanged: (value) => setState(() => rating = value ?? 5),
              ),
              TextField(
                  controller: review,
                  decoration:
                      const InputDecoration(labelText: 'Review (optional)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (submitted != true || !context.mounted) {
      review.dispose();
      return;
    }
    try {
      await ref.read(appControllerProvider).api.rateBooking(
            booking.id,
            rating: rating,
            review: review.text.trim().isEmpty ? null : review.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thank you for rating the delivery.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      review.dispose();
    }
  }
}

class _BookingMessage extends StatelessWidget {
  const _BookingMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: action, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconForStatus(String status) => switch (status) {
      'delivered' => Icons.check_circle_outline,
      'cancelled' => Icons.cancel_outlined,
      'in_transit' || 'arrived' => Icons.local_shipping_outlined,
      _ => Icons.schedule_outlined,
    };

String _formatDate(DateTime? value) {
  if (value == null) return 'Not scheduled';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
