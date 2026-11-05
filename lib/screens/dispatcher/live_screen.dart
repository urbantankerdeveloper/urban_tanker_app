import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/dispatcher.dart';
import '../../services/friendly_error.dart';
import '../common/brand_map.dart';
import '../common/map_tiles.dart';

/// Chennai, where deliveries are made. The map starts here when no active
/// order has a location yet.
const _chennai = LatLng(13.0827, 80.2707);

/// Degrees per grid cell for clustering. About a kilometre.
const _clusterCell = 0.01;

/// Filters for the live list. Each one is a set of order statuses.
const _liveFilters = <(String, Set<String>?)>[
  ('All active', null),
  ('Unassigned', {'pending_vendor'}),
  ('Assigned', {'vendor_assigned', 'accepted'}),
  ('En route', {'en_route'}),
  ('Arrived', {'arrived'}),
];

/// Live operations: a map of active deliveries with a draggable list. Orders
/// close to each other share one pin with a count.
class DispatcherLiveScreen extends ConsumerStatefulWidget {
  const DispatcherLiveScreen({super.key});

  @override
  ConsumerState<DispatcherLiveScreen> createState() =>
      _DispatcherLiveScreenState();
}

class _DispatcherLiveScreenState extends ConsumerState<DispatcherLiveScreen> {
  final _map = MapController();
  int _filterIndex = 0;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(
      dispatcherOrdersProvider(const DispatcherOrderFilter()),
    );
    return orders.when(
      loading: () => const LoadingState(message: 'Loading live operations...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(dispatcherOrdersProvider),
      ),
      data: (page) {
        final rows = (page['rows'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
        final active = [
          for (final raw in rows)
            if (!['delivered', 'cancelled']
                .contains((raw['status'] ?? '').toString()))
              DispatcherOrder.fromJson(raw),
        ];
        final statuses = _liveFilters[_filterIndex].$2;
        final shown = [
          for (final order in active)
            if (statuses == null || statuses.contains(order.status)) order,
        ];
        final located = [
          for (final order in shown)
            if (order.latitude != null && order.longitude != null) order,
        ];
        final clusters = _cluster(located);
        final map = FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: located.isEmpty
                ? _chennai
                : LatLng(located.first.latitude!, located.first.longitude!),
            initialZoom: 12,
          ),
          children: [
            const MapTileLayer(),
            MarkerLayer(
              markers: [
                for (final cluster in clusters)
                  Marker(
                    point: cluster.center,
                    width: 48,
                    height: 48,
                    child: _OrderPin(orders: cluster.orders),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            map,
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: AppPageInsets.card,
                  child: _Header(
                    count: shown.length,
                    selected: _filterIndex,
                    onSelected: (index) => setState(() => _filterIndex = index),
                  ),
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.34,
              minChildSize: 0.18,
              maxChildSize: 0.88,
              snap: true,
              builder: (context, controller) => _ListSheet(
                controller: controller,
                orders: shown,
                onFocus: (order) => _map.move(
                  LatLng(order.latitude!, order.longitude!),
                  15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Groups orders into grid cells and puts each group at its average point.
  static List<_Cluster> _cluster(List<DispatcherOrder> orders) {
    final cells = <String, List<DispatcherOrder>>{};
    for (final order in orders) {
      final key = '${(order.latitude! / _clusterCell).round()}:'
          '${(order.longitude! / _clusterCell).round()}';
      cells.putIfAbsent(key, () => []).add(order);
    }
    return [
      for (final group in cells.values)
        _Cluster(
          orders: group,
          center: LatLng(
            group.map((o) => o.latitude!).reduce((a, b) => a + b) /
                group.length,
            group.map((o) => o.longitude!).reduce((a, b) => a + b) /
                group.length,
          ),
        ),
    ];
  }
}

class _Cluster {
  const _Cluster({required this.orders, required this.center});

  final List<DispatcherOrder> orders;
  final LatLng center;
}

/// Floating glass header: the title, the number of orders, and the filters.
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final int count;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      radius: AppRadius.cardBorder,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live operations • $count active',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (var i = 0; i < _liveFilters.length; i++)
                ChoiceChip(
                  label: Text(_liveFilters[i].$1),
                  selected: selected == i,
                  onSelected: (_) => onSelected(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single order gets its status-coloured pin. A group gets a count.
class _OrderPin extends StatelessWidget {
  const _OrderPin({required this.orders});

  final List<DispatcherOrder> orders;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (orders.length == 1) {
      final order = orders.first;
      return Semantics(
        label: '${order.reference}, ${StatusChip.statusLabel(order.status)}',
        child: BrandPin(
          color: colors.statusTone(order.status).fg,
          foreground: colors.onHero,
          icon: Icons.local_shipping,
        ),
      );
    }
    return Semantics(
      label: '${orders.length} orders close together',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryDeep,
          shape: BoxShape.circle,
          border: Border.all(color: colors.onHero, width: 2),
        ),
        child: Text(
          '${orders.length}',
          style: TextStyle(color: colors.onHero, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Draggable list of the orders on the map.
class _ListSheet extends StatelessWidget {
  const _ListSheet({
    required this.controller,
    required this.orders,
    required this.onFocus,
  });

  final ScrollController controller;
  final List<DispatcherOrder> orders;
  final ValueChanged<DispatcherOrder> onFocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.sheetBorder,
        boxShadow: colors.shadowLifted,
      ),
      child: ListView(
        controller: controller,
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('ACTIVE DELIVERIES', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.md),
          if (orders.isEmpty)
            const AppListRow(title: 'No active live operations.')
          else
            for (final order in orders)
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: AppListRow(
                  leading: Icon(
                    order.latitude != null && order.longitude != null
                        ? Icons.my_location
                        : Icons.location_off_outlined,
                  ),
                  title: order.reference,
                  subtitle: order.address.isEmpty
                      ? 'Address unavailable'
                      : order.address,
                  trailing: BookingStatusChip(status: order.status),
                  onTap: order.latitude != null && order.longitude != null
                      ? () => onFocus(order)
                      : null,
                ),
              ),
        ],
      ),
    );
  }
}
