import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';

enum VendorSalesPeriod { day, week, month }

class VendorSalesBreakdown {
  const VendorSalesBreakdown({
    required this.service,
    required this.orders,
    required this.amountPaise,
  });

  final String service;
  final int orders;
  final int amountPaise;
}

class VendorSalesReport {
  const VendorSalesReport({
    required this.totalPaise,
    required this.previousTotalPaise,
    required this.orderCount,
    required this.dailyTotalsPaise,
    required this.breakdown,
  });

  final int totalPaise;
  final int previousTotalPaise;
  final int orderCount;
  final List<int> dailyTotalsPaise;
  final List<VendorSalesBreakdown> breakdown;
}

abstract interface class VendorSalesReportRepository {
  Future<VendorSalesReport> load(VendorSalesPeriod period);
}

class ApiVendorSalesReportRepository implements VendorSalesReportRepository {
  const ApiVendorSalesReportRepository(this.loadReport);

  final Future<Map<String, dynamic>> Function(String period) loadReport;

  @override
  Future<VendorSalesReport> load(VendorSalesPeriod period) async {
    final response = await loadReport(period.name);
    final dailyTotals = response['dailyTotalsPaise'];
    final breakdown = response['breakdown'];
    if (dailyTotals is! List || breakdown is! List) {
      throw const FormatException('The vendor sales report was invalid.');
    }

    return VendorSalesReport(
      totalPaise: _reportInt(response['totalPaise'], 'totalPaise'),
      previousTotalPaise: _reportInt(
        response['previousTotalPaise'],
        'previousTotalPaise',
      ),
      orderCount: _reportInt(response['orderCount'], 'orderCount'),
      dailyTotalsPaise: dailyTotals
          .map((value) => _reportInt(value, 'dailyTotalsPaise'))
          .toList(growable: false),
      breakdown: breakdown.map((value) {
        if (value is! Map) {
          throw const FormatException('The vendor sales breakdown was invalid.');
        }
        return VendorSalesBreakdown(
          service: value['service']?.toString() ?? '',
          orders: _reportInt(value['orders'], 'breakdown.orders'),
          amountPaise: _reportInt(value['amountPaise'], 'breakdown.amountPaise'),
        );
      }).toList(growable: false),
    );
  }

  static int _reportInt(Object? value, String field) {
    if (value is! num || !value.isFinite || value < 0 || value != value.toInt()) {
      throw FormatException('The vendor sales report field "$field" was invalid.');
    }
    return value.toInt();
  }
}

final vendorSalesReportRepositoryProvider =
    Provider<VendorSalesReportRepository>(
      (ref) => ApiVendorSalesReportRepository(
        ref.watch(apiProvider).vendorSalesReport,
      ),
    );

class VendorSalesReportCard extends ConsumerStatefulWidget {
  const VendorSalesReportCard({super.key});

  @override
  ConsumerState<VendorSalesReportCard> createState() =>
      _VendorSalesReportCardState();
}

class _VendorSalesReportCardState extends ConsumerState<VendorSalesReportCard> {
  VendorSalesPeriod _period = VendorSalesPeriod.day;
  bool _loading = false;
  Object? _error;
  VendorSalesReport? _report;

  static const _periods = VendorSalesPeriod.values;
  static const _labels = ['Day', 'Week', 'Month'];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await ref
          .read(vendorSalesReportRepositoryProvider)
          .load(_period);
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sales report', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          SegmentedTabs(
            labels: _labels,
            selectedIndex: _periods.indexOf(_period),
            onChanged: (index) => setState(() => _period = _periods[index]),
          ),
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: _loading ? 'Loading...' : 'View report',
            icon: Icons.insights_outlined,
            loading: _loading,
            onPressed: _loading ? null : _load,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            AppStateInline.error(
              error: _error!,
              message: 'Sales report could not be loaded: $_error',
              onRetry: _load,
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Sales',
                    value: '₹${(report.totalPaise / 100).toStringAsFixed(2)}',
                    icon: Icons.currency_rupee,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: StatCard(
                    label: 'Orders',
                    value: '${report.orderCount}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _comparisonText(report.totalPaise, report.previousTotalPaise),
              style: theme.textTheme.bodySmall,
            ),
            if (report.dailyTotalsPaise.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                height: AppSize.reportChartHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: _VendorSalesBarPainter(
                    values: [
                      for (final total in report.dailyTotalsPaise)
                        total.toDouble(),
                    ],
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Text('BREAKDOWN', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
            if (report.breakdown.isEmpty)
              const EmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No sales in this period.',
              )
            else
              for (final item in report.breakdown)
                AppListRow(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: item.service,
                  subtitle: '${item.orders} orders',
                  trailing: Text(
                    '₹${(item.amountPaise / 100).toStringAsFixed(2)}',
                  ),
                ),
          ],
        ],
      ),
    );
  }

  static String _comparisonText(int current, int previous) {
    if (previous <= 0) {
      return current <= 0
          ? 'No sales in either period.'
          : 'No sales were recorded in the previous period.';
    }
    final change = ((current - previous) / previous) * 100;
    final direction = change > 0
        ? 'Up'
        : change < 0
        ? 'Down'
        : 'Unchanged';
    return '$direction ${change.abs().toStringAsFixed(1)}% vs previous period.';
  }
}

class _VendorSalesBarPainter extends CustomPainter {
  const _VendorSalesBarPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    if (max <= 0 || values.isEmpty) return;
    final slot = size.width / values.length;
    final width = slot * 0.6;
    final paint = Paint()..color = color;
    for (var index = 0; index < values.length; index++) {
      final height = size.height * (values[index] / max);
      final left = index * slot + (slot - width) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, width, height),
          const Radius.circular(AppSpace.xs),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VendorSalesBarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
