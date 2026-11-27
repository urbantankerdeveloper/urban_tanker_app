import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_feature_flags.dart';
import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';

enum AdminReviewKind { vendor, driver }

class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({
    required this.kind,
    required this.record,
    required this.onUpdated,
    super.key,
  });

  final AdminReviewKind kind;
  final Map<String, dynamic> record;
  final VoidCallback onUpdated;

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  bool _busy = false;

  String get _id => (widget.record['id'] ?? '').toString();
  String get _status => (widget.record['verification'] ?? 'pending').toString();

  String get _title => switch (widget.kind) {
    AdminReviewKind.vendor =>
      (widget.record['business_name'] ?? 'Vendor application').toString(),
    AdminReviewKind.driver =>
      (widget.record['name'] ?? widget.record['full_name'] ?? 'Driver')
          .toString(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVendor = widget.kind == AdminReviewKind.vendor;
    final fields = isVendor
        ? <(String, String)>[
            ('Business name', _title),
            ('Contact number', _value('phone_e164')),
            ('Email', _value('email')),
            ('Service area', _value('service_zone')),
            ('Verification', StatusChip.statusLabel(_status)),
            (
              'Availability',
              widget.record['is_online'] == true ? 'Online' : 'Offline',
            ),
          ]
        : <(String, String)>[
            ('Driver name', _title),
            ('Contact number', _value('mobile_e164')),
            ('Licence number', _value('licence_number')),
            ('Verification', StatusChip.statusLabel(_status)),
            (
              'Availability',
              widget.record['is_active'] == true ? 'Active' : 'Inactive',
            ),
          ];
    final documents = widget.record['documents'];
    return AppScaffold(
      title: isVendor ? 'Review vendor' : 'Review driver',
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
                  isVendor ? Icons.storefront_outlined : Icons.badge_outlined,
                  size: 40,
                  color: context.colors.onHero,
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  _title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: context.colors.onHero,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                StatusChip(
                  label: StatusChip.statusLabel(_status),
                  tone: context.colors.statusTone(_status),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Application details', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  AppListRow(
                    title: fields[index].$1,
                    subtitle: fields[index].$2,
                  ),
                  if (index < fields.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Documents', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          if (documents is List && documents.isNotEmpty)
            for (final document in documents.whereType<Map>())
              SurfaceCard(
                child: AppListRow(
                  leading: const Icon(Icons.description_outlined),
                  title:
                      (document['name'] ??
                              document['document_type'] ??
                              'Submitted document')
                          .toString(),
                  subtitle: StatusChip.statusLabel(
                    (document['verification'] ?? 'submitted').toString(),
                  ),
                ),
              )
          else
            const NewUiEmptyState(
              icon: Icons.description_outlined,
              title: 'No document details available',
              message:
                  'Document records are not included in the current review response.',
            ),
          const SizedBox(height: AppSpace.xl),
          if (_status.toLowerCase() != 'approved')
            PrimaryButton(
              label: _busy ? 'Updating...' : 'Approve application',
              icon: Icons.check_circle_outline,
              onPressed: _busy ? null : () => _updateStatus('approved'),
            ),
          if (_status.toLowerCase() != 'rejected') ...[
            const SizedBox(height: AppSpace.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _updateStatus('rejected'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject application'),
            ),
          ],
          if (AuthFeatureFlags.newUiEnabled &&
              isVendor &&
              _status.toLowerCase() == 'approved') ...[
            const SizedBox(height: AppSpace.sm),
            SecondaryButton(
              label: 'Suspend vendor',
              icon: Icons.pause_circle_outline,
              onPressed: _busy ? null : () => _updateStatus('suspended'),
            ),
          ],
        ],
      ),
    );
  }

  String _value(String key) {
    final value = widget.record[key]?.toString().trim() ?? '';
    return value.isEmpty ? 'Not provided' : value;
  }

  Future<void> _updateStatus(String status) async {
    if (_id.isEmpty) {
      showAppSnack(
        context,
        'This review record has no identifier.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: status == 'approved'
          ? 'Approve application?'
          : 'Reject application?',
      message: 'Update $_title to ${StatusChip.statusLabel(status)}?',
      confirmLabel: status == 'approved' ? 'Approve' : 'Confirm',
      destructive: status != 'approved',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(appControllerProvider).api;
      if (widget.kind == AdminReviewKind.vendor) {
        await api.updateVendorVerification(_id, status);
      } else {
        await api.updateAdminDriverStatus(
          _id,
          verification: status,
          isActive: status == 'approved',
        );
      }
      if (!mounted) return;
      widget.onUpdated();
      showAppSnack(
        context,
        'Application ${StatusChip.statusLabel(status).toLowerCase()}.',
        variant: AppSnackVariant.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(error),
        variant: AppSnackVariant.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
