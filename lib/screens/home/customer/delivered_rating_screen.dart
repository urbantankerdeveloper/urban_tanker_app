import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/booking.dart';
import '../../../services/friendly_error.dart';

class DeliveredRatingScreen extends ConsumerStatefulWidget {
  const DeliveredRatingScreen({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<DeliveredRatingScreen> createState() =>
      _DeliveredRatingScreenState();
}

class _DeliveredRatingScreenState extends ConsumerState<DeliveredRatingScreen> {
  final _reviewController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .rateBooking(
            widget.booking.id,
            rating: _rating,
            review: _reviewController.text.trim().isEmpty
                ? null
                : _reviewController.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return AppScaffold(
      title: _submitted ? 'Delivery complete' : 'Rate your delivery',
      body: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _submitted
                      ? Icons.check_circle_outline
                      : Icons.local_shipping_outlined,
                  size: 40,
                  color: colors.onHero,
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  _submitted
                      ? 'Thank you for choosing Urban Tanker.'
                      : 'Your delivery is complete.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onHero,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  widget.booking.reference,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onHero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          if (_submitted)
            SurfaceCard(
              child: Column(
                children: [
                  Icon(Icons.stars_rounded, size: 52, color: colors.warning.fg),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Your feedback helps us improve every delivery.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  PrimaryButton(
                    label: 'Back to bookings',
                    icon: Icons.receipt_long_outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            )
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was your delivery?',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        tooltip: '$value star${value == 1 ? '' : 's'}',
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _rating = value),
                        icon: Icon(
                          value <= _rating ? Icons.star : Icons.star_outline,
                          color: colors.warning.fg,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _reviewController,
                    label: 'Review (optional)',
                    minLines: 3,
                    maxLines: 5,
                    enabled: !_submitting,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              ErrorState(error: _error!, message: _error),
            ],
            const SizedBox(height: AppSpace.lg),
            PrimaryButton(
              label: _submitting ? 'Submitting...' : 'Submit rating',
              icon: Icons.send_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpace.sm),
            GhostButton(
              label: 'Not now',
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}
