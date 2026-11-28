import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../models/account.dart';
import '../../models/vendor.dart';
import 'admin_access_requests_screen.dart';
import 'admin_review_screen.dart';

class AdminApprovalsHubScreen extends StatefulWidget {
  const AdminApprovalsHubScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AdminApprovalsHubScreen> createState() =>
      _AdminApprovalsHubScreenState();
}

class _AdminApprovalsHubScreenState extends State<AdminApprovalsHubScreen> {
  static const _tabs = ['Vendors', 'Drivers', 'Admins'];

  int _selectedTab = 0;
  late Future<List<AccountRecord>> _vendors;
  late Future<List<AdminFleetDriver>> _drivers;
  late Future<List<Map<String, dynamic>>> _admins;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = widget.controller.api;
    _vendors = api.adminVendors();
    _drivers = api.adminDrivers();
    _admins = api.adminUsers();
  }

  bool _needsReview(String status) => const {
    'pending',
    'submitted',
    'under_review',
    'needs_more_documents',
  }.contains(status.toLowerCase());

  Future<void> _openReview(AdminReviewKind kind, Map<String, dynamic> record) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminReviewScreen(
          kind: kind,
          record: record,
          onUpdated: () {
            if (mounted) setState(_reload);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous approval category',
                onPressed: _selectedTab > 0
                    ? () => setState(() => _selectedTab--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _tabs[_selectedTab],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next approval category',
                onPressed: _selectedTab < _tabs.length - 1
                    ? () => setState(() => _selectedTab++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
          child: SwipeNavigationArea(
            onSwipeLeft: _selectedTab < _tabs.length - 1
                ? () => setState(() => _selectedTab++)
                : null,
            onSwipeRight: _selectedTab > 0
                ? () => setState(() => _selectedTab--)
                : null,
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _vendorApplications(),
                _driverApplications(),
                _adminApplications(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _vendorApplications() => FutureBuilder<List<AccountRecord>>(
    future: _vendors,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          error: snapshot.error!,
          onRetry: () => setState(_reload),
        );
      }
      if (!snapshot.hasData) {
        return const ListLoadingState();
      }
      final pending = snapshot.data!.where((vendor) {
        final status =
            (vendor.data['verification'] ?? vendor.data['status'] ?? '')
                .toString();
        return _needsReview(status);
      }).toList();
      if (pending.isEmpty) {
        return const NewUiEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No pending vendor approvals',
          message: 'New vendor applications will appear here.',
        );
      }
      return ListView.separated(
        padding: AppPageInsets.standard,
        itemCount: pending.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (context, index) {
          final vendor = pending[index];
          return SurfaceCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              leading: const Icon(Icons.storefront_outlined),
              title: vendor.title,
              subtitle: vendor.detail,
              trailing: TextButton(
                onPressed: () =>
                    _openReview(AdminReviewKind.vendor, vendor.data),
                child: const Text('Review'),
              ),
              onTap: () => _openReview(AdminReviewKind.vendor, vendor.data),
            ),
          );
        },
      );
    },
  );

  Widget _driverApplications() => FutureBuilder<List<AdminFleetDriver>>(
    future: _drivers,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          error: snapshot.error!,
          onRetry: () => setState(_reload),
        );
      }
      if (!snapshot.hasData) {
        return const ListLoadingState();
      }
      final pending = snapshot.data!
          .where((driver) => _needsReview(driver.verification))
          .toList();
      if (pending.isEmpty) {
        return const NewUiEmptyState(
          icon: Icons.badge_outlined,
          title: 'No pending driver approvals',
          message: 'New driver applications will appear here.',
        );
      }
      return ListView.separated(
        padding: AppPageInsets.standard,
        itemCount: pending.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
        itemBuilder: (context, index) {
          final driver = pending[index];
          return SurfaceCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              leading: const Icon(Icons.badge_outlined),
              title: driver.name,
              subtitle: driver.mobile,
              trailing: TextButton(
                onPressed: () =>
                    _openReview(AdminReviewKind.driver, driver.data),
                child: const Text('Review'),
              ),
              onTap: () => _openReview(AdminReviewKind.driver, driver.data),
            ),
          );
        },
      );
    },
  );

  Widget _adminApplications() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _admins,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          error: snapshot.error!,
          onRetry: () => setState(_reload),
        );
      }
      if (!snapshot.hasData) {
        return const ListLoadingState();
      }
      final pending = snapshot.data!
          .where((admin) => admin['status'] == 'pending')
          .toList();
      return ListView(
        padding: AppPageInsets.standard,
        children: [
          if (pending.isEmpty)
            const NewUiEmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'No pending admin approvals',
              message: 'Admin access requests will appear here.',
            )
          else
            for (final admin in pending) ...[
              SurfaceCard(
                child: AppListRow(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: admin['name']?.toString() ?? 'Admin applicant',
                  subtitle: admin['email']?.toString(),
                  trailing: StatusChip(
                    label: 'Pending',
                    tone: context.colors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
            ],
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: 'Manage admin requests',
            icon: Icons.manage_accounts_outlined,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AdminUsersScreen(controller: widget.controller),
              ),
            ),
          ),
        ],
      );
    },
  );
}
