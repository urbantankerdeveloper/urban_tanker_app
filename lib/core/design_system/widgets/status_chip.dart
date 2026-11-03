import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Status pill. Shows an icon and text, so the status does not rely on color.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    super.key,
    this.icon,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// Turns `pending_vendor` into `Pending vendor`.
  static String statusLabel(String status) {
    final words = status.replaceAll('_', ' ').trim();
    if (words.isEmpty) return words;
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: tone.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: tone.fg),
                const SizedBox(width: AppSpace.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: tone.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip for a backend booking status such as `pending_vendor`. The tone and
/// icon both come from the status, so light and dark stay consistent.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: StatusChip.statusLabel(status),
        icon: _statusIcon(status),
        tone: context.colors.statusTone(status),
      );
}

IconData? _statusIcon(String status) => switch (status) {
      'pending' || 'pending_vendor' => Icons.schedule,
      'accepted' || 'vendor_accepted' => Icons.thumb_up_alt_outlined,
      'assigned' || 'vendor_assigned' => Icons.person_pin_circle_outlined,
      'in_transit' ||
      'on_the_way' ||
      'en_route' =>
        Icons.local_shipping_outlined,
      'arrived' => Icons.place_outlined,
      'delivered' || 'completed' => Icons.check_circle_outline,
      'cancelled' || 'canceled' => Icons.cancel_outlined,
      'rejected' => Icons.block,
      _ => null,
    };
