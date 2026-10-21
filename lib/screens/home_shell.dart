import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../models/service.dart';
import '../models/session.dart';
import '../models/account.dart';
import '../models/notification.dart';
import 'notification_inbox.dart';
import 'bookings_screen.dart';
import 'customer_account_screen.dart';
import 'vendor_workspace.dart';
import 'admin_workspace.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  List<TankerService> _services = const [];
  bool _loadingServices = false;
  String? _serviceError;
  late Future<List<NotificationItem>>? _notifications;

  WorkspaceRole get role => widget.controller.user!.role;

  @override
  void initState() {
    super.initState();
    _notifications = role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.admin
        ? widget.controller.api.notifications(role.name)
        : null;
    if (role == WorkspaceRole.customer) _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _serviceError = null;
    });
    try {
      _services = await widget.controller.api.services();
    } catch (error) {
      _serviceError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _createBooking() async {
    if (_services.isEmpty) return;
    List<AccountRecord> addresses = const [];
    try {
      addresses = await widget.controller.api.addresses();
    } catch (_) {
      // Saved addresses are optional; manual entry remains available.
    }
    final locationController = TextEditingController();
    final dateController = TextEditingController();
    final capacityController = TextEditingController(text: '5000');
    final couponController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedService = _services.first.id;
    var selectedAddress = addresses.isEmpty ? null : addresses.first.detail;
    Map<String, dynamic>? validatedCoupon;
    String? couponMessage;
    var validatingCoupon = false;
    if (selectedAddress != null) locationController.text = selectedAddress;
    if (!mounted) {
      locationController.dispose();
      dateController.dispose();
      capacityController.dispose();
      couponController.dispose();
      return;
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Book a delivery',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedService,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: _services
                      .map((service) => DropdownMenuItem(
                            value: service.id,
                            child: Text(service.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selectedService = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (addresses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedAddress,
                    decoration:
                        const InputDecoration(labelText: 'Saved address'),
                    items: addresses
                        .map((address) => DropdownMenuItem(
                              value: address.detail,
                              child: Text(address.title),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        selectedAddress = value;
                        locationController.text = value ?? '';
                      });
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery location',
                    helperText: 'Choose a saved address or enter one manually.',
                  ),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Enter a delivery location.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(
                      labelText: 'Delivery date (YYYY-MM-DD)'),
                  validator: (value) =>
                      value == null || value.trim().length < 10
                          ? 'Enter a delivery date.'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capacityController,
                  decoration:
                      const InputDecoration(labelText: 'Capacity (litres)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Coupon code (optional)',
                    suffixIcon: TextButton(
                      onPressed: validatingCoupon
                          ? null
                          : () async {
                              final code = couponController.text.trim();
                              if (code.isEmpty) {
                                setSheetState(() {
                                  validatedCoupon = null;
                                  couponMessage = 'Enter a coupon code first.';
                                });
                                return;
                              }
                              setSheetState(() {
                                validatingCoupon = true;
                                couponMessage = null;
                              });
                              try {
                                final coupon =
                                    await widget.controller.api.validateCoupon(
                                  code: code,
                                  serviceCode: selectedService,
                                  amount: 0,
                                );
                                setSheetState(() {
                                  validatedCoupon = coupon;
                                  couponMessage =
                                      '${coupon['title'] ?? coupon['code'] ?? code} is valid.';
                                });
                              } catch (error) {
                                setSheetState(() {
                                  validatedCoupon = null;
                                  couponMessage = error.toString();
                                });
                              } finally {
                                if (context.mounted) {
                                  setSheetState(() => validatingCoupon = false);
                                }
                              }
                            },
                      child: validatingCoupon
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ),
                ),
                if (couponMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      couponMessage!,
                      style: TextStyle(
                        color: validatedCoupon == null
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final booking = await widget.controller.api.createBooking(
                        serviceId: selectedService,
                        capacity: capacityController.text,
                        location: locationController.text.trim(),
                        deliveryDate: dateController.text.trim(),
                        couponCode: validatedCoupon == null
                            ? null
                            : couponController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context, booking);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Submit booking'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    locationController.dispose();
    dateController.dispose();
    capacityController.dispose();
    couponController.dispose();
    if (result != null && mounted) {
      final quote = result['quote'];
      await _showBookingConfirmation(
        result,
        quote is Map<String, dynamic> ? quote : null,
      );
    }
  }

  Future<void> _showBookingConfirmation(
    Map<String, dynamic> booking,
    Map<String, dynamic>? quote,
  ) async {
    String? money(Object? value) {
      if (value is! num) return null;
      return '₹${(value / 100).toStringAsFixed(2)}';
    }

    final lines = [
      if (booking['reference'] != null) 'Reference: ${booking['reference']}',
      if (quote?['subtotalPaise'] != null)
        'Subtotal: ${money(quote!['subtotalPaise'])}',
      if (quote?['gstPaise'] != null) 'GST: ${money(quote!['gstPaise'])}',
      if (quote?['discountPaise'] != null)
        'Discount: ${money(quote!['discountPaise'])}',
      if (quote?['totalPaise'] != null) 'Total: ${money(quote!['totalPaise'])}',
      'Payment: Cash on delivery',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking submitted'),
        content: Text(lines.join('\n')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final tabs = _tabsForRole(role);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForRole(role)),
        actions: [
          FutureBuilder<List<NotificationItem>>(
            future: _notifications,
            builder: (context, snapshot) {
              final unread = snapshot.data
                      ?.where((notification) => !notification.read)
                      .length ??
                  0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationInbox(
                        controller: widget.controller,
                        role: role.name,
                        onNotificationSelected: (item) {
                          final target = item.bookingId != null
                              ? role == WorkspaceRole.vendor
                                  ? 'Operations'
                                  : 'Bookings'
                              : item.invoiceId != null
                                  ? role == WorkspaceRole.vendor
                                      ? 'Earnings'
                                      : 'Account > Invoices'
                                  : 'Account > Support requests';
                          setState(() {
                            _index = role == WorkspaceRole.vendor
                                ? (item.bookingId != null ? 0 : 2)
                                : (item.bookingId != null ? 1 : 2);
                          });
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$target selected.'),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                  if (mounted &&
                      (role == WorkspaceRole.customer ||
                          role == WorkspaceRole.vendor ||
                          role == WorkspaceRole.admin)) {
                    setState(() {
                      _notifications =
                          widget.controller.api.notifications(role.name);
                    });
                  }
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () => _showThemePicker(context),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.controller.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: tabs.map((tab) => _pageFor(tab, user)).toList(),
      ),
      floatingActionButton: role == WorkspaceRole.customer && _index == 0
          ? FloatingActionButton.extended(
              onPressed:
                  _loadingServices || _services.isEmpty ? null : _createBooking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Book water'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }

  List<_Tab> _tabsForRole(WorkspaceRole role) {
    return switch (role) {
      WorkspaceRole.customer => const [
          _Tab('Overview', Icons.home_outlined),
          _Tab('Bookings', Icons.receipt_long_outlined),
          _Tab('Account', Icons.person_outline),
        ],
      WorkspaceRole.vendor => const [
          _Tab('Operations', Icons.dashboard_outlined),
          _Tab('Fleet', Icons.local_shipping_outlined),
          _Tab('Earnings', Icons.payments_outlined),
        ],
      WorkspaceRole.dispatcher => const [
          _Tab('Dispatch', Icons.alt_route_outlined),
          _Tab('Live', Icons.radar_outlined),
          _Tab('Alerts', Icons.warning_amber_outlined),
        ],
      WorkspaceRole.admin => const [
          _Tab('Pulse', Icons.dashboard_outlined),
          _Tab('Operations', Icons.monitor_outlined),
          _Tab('Reports', Icons.analytics_outlined),
        ],
    };
  }

  Widget _pageFor(_Tab tab, SessionUser user) {
    if (role == WorkspaceRole.customer && tab.label == 'Overview') {
      return _customerOverview(user);
    }
    if (role == WorkspaceRole.customer && tab.label == 'Bookings') {
      return const BookingsScreen();
    }
    if (role == WorkspaceRole.customer && tab.label == 'Account') {
      return const CustomerAccountScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Operations') {
      return const VendorOperationsScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Fleet') {
      return const VendorFleetScreen();
    }
    if (role == WorkspaceRole.vendor && tab.label == 'Earnings') {
      return const VendorEarningsScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Pulse') {
      return const AdminPulseScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Operations') {
      return const AdminOperationsScreen();
    }
    if (role == WorkspaceRole.admin && tab.label == 'Reports') {
      return const AdminReportsScreen();
    }
    return _workspacePage(tab, user);
  }

  Widget _customerOverview(SessionUser user) {
    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Good to see you, ${user.name.split(' ').first}.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Reliable water delivery, without the runaround.'),
          const SizedBox(height: 22),
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF17454D)
                : ink,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEXT DELIVERY',
                      style: TextStyle(color: mint, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('Book a tanker when you need it.',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _services.isEmpty ? null : _createBooking,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Start a booking'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Available services',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loadingServices)
            const Center(child: CircularProgressIndicator())
          else if (_serviceError != null)
            _ErrorCard(message: _serviceError!, onRetry: _loadServices)
          else if (_services.isEmpty)
            const _EmptyCard(message: 'No services are available right now.')
          else
            ..._services.map((service) => _ServiceCard(service: service)),
        ],
      ),
    );
  }

  Widget _workspacePage(_Tab tab, SessionUser user) {
    final copy = switch (role) {
      WorkspaceRole.vendor =>
        'Manage assigned work, fleet, drivers, and payouts.',
      WorkspaceRole.dispatcher =>
        'Coordinate active deliveries and resolve operational exceptions.',
      WorkspaceRole.admin =>
        'Review platform operations, records, finance, and system health.',
      WorkspaceRole.customer => 'Your account activity and saved details.',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(tab.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(copy),
        const SizedBox(height: 22),
        _MetricCard(label: 'Signed in as', value: user.role.name),
        const SizedBox(height: 12),
        _MetricCard(label: 'Realtime', value: 'Connected'),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Native workspace ready'),
            subtitle: Text(
              'This role can only access server-authorized ${user.role.name} operations.',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showThemePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: widget.controller.themeMode,
          onChanged: (value) {
            if (value != null) widget.controller.setThemeMode(value);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (mode) => RadioListTile<ThemeMode>(
                    title: Text(
                      mode.name[0].toUpperCase() + mode.name.substring(1),
                    ),
                    value: mode,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

String _titleForRole(WorkspaceRole role) => switch (role) {
      WorkspaceRole.customer => 'Urban Tanker',
      WorkspaceRole.vendor => 'Vendor workspace',
      WorkspaceRole.dispatcher => 'Dispatch workspace',
      WorkspaceRole.admin => 'Admin workspace',
    };

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final TankerService service;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: mint,
            child: Icon(Icons.water_drop_outlined, color: ink),
          ),
          title: Text(service.name),
          subtitle: Text(service.description.isEmpty
              ? service.category
              : service.description),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error),
          title: const Text('Could not load services'),
          subtitle: Text(message),
          trailing:
              IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ),
      );
}
