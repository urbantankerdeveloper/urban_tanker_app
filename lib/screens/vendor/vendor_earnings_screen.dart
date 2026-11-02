import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/page_components.dart';
import '../../services/friendly_error.dart';
import 'vendor_shared.dart';

class VendorEarningsScreen extends ConsumerWidget {
  const VendorEarningsScreen({super.key});

  /// Only one payout request is sent at a time.
  static var _payoutInFlight = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(vendorPayoutsProvider);
    return payouts.when(
      loading: () => const AppStateView.loading(),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorPayoutsProvider),
      ),
      data: (items) {
        final paidPaise = items
            .where((item) =>
                ['paid', 'completed'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        final pendingPaise = items
            .where((item) =>
                ['pending', 'processing'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        // Fixed summary above the payout rows; only the rows are built lazily.
        final header = <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payout summary',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Paid: ₹${(paidPaise / 100).toStringAsFixed(2)}',
                  ),
                  Text(
                    'Pending/processing: '
                    '₹${(pendingPaise / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on payout records; this is not an available-balance estimate.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _requestPayout(context, ref),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Request payout'),
            ),
          ),
          const SizedBox(height: 8),
        ];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorPayoutsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: header.length + (items.isEmpty ? 1 : items.length),
            itemBuilder: (_, index) {
              if (index < header.length) return header[index];
              if (items.isEmpty) {
                return const VendorEmpty(message: 'No payouts yet.');
              }
              final payout = items[index - header.length];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text('₹${payout.amountRupees.toStringAsFixed(2)}'),
                  subtitle: Text([
                    payout.reference,
                    formatDate(payout.createdAt),
                    if (payout.periodStart != null || payout.periodEnd != null)
                      'Period: ${formatDate(payout.periodStart)} – '
                          '${formatDate(payout.periodEnd)}',
                  ].join('\n')),
                  trailing: Text(payout.status),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref) async {
    if (_payoutInFlight) return;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTimeRange? period;
    var dialogSubmitted = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request payout'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount in rupees',
                    prefixText: '₹ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter a valid amount.'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: period,
                    );
                    if (selected != null) {
                      setDialogState(() => period = selected);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    period == null
                        ? 'Add earning period (optional)'
                        : '${formatDate(period!.start)} – '
                            '${formatDate(period!.end)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogSubmitted) return;
                if (formKey.currentState!.validate()) {
                  dialogSubmitted = true;
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (submitted != true || amount == null || !context.mounted) return;
    _payoutInFlight = true;
    try {
      await ref.read(appControllerProvider).api.requestVendorPayout(
            amount: amount,
            periodStart: period?.start,
            periodEnd: period?.end,
          );
      ref.invalidate(vendorPayoutsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout request submitted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout request failed: $error')),
        );
      }
    } finally {
      _payoutInFlight = false;
    }
  }
}
