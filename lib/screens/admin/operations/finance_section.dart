import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_feature_flags.dart';
import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../services/friendly_error.dart';
import '../admin_partner_review_screen.dart';
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

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _query = '';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final future = switch (_tab) {
      0 => _coupons,
      1 => _payouts,
      _ => _partners,
    };
    final content = ListView(
      padding: AppPageInsets.withSafeAreaBottom(
        context,
        AppPageInsets.standard,
      ),
      children: [
        SegmentedTabs(
          labels: _financeTabs,
          selectedIndex: _tab,
          onChanged: _selectTab,
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
                    child: AdminRecordRow(
                      record: record,
                      onTap: _tab == 2 && AuthFeatureFlags.newUiEnabled
                          ? () => _openPartnerReview(record)
                          : null,
                      trailing: _tab == 2
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'View application history',
                                  onPressed: () {
                                    if (AuthFeatureFlags.newUiEnabled) {
                                      _openPartnerReview(record, initialTab: 2);
                                    } else {
                                      _showPartnerHistory(record);
                                    }
                                  },
                                  icon: const Icon(Icons.history),
                                ),
                                IconButton(
                                  tooltip: 'Review partner application',
                                  onPressed: () {
                                    if (AuthFeatureFlags.newUiEnabled) {
                                      _openPartnerReview(record);
                                    } else {
                                      _reviewPartnerApplication(record);
                                    }
                                  },
                                  icon: const Icon(Icons.fact_check_outlined),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
    return SwipeNavigationArea(
      onSwipeLeft: _tab < _financeTabs.length - 1
          ? () => _selectTab(_tab + 1)
          : null,
      onSwipeRight: _tab > 0 ? () => _selectTab(_tab - 1) : null,
      child: content,
    );
  }

  bool _matches(AccountRecord record) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return record.title.toLowerCase().contains(query) ||
        record.detail.toLowerCase().contains(query);
  }

  Future<void> _openPartnerReview(
    AccountRecord record, {
    int initialTab = 0,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminPartnerReviewScreen(
          application: record,
          initialTab: initialTab,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _showPartnerHistory(AccountRecord record) async {
    final history = ref
        .read(appControllerProvider)
        .api
        .partnerApplicationHistory(record.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: FutureBuilder<List<AccountRecord>>(
            future: history,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(
                  message: 'Loading application history...',
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Application history unavailable: ${friendlyError(snapshot.error!)}',
                );
              }
              final entries = snapshot.data ?? const <AccountRecord>[];
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.history,
                  title: 'No review history is available.',
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Application history',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final entry in entries) ...[
                      Text(
                        '${entry.data['created_at'] ?? ''} · ${entry.data['action'] ?? ''}',
                        style: Theme.of(sheetContext).textTheme.labelLarge,
                      ),
                      Text(
                        '${entry.data['old_status'] ?? '-'} -> ${entry.data['new_status'] ?? ''}',
                      ),
                      if ((entry.data['review_note'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text(entry.data['review_note'].toString()),
                      const Divider(height: AppSpace.xl),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _reviewPartnerApplication(AccountRecord record) async {
    final note = TextEditingController(
      text: (record.data['review_note'] ?? '').toString(),
    );
    var status =
        const {
          'submitted',
          'under_review',
          'additional_info_required',
          'approved',
          'rejected',
        }.contains(record.status)
        ? record.status
        : 'submitted';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Review ${record.title}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Application status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'submitted',
                    child: Text('Submitted'),
                  ),
                  DropdownMenuItem(
                    value: 'under_review',
                    child: Text('Under review'),
                  ),
                  DropdownMenuItem(
                    value: 'additional_info_required',
                    child: Text('Additional information required'),
                  ),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => status = value);
                },
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: note,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Review note'),
              ),
              const SizedBox(height: AppSpace.md),
              PrimaryButton(
                label: 'Save review',
                icon: Icons.save_outlined,
                expand: true,
                onPressed: () async {
                  try {
                    await ref
                        .read(appControllerProvider)
                        .api
                        .reviewPartnerApplication(
                          record.id,
                          status: status,
                          reviewNote: note.text.trim().isEmpty
                              ? null
                              : note.text.trim(),
                        );
                    if (!mounted || !sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    setState(_reload);
                  } catch (error) {
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(content: Text(friendlyError(error))),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    note.dispose();
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
