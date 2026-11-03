import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../../services/friendly_error.dart';
import '../vendor_shared.dart';
import 'records_card.dart';

/// Attendance for one day. The date picker chooses the day to show.
class AttendanceCard extends ConsumerStatefulWidget {
  const AttendanceCard({required this.drivers, super.key});

  final List<VendorDriver> drivers;

  @override
  ConsumerState<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<AttendanceCard> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return FleetCardShell(
      title: 'Attendance history',
      icon: Icons.event_available_outlined,
      subtitle: formatDate(selectedDate),
      children: [
        AppListRow(
          title: 'Select date',
          trailing: IconButton(
            tooltip: 'Choose date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final value = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: selectedDate,
              );
              if (value != null) setState(() => selectedDate = value);
            },
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: ref.watch(vendorAttendanceProvider(selectedDate).future),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppListRow(
                title: 'Could not load this section',
                subtitle: friendlyError(snapshot.error!),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: SkeletonBox(height: 48),
              );
            }
            final records = snapshot.data ?? const [];
            if (records.isEmpty) {
              return const AppListRow(title: 'No attendance recorded.');
            }
            return Column(
              children: [
                for (final record in records)
                  AppListRow(
                    title: widget.drivers
                        .firstWhere(
                          (item) => item.id == record['driver_id'],
                          orElse: () => const VendorDriver(
                            id: '',
                            name: 'Driver',
                            mobile: '',
                            active: false,
                            verification: '',
                          ),
                        )
                        .name,
                    trailing: Text(
                      (record['status'] ?? '').toString(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
