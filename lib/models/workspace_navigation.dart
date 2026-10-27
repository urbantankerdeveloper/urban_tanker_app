import 'session.dart';

class WorkspaceNavigationDestination {
  const WorkspaceNavigationDestination({
    required this.label,
    required this.index,
  });

  final String label;
  final int index;
}

class WorkspaceNavigationGroup {
  const WorkspaceNavigationGroup({
    required this.title,
    required this.destinations,
  });

  final String title;
  final List<WorkspaceNavigationDestination> destinations;
}

List<WorkspaceNavigationGroup> workspaceNavigationForRole(
  WorkspaceRole role,
) {
  WorkspaceNavigationDestination destination(String label, int index) =>
      WorkspaceNavigationDestination(label: label, index: index);

  return switch (role) {
    WorkspaceRole.admin => [
        WorkspaceNavigationGroup(
          title: 'Bookings & dispatch',
          destinations: [destination('Orders', 1)],
        ),
        WorkspaceNavigationGroup(
          title: 'People & fleet',
          destinations: [destination('Vendors, customers & fleet', 1)],
        ),
        WorkspaceNavigationGroup(
          title: 'Finance & promos',
          destinations: [destination('Coupons, payouts & partners', 1)],
        ),
        WorkspaceNavigationGroup(
          title: 'Reports & setup',
          destinations: [
            destination('Services, notifications & audit', 1),
            destination('Reports', 2),
            destination('System health', 0),
          ],
        ),
      ],
    WorkspaceRole.vendor => [
        WorkspaceNavigationGroup(
          title: 'Orders & support',
          destinations: [destination('Orders', 0)],
        ),
        WorkspaceNavigationGroup(
          title: 'Services & team',
          destinations: [destination('Services and fleet', 1)],
        ),
        WorkspaceNavigationGroup(
          title: 'Earnings',
          destinations: [destination('Payouts and earnings', 2)],
        ),
      ],
    WorkspaceRole.dispatcher => [
        WorkspaceNavigationGroup(
          title: 'Dispatch operations',
          destinations: [
            destination('Dispatch queue', 0),
            destination('Live operations', 1),
          ],
        ),
        WorkspaceNavigationGroup(
          title: 'Reports & alerts',
          destinations: [destination('Alerts', 2)],
        ),
      ],
    WorkspaceRole.customer => const [],
  };
}
