import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../core/design_system/gallery/design_system_gallery.dart';
import '../../models/booking.dart';
import '../../models/notification.dart';
import '../../models/service.dart';
import '../../models/session.dart';
import '../../models/workspace_navigation.dart';
import '../../services/friendly_error.dart';
import '../../services/realtime_service.dart';
import '../admin/admin_operations_screen.dart';
import '../admin/admin_pulse_screen.dart';
import '../admin/admin_reports_screen.dart';
import '../bookings_screen.dart';
import '../customer_account_screen.dart';
import '../dispatcher_workspace.dart';
import '../notification_inbox.dart';
import '../vendor/vendor_earnings_screen.dart';
import '../vendor/vendor_fleet_screen.dart';
import '../vendor/vendor_operations_screen.dart';
import 'booking/booking_form_sheet.dart';
import 'customer/customer_overview.dart';
import 'shell/menu_screen.dart';
import 'shell/notification_routing.dart';
import 'shell/role_tabs.dart';
import 'shell/unlock_offer.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  List<TankerService> _services = const [];
  bool _loadingServices = false;
  bool _bookingFormOpening = false;
  String? _serviceError;
  late Future<List<NotificationItem>>? _notifications;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  final _operationsFocus = ValueNotifier<OperationsFocus?>(null);

  WorkspaceRole get role =>
      widget.controller.user?.role ?? WorkspaceRole.customer;

  @override
  void initState() {
    super.initState();
    _notifications = role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.admin
        ? widget.controller.api.notifications(role.name)
        : null;
    if (role == WorkspaceRole.customer) _loadServices();
    _realtimeSubscription = widget.controller.realtime?.events.listen((event) {
      if (!mounted) return;
      switch (event.name) {
        case 'booking.created':
        case 'booking.updated':
        case 'booking.rejected':
        case 'booking.vendor_accepted':
        case 'booking.delivered':
          ref.invalidate(bookingsProvider);
        case 'notification.created':
          ref.invalidate(bookingsProvider);
          _reloadNotifications();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) offerUnlockSetup(context, widget.controller);
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _operationsFocus.dispose();
    super.dispose();
  }

  void _reloadNotifications() {
    if (!mounted ||
        !(role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.admin)) {
      return;
    }
    setState(() {
      _notifications = widget.controller.api.notifications(role.name);
    });
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _serviceError = null;
    });
    try {
      _services = await widget.controller.api.services();
    } catch (error) {
      _serviceError = friendlyError(error);
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _createBooking({Booking? previousBooking}) async {
    if (_bookingFormOpening || _services.isEmpty) return;
    setState(() => _bookingFormOpening = true);
    try {
      await openBookingForm(
        context,
        controller: widget.controller,
        serviceCatalog: _services,
        previousBooking: previousBooking,
      );
    } finally {
      if (mounted) setState(() => _bookingFormOpening = false);
    }
  }

  /// Menu items switch to their tab; admin items also ask the operations
  /// screen to open their section.
  /// Switches to [page] if the current role has a tab for it.
  void _selectPage(ShellPage page) {
    final index = tabsForRole(role).indexWhere((tab) => tab.page == page);
    if (index >= 0) setState(() => _index = index);
  }

  void _openDestination(WorkspaceNavigationDestination destination) {
    final section = destination.operationsSection;
    setState(() => _index = destination.index);
    if (section != null) _operationsFocus.value = OperationsFocus(section);
  }

  void _selectNotification(NotificationItem item) {
    if (!hasNotificationTarget(item)) {
      Navigator.of(context).pop();
      showAppSnack(context, 'This notification has no valid destination.');
      return;
    }
    setState(() => _index = notificationTabIndex(role, item));
    Navigator.of(context).pop();
    unawaited(openNotificationTarget(context, widget.controller, role, item));
  }

  Future<void> _openNotificationInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationInbox(
          controller: widget.controller,
          role: role.name,
          onNotificationSelected: _selectNotification,
        ),
      ),
    );
    _reloadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    // The app switches to the auth screen on sign-out; render nothing until then.
    if (user == null) return const SizedBox.shrink();
    final isCustomer = role == WorkspaceRole.customer;
    final tabs = tabsForRole(role);
    return Scaffold(
      appBar: AppBar(
        title: Text(titleForRole(role)),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Design system',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignSystemGallery(),
                ),
              ),
              icon: const Icon(Icons.palette_outlined),
            ),
          _notificationBell(),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final tab in tabs) _pageFor(tab.page, user)],
      ),
      floatingActionButton: isCustomer && _index == 0
          ? FloatingActionButton.extended(
              onPressed:
                  _loadingServices || _services.isEmpty || _bookingFormOpening
                      ? null
                      : _createBooking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Book service'),
            )
          : null,
      bottomNavigationBar: AppBottomNav(
        items: [
          for (final tab in tabs)
            AppNavItem(
              label: tab.label,
              icon: tab.icon,
              selectedIcon: tab.selectedIcon,
            ),
        ],
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }

  Widget _notificationBell() => FutureBuilder<List<NotificationItem>>(
        future: _notifications,
        builder: (context, snapshot) {
          final unread = snapshot.data?.where((item) => !item.read).length ?? 0;
          return IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotificationInbox,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_outlined),
            ),
          );
        },
      );

  Widget _pageFor(ShellPage page, SessionUser user) => switch (page) {
        ShellPage.overview => CustomerOverview(
            user: user,
            services: _services,
            loading: _loadingServices,
            error: _serviceError,
            onRetry: _loadServices,
            onBook: _services.isEmpty ? null : _createBooking,
            onBookAgain: (booking) => _createBooking(previousBooking: booking),
            onOpenBookings: () => _selectPage(ShellPage.bookings),
            onOpenAccount: () => _selectPage(ShellPage.account),
          ),
        ShellPage.bookings => BookingsScreen(
            onBookAgain: (booking) => _createBooking(previousBooking: booking),
          ),
        ShellPage.account => const CustomerAccountScreen(),
        ShellPage.vendorOperations => const VendorOperationsScreen(),
        ShellPage.vendorFleet => const VendorFleetScreen(),
        ShellPage.vendorEarnings => const VendorEarningsScreen(),
        ShellPage.dispatchDispatch => const DispatcherDispatchScreen(),
        ShellPage.dispatchLive => const DispatcherLiveScreen(),
        ShellPage.dispatchAlerts => const DispatcherAlertsScreen(),
        ShellPage.adminPulse => const AdminPulseScreen(),
        ShellPage.adminOperations => AdminOperationsScreen(
            focus: _operationsFocus,
          ),
        ShellPage.adminReports => const AdminReportsScreen(),
        ShellPage.menu => MenuScreen(
            controller: widget.controller,
            role: role,
            notifications: _notifications,
            onDestination: _openDestination,
            onNotifications: _openNotificationInbox,
          ),
      };
}
