import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/dispatcher.dart';
import '../../services/friendly_error.dart';
import 'dispatch_order_card.dart';
import 'dispatch_urgency.dart';

/// Dispatch queue: orders sorted by urgency, with filters and paging.
class DispatcherDispatchScreen extends ConsumerStatefulWidget {
  const DispatcherDispatchScreen({super.key});

  @override
  ConsumerState<DispatcherDispatchScreen> createState() =>
      _DispatcherDispatchScreenState();
}

class _DispatcherDispatchScreenState
    extends ConsumerState<DispatcherDispatchScreen> {
  String? status;
  String? service;
  String? vendorId;
  String? from;
  String? to;
  bool? assigned;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = DispatcherOrderFilter(
      page: page,
      status: status,
      service: service,
      vendorId: vendorId,
      from: from,
      to: to,
      assigned: assigned,
    );
    final orders = ref.watch(dispatcherOrdersProvider(filter));
    final vendors = ref.watch(dispatcherVendorsProvider);
    // Fixed filters above the queue. Only the order cards are built lazily.
    final header = <Widget>[
      DropdownButtonFormField<String?>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Filter status'),
        items: const [
          DropdownMenuItem(value: null, child: Text('All statuses')),
          DropdownMenuItem(
            value: 'pending_vendor',
            child: Text('Pending assignment'),
          ),
          DropdownMenuItem(value: 'vendor_assigned', child: Text('Assigned')),
          DropdownMenuItem(value: 'en_route', child: Text('En route')),
          DropdownMenuItem(value: 'arrived', child: Text('Arrived')),
          DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
        ],
        onChanged: (value) => setState(() {
          status = value;
          page = 1;
        }),
      ),
      const SizedBox(height: AppSpace.md),
      AppTextField(
        label: 'Service code',
        prefix: const Icon(Icons.water_drop_outlined),
        onChanged: (value) => setState(() {
          service = value.trim().isEmpty ? null : value.trim();
          page = 1;
        }),
      ),
      const SizedBox(height: AppSpace.md),
      vendors.when(
        loading: () => const SkeletonBox(height: 56),
        error: (error, _) => AppStateInline.error(
          error: error,
          message: 'Vendor filter unavailable: $error',
          onRetry: () => ref.invalidate(dispatcherVendorsProvider),
        ),
        data: (items) => DropdownButtonFormField<String?>(
          initialValue: vendorId,
          decoration: const InputDecoration(labelText: 'Vendor'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All vendors'),
            ),
            ...items.map(
              (vendor) => DropdownMenuItem<String?>(
                value: vendor.id,
                child: Text(vendor.title),
              ),
            ),
          ],
          onChanged: (value) => setState(() {
            vendorId = value;
            page = 1;
          }),
        ),
      ),
      const SizedBox(height: AppSpace.md),
      DropdownButtonFormField<bool?>(
        initialValue: assigned,
        decoration: const InputDecoration(labelText: 'Assignment'),
        items: const [
          DropdownMenuItem<bool?>(
            value: null,
            child: Text('Assigned and unassigned'),
          ),
          DropdownMenuItem<bool?>(value: true, child: Text('Assigned only')),
          DropdownMenuItem<bool?>(
            value: false,
            child: Text('Unassigned only'),
          ),
        ],
        onChanged: (value) => setState(() {
          assigned = value;
          page = 1;
        }),
      ),
      const SizedBox(height: AppSpace.md),
      Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          SecondaryButton(
            label: from == null ? 'From date' : 'From $from',
            icon: Icons.calendar_today_outlined,
            expand: false,
            onPressed: () => _chooseDate(
              (value) => setState(() {
                from = value;
                page = 1;
              }),
            ),
          ),
          SecondaryButton(
            label: to == null ? 'To date' : 'To $to',
            icon: Icons.event_outlined,
            expand: false,
            onPressed: () => _chooseDate(
              (value) => setState(() {
                to = value;
                page = 1;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.lg),
    ];
    // Each entry builds one order card, the empty message, or the pager.
    final body = orders.when<List<Widget Function()>>(
      loading: () => [
        () => const LoadingState(message: 'Loading the dispatch queue...'),
      ],
      error: (error, _) => [
        () => ErrorState(
              error: error,
              message: friendlyError(error),
              onRetry: () => ref.invalidate(dispatcherOrdersProvider(filter)),
            ),
      ],
      data: (pageData) {
        final rows = (pageData['rows'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return [
            () => const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No dispatch orders.',
                ),
          ];
        }
        final now = DateTime.now();
        final queue = [
          for (final raw in rows)
            (raw: raw, order: DispatcherOrder.fromJson(raw)),
        ]..sort((a, b) => compareByPriority(a.order, b.order, now));
        final currentPage = (pageData['page'] as num?)?.toInt() ?? page;
        final total = (pageData['total'] as num?)?.toInt() ?? rows.length;
        final pageSize = (pageData['pageSize'] as num?)?.toInt() ?? 25;
        return [
          for (final entry in queue)
            () => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: DispatchOrderCard(raw: entry.raw),
                ),
          if (total > pageSize)
            () => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $currentPage of ${(total / pageSize).ceil()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: currentPage > 1
                              ? () => setState(() => page = currentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: currentPage * pageSize < total
                              ? () => setState(() => page = currentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
        ];
      },
    );
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dispatcherOrdersProvider(filter)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xxxl,
        ),
        itemCount: header.length + body.length,
        itemBuilder: (_, index) {
          if (index < header.length) return header[index];
          return body[index - header.length]();
        },
      ),
    );
  }

  Future<void> _chooseDate(ValueChanged<String> onSelected) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    onSelected(
      '${selected.year.toString().padLeft(4, '0')}-'
      '${selected.month.toString().padLeft(2, '0')}-'
      '${selected.day.toString().padLeft(2, '0')}',
    );
  }
}
