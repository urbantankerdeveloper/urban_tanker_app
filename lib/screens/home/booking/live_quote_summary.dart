import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/booking_service_details.dart';
import '../../../services/api_client.dart';
import '../../../services/friendly_error.dart';

String formatQuoteSummary(Object? quote) {
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

class LiveQuoteSummary extends StatefulWidget {
  const LiveQuoteSummary({
    super.key,
    required this.api,
    required this.services,
    required this.phone,
    required this.paymentMethod,
    this.couponCode,
  });

  final ApiClient api;
  final List<BookingServiceDetails> services;
  final String phone;
  final String paymentMethod;
  final String? couponCode;

  @override
  State<LiveQuoteSummary> createState() => _LiveQuoteSummaryState();
}

class _LiveQuoteSummaryState extends State<LiveQuoteSummary> {
  static const _debounceDelay = Duration(milliseconds: 400);

  Timer? _debounce;
  String _lastKey = '';
  int _requestCount = 0;
  bool _loading = false;
  Object? _quote;
  String? _error;

  String get _inputKey => [
        for (final service in widget.services)
          [
            service.serviceId,
            service.quantity,
            service.waterType,
            service.tankerCount,
            service.details,
            service.deliveryDate,
            service.location,
            service.latitude,
            service.longitude,
          ].join('|'),
        widget.phone,
        widget.paymentMethod,
        widget.couponCode ?? '',
      ].join('\n');

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant LiveQuoteSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_inputKey != _lastKey) setState(_schedule);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    final key = _inputKey;
    _lastKey = key;
    _debounce?.cancel();
    _error = null;
    if (widget.services.isEmpty) {
      _loading = false;
      _quote = null;
      return;
    }
    _loading = true;
    _debounce = Timer(_debounceDelay, () => _fetch(key));
  }

  Future<void> _fetch(String key) async {
    final requestId = ++_requestCount;
    final first = widget.services.first;
    try {
      final response = await widget.api.previewBookingQuote(
        serviceId: first.serviceId,
        capacity: first.quantity,
        services: widget.services,
        location: first.location ?? '',
        deliveryDate: first.deliveryDate ?? '',
        paymentMethod: widget.paymentMethod,
        latitude: first.latitude,
        longitude: first.longitude,
        couponCode: widget.couponCode,
        phone: widget.phone,
      );
      if (!mounted || requestId != _requestCount || key != _lastKey) return;
      setState(() {
        _loading = false;
        _quote = response['quote'];
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestCount || key != _lastKey) return;
      setState(() {
        _loading = false;
        _quote = null;
        _error = friendlyError(error);
      });
    }
  }

  void _retry() => setState(_schedule);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.services.isEmpty) {
      return Text(
        'Complete the service details to see the price.',
        style: theme.textTheme.bodyMedium,
      );
    }
    if (_loading) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Calculating price…')),
        ],
      );
    }
    if (_error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Price unavailable: $_error',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          TextButton(onPressed: _retry, child: const Text('Retry')),
        ],
      );
    }
    return Semantics(
      liveRegion: true,
      child: Text(
        formatQuoteSummary(_quote),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
