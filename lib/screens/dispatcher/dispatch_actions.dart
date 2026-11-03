import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/account.dart';
import '../../models/dispatcher.dart';

/// Actions for one dispatch order, in a sheet.
Future<void> showDispatchActions(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> order,
) async {
  final action = await showAppBottomSheet<String>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListRow(
            leading: const Icon(Icons.receipt_long_outlined),
            title: 'View order details',
            onTap: () => Navigator.pop(sheetContext, 'details'),
          ),
          AppListRow(
            leading: const Icon(Icons.assignment_ind_outlined),
            title: 'Assign vendor / fleet',
            onTap: () => Navigator.pop(sheetContext, 'assign'),
          ),
          AppListRow(
            leading: const Icon(Icons.sync_alt_outlined),
            title: 'Update status',
            onTap: () => Navigator.pop(sheetContext, 'status'),
          ),
          AppListRow(
            leading: const Icon(Icons.cancel_outlined),
            title: 'Cancel order',
            onTap: () => Navigator.pop(sheetContext, 'cancel'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case 'details':
      showOrderDetails(context, order);
    case 'assign':
      await assignOrder(context, ref, order);
    case 'status':
      await updateOrderStatus(context, ref, order);
    case 'cancel':
      await cancelOrder(context, ref, order);
  }
}

void showOrderDetails(BuildContext context, Map<String, dynamic> order) {
  final details = <String, dynamic>{
    'Reference': order['reference'] ?? order['id'],
    'Status': order['status'] ?? '—',
    'Service': order['service_code'] ?? '—',
    'Address': order['address_text'] ?? '—',
    'Amount':
        '₹${((order['quoted_amount_paise'] as num?)?.toDouble() ?? 0) / 100}',
    'Schedule': order['scheduled_for'] ?? '—',
    'Vendor': order['vendor_id'] ?? 'Unassigned',
    'Vehicle': order['vehicle_id'] ?? 'Unassigned',
    'Driver': order['driver_id'] ?? 'Unassigned',
    'Cancellation reason':
        order['cancellation_reason'] ?? order['cancellationReason'] ?? '—',
  };
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: 'Dispatch order details',
      message: details.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Assigns an approved vendor to the order, chosen in the vendor picker.
Future<void> assignOrder(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> order,
) async {
  final vendors = await ref.read(dispatcherVendorsProvider.future);
  final eligible = vendors
      .where((vendor) =>
          vendor.status == 'approved' ||
          vendor.data['verification'] == 'approved')
      .toList();
  if (!context.mounted) return;
  if (eligible.isEmpty) {
    showAppSnack(
      context,
      'No approved vendors are available.',
      variant: AppSnackVariant.error,
    );
    return;
  }
  final vendorId = await pickVendor(context, eligible);
  if (vendorId == null || !context.mounted) return;
  try {
    await ref.read(appControllerProvider).api.dispatcherAssignOrder(
          order['id'].toString(),
          vendorId: vendorId,
        );
    ref.invalidate(dispatcherOrdersProvider);
    if (context.mounted) {
      showAppSnack(
        context,
        'Order assigned.',
        variant: AppSnackVariant.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Assignment failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }
}

/// Vendor picker sheet. Resolves to the chosen vendor id, or null.
Future<String?> pickVendor(BuildContext context, List<AccountRecord> vendors) {
  return showAppBottomSheet<String>(
    context,
    builder: (_) => _VendorPickerSheet(vendors: vendors),
  );
}

class _VendorPickerSheet extends StatefulWidget {
  const _VendorPickerSheet({required this.vendors});

  final List<AccountRecord> vendors;

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  late String _selected = widget.vendors.first.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Assign vendor', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpace.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final vendor in widget.vendors)
                  AppListRow(
                    leading: Icon(
                      vendor.id == _selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: context.colors.primary,
                    ),
                    title: vendor.title,
                    onTap: () => setState(() => _selected = vendor.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
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
                  label: 'Assign',
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> updateOrderStatus(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> order,
) async {
  final allowed = DispatcherOrder.fromJson(order).allowedNextStatuses;
  if (allowed.isEmpty) {
    showAppSnack(
      context,
      'No status transitions are available for this order.',
      variant: AppSnackVariant.error,
    );
    return;
  }
  final value = await showAppBottomSheet<String>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in allowed)
            AppListRow(
              leading: const Icon(Icons.sync_alt_outlined),
              title: StatusChip.statusLabel(status),
              onTap: () => Navigator.pop(sheetContext, status),
            ),
        ],
      ),
    ),
  );
  if (value == null || !context.mounted) return;
  try {
    await ref.read(appControllerProvider).api.dispatcherUpdateStatus(
          order['id'].toString(),
          value,
        );
    ref.invalidate(dispatcherOrdersProvider);
    if (context.mounted) {
      showAppSnack(
        context,
        'Order status updated.',
        variant: AppSnackVariant.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Status update failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }
}

/// Cancels an order. A reason is required; the sheet keeps the order if the
/// reason is left empty.
Future<void> cancelOrder(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> order,
) async {
  final reason = await showAppBottomSheet<String>(
    context,
    builder: (_) => const _CancelSheet(),
  );
  if (reason == null || reason.isEmpty || !context.mounted) return;
  try {
    await ref.read(appControllerProvider).api.dispatcherCancelOrder(
          order['id'].toString(),
          reason,
        );
    ref.invalidate(dispatcherOrdersProvider);
    if (context.mounted) {
      showAppSnack(
        context,
        'Order cancelled.',
        variant: AppSnackVariant.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Cancellation failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cancel order', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          AppTextField(
            controller: _reason,
            label: 'Cancellation reason',
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Keep',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.danger.fg,
                    side: BorderSide(color: colors.danger.border),
                    minimumSize: const Size(64, AppSize.buttonHeight),
                  ),
                  onPressed: () => Navigator.pop(context, _reason.text.trim()),
                  child: const Text('Cancel order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
