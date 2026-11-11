import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';

import 'fleet_forms.dart';
import 'records_card.dart';

/// Complaints raised against the vendor's bookings. Add a complaint, or open
/// one to resolve it.
class ComplaintsCard extends ConsumerWidget {
  const ComplaintsCard({required this.orders, super.key});

  final List<VendorOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VendorRecordsCard(
      title: 'Complaints',
      icon: Icons.report_problem_outlined,
      records: ref.watch(vendorComplaintsProvider),
      emptyMessage: 'No complaints recorded.',
      action: () => _createComplaint(context, ref),
      onTap: (record) => _showComplaint(context, ref, record),
    );
  }

  Future<void> _createComplaint(BuildContext context, WidgetRef ref) async {
    if (orders.isEmpty) {
      showAppSnack(
        context,
        'A booking is required to create a complaint.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    final subject = TextEditingController();
    final message = TextEditingController();
    var bookingId = orders.first.id;
    final saved = await showRecordSheet(
      context,
      title: 'Create complaint',
      fields: [('Subject', subject), ('Message', message)],
      requireAll: true,
      extra: DropdownButtonFormField<String>(
        initialValue: bookingId,
        decoration: const InputDecoration(labelText: 'Booking'),
        items: orders
            .map((order) => DropdownMenuItem(
                  value: order.id,
                  child: Text(order.reference),
                ))
            .toList(),
        onChanged: (value) => bookingId = value ?? bookingId,
      ),
      submit: () async {
        await ref.read(appControllerProvider).api.createVendorComplaint(
              bookingId: bookingId,
              subject: subject.text.trim(),
              message: message.text.trim(),
            );
      },
    );
    subject.dispose();
    message.dispose();
    if (saved && context.mounted) {
      ref.invalidate(vendorComplaintsProvider);
      showAppSnack(
        context,
        'Complaint submitted.',
        variant: AppSnackVariant.success,
      );
    }
  }

  Future<void> _showComplaint(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> record,
  ) async {
    final resolution = TextEditingController(
      text: (record['message'] ?? record['response'] ?? '').toString(),
    );
    final status = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: (record['subject'] ?? 'Complaint').toString(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text((record['message'] ?? '').toString()),
            const SizedBox(height: AppSpace.md),
            AppTextField(
              controller: resolution,
              label: 'Resolution / response',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'resolved'),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (status == null || !context.mounted) {
      resolution.dispose();
      return;
    }
    try {
      await ref.read(appControllerProvider).api.updateVendorComplaint(
            id: (record['id'] ?? '').toString(),
            status: status,
            resolution: resolution.text,
          );
      ref.invalidate(vendorComplaintsProvider);
      if (context.mounted) {
        showAppSnack(
          context,
          'Complaint updated.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Complaint update failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      resolution.dispose();
    }
  }
}
