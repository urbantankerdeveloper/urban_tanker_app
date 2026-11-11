import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../services/friendly_error.dart';

/// Expandable card shell for a fleet section, with an optional trailing action.
class FleetCardShell extends StatelessWidget {
  const FleetCardShell({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
    this.subtitle,
    this.action,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: context.colors.primary),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: theme.textTheme.bodySmall),
          trailing: action,
          children: children,
        ),
      ),
    );
  }
}

/// A fleet card that lists records from [loader]. The records load once per
/// mounted card, so rebuilds do not call the API again.
class VendorRecordsCard extends StatelessWidget {
  const VendorRecordsCard({
    required this.title,
    required this.icon,
    required this.records,
    required this.emptyMessage,
    super.key,
    this.action,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final AsyncValue<List<Map<String, dynamic>>> records;
  final String emptyMessage;
  final VoidCallback? action;
  final void Function(Map<String, dynamic> record)? onTap;

  @override
  Widget build(BuildContext context) {
    return FleetCardShell(
      title: title,
      icon: icon,
      action: action == null
          ? null
          : IconButton(
              tooltip: 'Add',
              onPressed: action,
              icon: const Icon(Icons.add),
            ),
      children: [
        records.when(
          loading: () => const Padding(
            padding: AppPageInsets.card,
            child: SkeletonBox(height: 48),
          ),
          error: (error, _) => AppListRow(
            title: 'Could not load $title',
            subtitle: friendlyError(error),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AppListRow(title: emptyMessage);
            }
            return Column(
              children: [
                for (final record in items)
                  AppListRow(
                    title: (record['subject'] ??
                            record['document_type'] ??
                            record['documentType'] ??
                            'Record')
                        .toString(),
                    subtitle: (record['status'] ??
                            record['verification'] ??
                            record['object_key'] ??
                            record['objectKey'] ??
                            '')
                        .toString(),
                    onTap: onTap == null ? null : () => onTap!(record),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
