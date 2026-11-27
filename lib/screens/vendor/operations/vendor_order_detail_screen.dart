import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import 'order_actions_sheet.dart';

class VendorOrderDetailScreen extends StatelessWidget {
  const VendorOrderDetailScreen({required this.order, super.key});

  final VendorOrder order;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Order details',
    body: OrderActionsSheet(order: order),
  );
}
