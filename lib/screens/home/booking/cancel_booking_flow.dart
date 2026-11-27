import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/booking.dart';

const cancellationReasons = [
  'I no longer need this delivery',
  'I booked the wrong service',
  'I need to change the delivery time',
  'I need to change the delivery address',
  'Other',
];

Future<String?> showCancelBookingReasonSheet(BuildContext context) {
  return showAppBottomSheet<String>(
    context,
    builder: (_) => const _CancellationReasonSheet(),
  );
}

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet();

  @override
  State<_CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  final _otherReason = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _otherReason.dispose();
    super.dispose();
  }

  String? get _reason {
    if (_selectedReason == 'Other') {
      final value = _otherReason.text.trim();
      return value.length >= 2 && value.length <= 500 ? value : null;
    }
    return _selectedReason;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Why are you cancelling?',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Choose a reason to help us improve your delivery experience.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.md),
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: (value) => setState(() {
                  _selectedReason = value;
                }),
                child: Column(
                  children: [
                    for (final reason in cancellationReasons)
                      RadioListTile<String>(
                        value: reason,
                        title: Text(reason),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (_selectedReason == 'Other') ...[
                const SizedBox(height: AppSpace.sm),
                AppTextField(
                  controller: _otherReason,
                  label: 'Tell us why',
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              PrimaryButton(
                label: 'Continue cancellation',
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop(_reason),
              ),
              const SizedBox(height: AppSpace.sm),
              SecondaryButton(
                label: 'Keep booking',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderCancelledScreen extends StatelessWidget {
  const OrderCancelledScreen({
    required this.booking,
    required this.reason,
    super.key,
  });

  final Booking booking;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Order cancelled',
      body: Center(
        child: SingleChildScrollView(
          padding: AppPageInsets.standard,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: colors.success.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: colors.success.fg,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Your order is cancelled',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Booking ${booking.reference} has been cancelled.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpace.xl),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancellation reason',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(reason, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: 'Back to bookings',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
