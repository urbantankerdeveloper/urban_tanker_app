import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/vendor.dart';
import '../../services/friendly_error.dart';
import 'vendor_shared.dart';

/// Period filters for the payout list. Null means no date limit.
const _periods = <(String, int?)>[
  ('All time', null),
  ('Last 30 days', 30),
  ('Last 90 days', 90),
];

class VendorEarningsScreen extends ConsumerStatefulWidget {
  const VendorEarningsScreen({super.key});

  /// Only one payout request is sent at a time.
  static var _payoutInFlight = false;

  @override
  ConsumerState<VendorEarningsScreen> createState() =>
      _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends ConsumerState<VendorEarningsScreen> {
  int _periodIndex = 0;

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(vendorPayoutsProvider);
    return payouts.when(
      loading: () => const LoadingState(message: 'Loading your earnings...'),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorPayoutsProvider),
      ),
      data: (all) {
        final days = _periods[_periodIndex].$2;
        final now = DateTime.now();
        final items = days == null
            ? all
            : [
                for (final payout in all)
                  if (payout.createdAt != null &&
                      now.difference(payout.createdAt!.toLocal()).inDays <=
                          days)
                    payout,
              ];
        final paidPaise = items
            .where((item) =>
                ['paid', 'completed'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        final pendingPaise = items
            .where((item) =>
                ['pending', 'processing'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        final trend = _trend(items);
        final colors = context.colors;
        final theme = Theme.of(context);

        // Fixed summary above the payout rows; only the rows are built lazily.
        final header = <Widget>[
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAID TO DATE', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpace.sm),
                AmountText(
                  '₹${(paidPaise / 100).toStringAsFixed(2)}',
                  large: true,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Pending and processing: '
                  '₹${(pendingPaise / 100).toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (trend.length > 1) ...[
                  const SizedBox(height: AppSpace.lg),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: SparklinePainter(
                        values: trend,
                        color: colors.onHero,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Based on payout records; this is not an available-balance estimate.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SegmentedTabs(
            labels: [for (final period in _periods) period.$1],
            selectedIndex: _periodIndex,
            onChanged: (index) => setState(() => _periodIndex = index),
          ),
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: 'Request payout',
            icon: Icons.payments_outlined,
            expand: false,
            onPressed: () => _requestPayout(context, ref),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('PAYOUTS', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.sm),
        ];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorPayoutsProvider),
          child: ListView.builder(
            padding: AppPageInsets.withSafeAreaBottom(
              context,
              AppPageInsets.standard,
            ),
            itemCount: header.length + (items.isEmpty ? 1 : items.length),
            itemBuilder: (_, index) {
              if (index < header.length) return header[index];
              if (items.isEmpty) {
                return const VendorEmpty(message: 'No payouts yet.');
              }
              final payout = items[index - header.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _PayoutRow(payout: payout),
              );
            },
          ),
        );
      },
    );
  }

  /// Payout amounts in rupees, oldest first, for the sparkline.
  static List<double> _trend(List<VendorPayout> items) {
    final dated = [
      for (final payout in items)
        if (payout.createdAt != null) payout,
    ]..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    final recent = dated.length > 12 ? dated.sublist(dated.length - 12) : dated;
    return [for (final payout in recent) payout.amountRupees];
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref) async {
    if (VendorEarningsScreen._payoutInFlight) return;
    final request = await showAppBottomSheet<_PayoutRequest>(
      context,
      builder: (_) => const _PayoutRequestSheet(),
    );
    if (request == null || !context.mounted) return;
    VendorEarningsScreen._payoutInFlight = true;
    try {
      await ref.read(appControllerProvider).api.requestVendorPayout(
            amount: request.amount,
            periodStart: request.period?.start,
            periodEnd: request.period?.end,
          );
      ref.invalidate(vendorPayoutsProvider);
      if (context.mounted) {
        showAppSnack(
          context,
          'Payout request submitted.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Payout request failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      VendorEarningsScreen._payoutInFlight = false;
    }
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});

  final VendorPayout payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: AppListRow(
        leading: const Icon(Icons.payments_outlined),
        title: payout.reference.isEmpty ? 'Payout' : payout.reference,
        subtitle: [
          formatDate(payout.createdAt),
          if (payout.periodStart != null || payout.periodEnd != null)
            'Period: ${formatDate(payout.periodStart)} – '
                '${formatDate(payout.periodEnd)}',
        ].join('\n'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountText(
              '₹${payout.amountRupees.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium,
            ),
            Text(payout.status, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// What the payout sheet returns.
class _PayoutRequest {
  const _PayoutRequest({required this.amount, this.period});

  final double amount;
  final DateTimeRange? period;
}

class _PayoutRequestSheet extends StatefulWidget {
  const _PayoutRequestSheet();

  @override
  State<_PayoutRequestSheet> createState() => _PayoutRequestSheetState();
}

class _PayoutRequestSheetState extends State<_PayoutRequestSheet> {
  final _amount = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTimeRange? _period;
  bool _submitted = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    _submitted = true;
    Navigator.pop(context, _PayoutRequest(amount: amount, period: _period));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request payout', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            AppTextField(
              controller: _amount,
              label: 'Amount in rupees',
              prefixText: '₹ ',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a valid amount.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpace.md),
            SecondaryButton(
              label: _period == null
                  ? 'Add earning period (optional)'
                  : '${formatDate(_period!.start)} – '
                      '${formatDate(_period!.end)}',
              icon: Icons.date_range_outlined,
              onPressed: () async {
                final selected = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _period,
                );
                if (selected != null) setState(() => _period = selected);
              },
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Submit',
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
