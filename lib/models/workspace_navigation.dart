import 'session.dart';

/// Sections of the admin operations screen, one per drawer group.
enum OperationsSection { orders, people, finance, setup }

/// A request to open [section] on the operations screen. A new instance is
/// created for every request, so repeating the same request still notifies.
class OperationsFocus {
  const OperationsFocus(this.section);

  final OperationsSection section;
}

class WorkspaceNavigationDestination {
  const WorkspaceNavigationDestination({
    required this.label,
    required this.index,
    this.operationsSection,
  });

  final String label;
  final int index;

  /// Set for admin items that open a section of the operations tab.
  final OperationsSection? operationsSection;
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
  WorkspaceNavigationDestination destination(
    String label,
    int index, [
    OperationsSection? section,
  ]) =>
      WorkspaceNavigationDestination(
        label: label,
        index: index,
        operationsSection: section,
      );

  return switch (role) {
    WorkspaceRole.admin => [
        WorkspaceNavigationGroup(
          title: 'Bookings & dispatch',
          destinations: [
            destination('Orders', 1, OperationsSection.orders),
          ],
        ),
        WorkspaceNavigationGroup(
          title: 'People & fleet',
          destinations: [
            destination(
              'Vendors, customers & fleet',
              1,
              OperationsSection.people,
            ),
          ],
        ),
        WorkspaceNavigationGroup(
          title: 'Finance & promos',
          destinations: [
            destination(
              'Coupons, payouts & partners',
              1,
              OperationsSection.finance,
            ),
          ],
        ),
        WorkspaceNavigationGroup(
          title: 'Reports & setup',
          destinations: [
            destination(
              'Services, notifications & audit',
              1,
              OperationsSection.setup,
            ),
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
