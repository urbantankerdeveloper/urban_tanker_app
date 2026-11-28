import 'package:flutter/material.dart';

import '../../../app/auth_feature_flags.dart';
import '../../../models/session.dart';

/// Every page the home shell can show. Tabs refer to pages by this enum, so
/// routing and notification targets do not depend on tab labels.
enum ShellPage {
  overview,
  bookings,
  account,
  vendorOperations,
  vendorFleet,
  vendorEarnings,
  dispatchHome,
  dispatchDispatch,
  dispatchLive,
  dispatchAlerts,
  adminDashboard,
  adminPulse,
  adminOperations,
  adminApprovals,
  adminReports,
  menu,
}

class ShellTab {
  const ShellTab(this.page, this.label, this.icon, [IconData? selectedIcon])
    : selectedIcon = selectedIcon ?? icon;

  final ShellPage page;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom tabs for [role]. Vendor, dispatcher and admin end with a Menu tab.
List<ShellTab> tabsForRole(
  WorkspaceRole role, {
  bool newUiEnabled = AuthFeatureFlags.newUiEnabled,
}) {
  const menu = ShellTab(
    ShellPage.menu,
    'Menu',
    Icons.menu_outlined,
    Icons.menu,
  );
  return switch (role) {
    WorkspaceRole.customer => const [
      ShellTab(ShellPage.overview, 'Home', Icons.home_outlined, Icons.home),
      ShellTab(
        ShellPage.bookings,
        'Bookings',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
      ),
      ShellTab(
        ShellPage.account,
        'Account',
        Icons.person_outline,
        Icons.person,
      ),
    ],
    WorkspaceRole.vendor => const [
      ShellTab(
        ShellPage.vendorOperations,
        'Operations',
        Icons.dashboard_outlined,
      ),
      ShellTab(ShellPage.vendorFleet, 'Fleet', Icons.local_shipping_outlined),
      ShellTab(ShellPage.vendorEarnings, 'Earnings', Icons.payments_outlined),
      menu,
    ],
    WorkspaceRole.dispatcher =>
      newUiEnabled
          ? const [
              ShellTab(
                ShellPage.dispatchHome,
                'Home',
                Icons.home_outlined,
                Icons.home,
              ),
              ShellTab(
                ShellPage.dispatchDispatch,
                'Orders',
                Icons.alt_route_outlined,
              ),
              ShellTab(ShellPage.dispatchLive, 'Live', Icons.radar_outlined),
              ShellTab(
                ShellPage.dispatchAlerts,
                'Alerts',
                Icons.warning_amber_outlined,
              ),
              menu,
            ]
          : const [
              ShellTab(
                ShellPage.dispatchDispatch,
                'Dispatch',
                Icons.alt_route_outlined,
              ),
              ShellTab(ShellPage.dispatchLive, 'Live', Icons.radar_outlined),
              ShellTab(
                ShellPage.dispatchAlerts,
                'Alerts',
                Icons.warning_amber_outlined,
              ),
              menu,
            ],
    WorkspaceRole.admin => [
      if (newUiEnabled)
        const ShellTab(
          ShellPage.adminDashboard,
          'Dashboard',
          Icons.dashboard_outlined,
        )
      else
        const ShellTab(ShellPage.adminPulse, 'Pulse', Icons.dashboard_outlined),
      ShellTab(ShellPage.adminOperations, 'Operations', Icons.monitor_outlined),
      if (newUiEnabled)
        const ShellTab(
          ShellPage.adminApprovals,
          'Approvals',
          Icons.fact_check_outlined,
        ),
      ShellTab(ShellPage.adminReports, 'Reports', Icons.analytics_outlined),
      menu,
    ],
  };
}

String titleForRole(WorkspaceRole role) => switch (role) {
  WorkspaceRole.customer => 'Urban Tanker',
  WorkspaceRole.vendor => 'Vendor workspace',
  WorkspaceRole.dispatcher => 'Dispatch workspace',
  WorkspaceRole.admin => 'Admin workspace',
};
