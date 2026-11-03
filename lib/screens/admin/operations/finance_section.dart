import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import 'admin_common.dart';

const _financeTabs = ['Coupons', 'Payouts', 'Partners'];

/// Admin finance and promos: coupons (with create), payouts, and partner
/// applications. Each list searches and opens its record in a sheet.
class AdminFinanceSection extends ConsumerStatefulWidget {
  const AdminFinanceSection({super.key});

  @override
  ConsumerState<AdminFinanceSection> createState() =>
      _AdminFinanceSectionState();
}

class _AdminFinanceSectionState extends ConsumerState<AdminFinanceSection> {
  final _search = TextEditingController();
  int _tab = 0;
  String _query = '';
  late Future<List<AccountRecord>> _coupons;
  late Future<List<AccountRecord>> _payouts;
  late Future<List<AccountRecord>> _partners;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final api = ref.read(appControllerProvider).api;
    _coupons = api.adminCoupons();
    _payouts = api.adminPayouts();
    _partners = api.adminPartnerApplications();
  }

  @override
  Widget build(BuildContext context) {
    final future = switch (_tab) {
      0 => _coupons,
      1 => _payouts,
      _ => _partners,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpace.gutter),
      children: [
        SegmentedTabs(
          labels: _financeTabs,
          selectedIndex: _tab,
          onChanged: (index) => setState(() {
            _tab = index;
            _query = '';
            _search.clear();
          }),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: AdminSearchField(
                controller: _search,
                label: 'Search ${_financeTabs[_tab].toLowerCase()}',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_tab == 0) ...[
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: 'Create coupon',
            icon: Icons.add,
            expand: false,
            onPressed: _createCoupon,
          ),
        ],
        const SizedBox(height: AppSpace.md),
        FutureBuilder<List<AccountRecord>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingState(message: 'Loading...');
            }
            if (snapshot.hasError) {
              return ErrorState(
                error: snapshot.error!,
                onRetry: () => setState(_reload),
              );
            }
            final records = [
              for (final record in snapshot.data ?? const <AccountRecord>[])
                if (_matches(record)) record,
            ];
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No records found.',
              );
            }
            return Column(
              children: [
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: AdminRecordRow(record: record),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _matches(AccountRecord record) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return record.title.toLowerCase().contains(query) ||
        record.detail.toLowerCase().contains(query);
  }

  Future<void> _createCoupon() async {
    final code = TextEditingController();
    final label = TextEditingController();
    final discount = TextEditingController();
    final expires = TextEditingController();
    await adminForm(
      context,
      title: 'Create coupon',
      fields: [
        ('Code', code),
        ('Label', label),
        ('Discount (10% or 100)', discount),
        ('Expiry (YYYY-MM-DD)', expires),
      ],
      submit: () {
        final expiry = DateTime.tryParse(expires.text.trim());
        if (expiry == null || expiry.isBefore(DateTime.now())) {
          throw const FormatException('Enter a valid future expiry date.');
        }
        return ref.read(appControllerProvider).api.createAdminCoupon({
          'code': code.text.trim(),
          'label': label.text.trim(),
          'discount': discount.text.trim(),
          'expires': expires.text.trim(),
          'active': true,
        });
      },
    );
    for (final controller in [code, label, discount, expires]) {
      controller.dispose();
    }
    if (mounted) setState(_reload);
  }
}
