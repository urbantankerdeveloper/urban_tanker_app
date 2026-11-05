import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../../services/friendly_error.dart';

/// Saved update records that the server could not apply. They are shown here
/// and can be discarded. Failed actions are never replayed automatically.
class SavedUpdatesCard extends ConsumerStatefulWidget {
  const SavedUpdatesCard({super.key});

  @override
  ConsumerState<SavedUpdatesCard> createState() => _SavedUpdatesCardState();
}

class _SavedUpdatesCardState extends ConsumerState<SavedUpdatesCard> {
  final Set<String> _processing = {};

  Future<void> _discard(VendorOfflineMutation mutation) async {
    setState(() => _processing.add(mutation.id));
    try {
      await ref
          .read(appControllerProvider)
          .api
          .discardVendorMutation(mutation.id);
      ref
        ..invalidate(vendorOfflineMutationsProvider)
        ..invalidate(vendorOrdersProvider);
      if (mounted) {
        showAppSnack(
          context,
          'Update record discarded.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not update queued item: $error',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(mutation.id));
    }
  }

  Future<void> _confirmDiscard(VendorOfflineMutation mutation) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Discard update record?',
      message: 'This removes the saved update record.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (confirmed && mounted) await _discard(mutation);
  }

  @override
  Widget build(BuildContext context) {
    final mutations = ref.watch(vendorOfflineMutationsProvider);
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.sync_problem_outlined),
          title: Text(
            'Saved update records',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            'Server logs only; failed actions are not auto-replayed.',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            mutations.when(
              loading: () => const Padding(
                padding: AppPageInsets.card,
                child: SkeletonBox(height: 48),
              ),
              error: (error, _) => AppListRow(
                title: 'Could not load pending mutations',
                subtitle: friendlyError(error),
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(vendorOfflineMutationsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const AppListRow(title: 'No saved update records.')
                  : Column(
                      children: [
                        for (final item in items)
                          AppListRow(
                            title: '${item.type} • ${item.entityType}'
                                '${item.entityId == null ? '' : ' ${item.entityId}'}',
                            subtitle: item.lastError ??
                                item.status.replaceAll('_', ' '),
                            trailing: IconButton(
                              tooltip: 'Discard',
                              onPressed: _processing.contains(item.id)
                                  ? null
                                  : () => _confirmDiscard(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
