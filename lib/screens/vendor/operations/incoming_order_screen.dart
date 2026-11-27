import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../common/booking_format.dart';

/// Foreground offer screen for a newly received vendor order.
class IncomingOrderScreen extends StatefulWidget {
  const IncomingOrderScreen({
    required this.order,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
    super.key,
  });

  static const responseWindow = Duration(seconds: 45);

  final VendorOrder order;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final Future<void> Function() onTimeout;

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen> {
  late int _secondsRemaining = IncomingOrderScreen.responseWindow.inSeconds;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _expire();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final order = widget.order;

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPageInsets.standard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text('INCOMING ORDER', style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              Center(
                child: SizedBox.square(
                  dimension: AppSize.incomingOrderTimer,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Semantics(
                        label: '$_secondsRemaining seconds to respond',
                        child: CircularProgressIndicator(
                          value:
                              _secondsRemaining /
                              IncomingOrderScreen.responseWindow.inSeconds,
                          strokeWidth: AppSize.incomingOrderTimerStroke,
                          backgroundColor: colors.hairline,
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        '$minutes:$seconds',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                order.reference,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                order.serviceCode.isEmpty
                    ? 'Service details unavailable'
                    : order.serviceCode,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.lg),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppListRow(
                      leading: const Icon(Icons.location_on_outlined),
                      title: order.address.isEmpty
                          ? 'Address unavailable'
                          : order.address,
                    ),
                    AppListRow(
                      leading: const Icon(Icons.schedule_outlined),
                      title: formatBookingDate(order.scheduledFor),
                    ),
                    AppListRow(
                      leading: const Icon(Icons.currency_rupee),
                      title: '₹${order.amountRupees.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              PrimaryButton(
                label: 'Accept order',
                icon: Icons.check_circle_outline,
                onPressed: _completed ? null : _accept,
              ),
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger.fg,
                  side: BorderSide(color: colors.danger.border),
                  minimumSize: const Size(64, AppSize.buttonHeight),
                ),
                onPressed: _completed ? null : _decline,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _accept() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
    unawaited(widget.onAccept());
  }

  void _decline() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
    unawaited(widget.onDecline());
  }

  void _expire() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
    unawaited(widget.onTimeout());
  }
}
