class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.activeOrdersByStatus,
    required this.todayRevenuePaise,
    required this.pendingPartnerApplications,
    required this.onlineVendors,
    required this.activeDrivers,
    required this.openOrderAlerts,
    required this.failedPayments,
    required this.stuckOrders,
    required this.generatedAt,
  });

  final Map<String, int> activeOrdersByStatus;
  final int todayRevenuePaise;
  final int pendingPartnerApplications;
  final int onlineVendors;
  final int activeDrivers;
  final int openOrderAlerts;
  final int failedPayments;
  final int stuckOrders;
  final DateTime generatedAt;

  int get activeOrderCount =>
      activeOrdersByStatus.values.fold(0, (total, count) => total + count);

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    final statuses = json['activeOrdersByStatus'];
    if (statuses is! Map) {
      throw const FormatException(
        'The admin dashboard order summary was invalid.',
      );
    }

    final activeOrdersByStatus = <String, int>{};
    for (final entry in statuses.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw const FormatException(
          'The admin dashboard order summary was invalid.',
        );
      }
      activeOrdersByStatus[entry.key as String] = (entry.value as num).toInt();
    }

    int number(String key) {
      final value = json[key];
      if (value is! num) {
        throw FormatException('The admin dashboard field "$key" was invalid.');
      }
      return value.toInt();
    }

    final generatedAt = DateTime.tryParse(
      (json['generatedAt'] ?? '').toString(),
    );
    if (generatedAt == null) {
      throw const FormatException(
        'The admin dashboard generation time was invalid.',
      );
    }

    return AdminDashboardSummary(
      activeOrdersByStatus: activeOrdersByStatus,
      todayRevenuePaise: number('todayRevenuePaise'),
      pendingPartnerApplications: number('pendingPartnerApplications'),
      onlineVendors: number('onlineVendors'),
      activeDrivers: number('activeDrivers'),
      openOrderAlerts: number('openOrderAlerts'),
      failedPayments: number('failedPayments'),
      stuckOrders: number('stuckOrders'),
      generatedAt: generatedAt,
    );
  }
}
