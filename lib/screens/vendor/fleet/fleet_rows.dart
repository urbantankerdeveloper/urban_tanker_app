import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../vendor_shared.dart';
import 'fleet_forms.dart';

/// Vehicle card: registration, capacity, verification, and an availability
/// switch. Tapping the card edits the vehicle.
class VehicleTile extends ConsumerWidget {
  const VehicleTile({required this.vehicle, super.key});

  final VendorVehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => editVehicle(context, ref, vehicle),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: colors.mint, shape: BoxShape.circle),
            child: Icon(Icons.local_shipping_outlined, color: colors.ink),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.registrationNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${vehicle.capacityLitres} litres',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.xs),
                StatusChip(
                  label: StatusChip.statusLabel(vehicle.verification),
                  icon: Icons.verified_outlined,
                  tone: verificationTone(colors, vehicle.verification),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: vehicle.active,
                onChanged: (value) =>
                    setVehicleActive(context, ref, vehicle, value),
              ),
              Text(
                vehicle.active ? 'Available' : 'Unavailable',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Driver row with an avatar, verification, and an attendance menu.
class DriverTile extends ConsumerWidget {
  const DriverTile({required this.driver, super.key});

  final VendorDriver driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => editDriver(context, ref, driver),
      child: Row(
        children: [
          AppAvatar(name: driver.name, size: 44),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${driver.mobile} • ${StatusChip.statusLabel(driver.verification)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: verificationTone(colors, driver.verification).fg,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Attendance',
            onSelected: (status) =>
                setDriverAttendance(context, ref, driver, status),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'present', child: Text('Mark present')),
              PopupMenuItem(value: 'absent', child: Text('Mark absent')),
              PopupMenuItem(value: 'on_leave', child: Text('Mark on leave')),
            ],
          ),
        ],
      ),
    );
  }
}
