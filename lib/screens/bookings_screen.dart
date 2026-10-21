import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/booking.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

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
            itemBuilder: (context, index) =>
                _BookingTile(booking: items[index]),
          ),
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(booking: booking),
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends ConsumerWidget {
  const BookingDetailsScreen({required this.booking, super.key});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(bookingTrackingProvider(booking.id));
    return Scaffold(
      appBar: AppBar(title: Text(booking.reference)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            booking.status.replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(booking.location,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
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
          Text('Live tracking', style: Theme.of(context).textTheme.titleLarge),
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
                  if (snapshot.recordedAt != null)
                    'Updated: ${_formatDate(snapshot.recordedAt)}',
                ].join('\n')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!['delivered', 'cancelled'].contains(booking.status))
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
          if (booking.status == 'arrived')
            FilledButton.icon(
              icon: const Icon(Icons.password_outlined),
              label: const Text('Request delivery OTP'),
              onPressed: () => _requestOtp(context, ref),
            ),
          if (booking.status == 'delivered')
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
