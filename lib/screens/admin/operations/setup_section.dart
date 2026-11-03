import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../models/notification.dart';
import '../../../services/friendly_error.dart';
import 'admin_common.dart';

const _setupTabs = ['Services', 'Notifications', 'Audit'];

/// Admin setup: service configuration, customer notifications and the admin
/// inbox, and the audit log.
class AdminSetupSection extends ConsumerStatefulWidget {
  const AdminSetupSection({super.key});

  @override
  ConsumerState<AdminSetupSection> createState() => _AdminSetupSectionState();
}

class _AdminSetupSectionState extends ConsumerState<AdminSetupSection> {
  int _tab = 0;
  late Future<List<AccountRecord>> _services;

  @override
  void initState() {
    super.initState();
    _reloadServices();
  }

  void _reloadServices() {
    _services = ref.read(appControllerProvider).api.adminServices();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.gutter),
      children: [
        SegmentedTabs(
          labels: _setupTabs,
          selectedIndex: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
        const SizedBox(height: AppSpace.lg),
        switch (_tab) {
          0 => _servicesTab(),
          1 => const _NotificationsPanel(),
          _ => const _AuditPanel(),
        },
      ],
    );
  }

  Widget _servicesTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Add service',
                  icon: Icons.add,
                  expand: false,
                  onPressed: () => _editService(),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => setState(_reloadServices),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          FutureBuilder<List<AccountRecord>>(
            future: _services,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(message: 'Loading services...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                  error: snapshot.error!,
                  message: 'Services could not be loaded. '
                      '${friendlyError(snapshot.error!)}',
                  onRetry: () => setState(_reloadServices),
                );
              }
              final records = snapshot.data ?? const <AccountRecord>[];
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.water_drop_outlined,
                  title: 'No services configured.',
                );
              }
              return Column(
                children: [
                  for (final record in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: AdminRecordRow(
                        record: record,
                        trailing: IconButton(
                          tooltip: 'Edit service options',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editService(record),
                        ),
                        onTap: () => _editService(record),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );

  Future<void> _editService([AccountRecord? record]) async {
    final saved = await showAppBottomSheet<bool>(
      context,
      builder: (_) => _ServiceEditorSheet(record: record),
    );
    if (saved == true && mounted) {
      setState(_reloadServices);
      showAppSnack(
        context,
        'Service configuration saved.',
        variant: AppSnackVariant.success,
      );
    }
  }
}

/// Service code, name, base price and the option lists. The code can't change
/// once a service exists. Tanker counts must be between 1 and 5.
class _ServiceEditorSheet extends ConsumerStatefulWidget {
  const _ServiceEditorSheet({this.record});

  final AccountRecord? record;

  @override
  ConsumerState<_ServiceEditorSheet> createState() =>
      _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends ConsumerState<_ServiceEditorSheet> {
  late final _config = widget.record?.data['config'] is Map
      ? Map<String, dynamic>.from(widget.record!.data['config'] as Map)
      : const <String, dynamic>{};
  late final _code = TextEditingController(
    text: (widget.record?.data['code'] ?? '').toString(),
  );
  late final _name = TextEditingController(
    text: (widget.record?.data['name'] ?? '').toString(),
  );
  late final _price = TextEditingController(
    text: (widget.record?.data['base_price_paise'] ?? '').toString(),
  );
  late final _capacities = TextEditingController(
    text: _optionText('capacityOptions'),
  );
  late final _details = TextEditingController(
    text: _optionText('detailOptions'),
  );
  late final _waterTypes = TextEditingController(
    text: _optionText('waterTypeOptions'),
  );
  late final _tankerCounts = TextEditingController(
    text: _optionText('tankerCountOptions'),
  );
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  String _optionText(String key) {
    final values = _config[key];
    return values is List
        ? values.map((value) => value.toString()).join('\n')
        : '';
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _price,
      _capacities,
      _details,
      _waterTypes,
      _tankerCounts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final counts = _parseOptionLines(_tankerCounts.text);
    if (counts.any((item) => !const ['1', '2', '3', '4', '5'].contains(item))) {
      setState(() => _error = 'Tanker counts must be between 1 and 5.');
      return;
    }
    final record = widget.record;
    final body = <String, dynamic>{
      if (record == null) 'code': _code.text.trim(),
      'name': _name.text.trim(),
      'basePricePaise': int.parse(_price.text.trim()),
      'capacityOptions': _parseOptionLines(_capacities.text),
      'detailOptions': _parseOptionLines(_details.text),
      'waterTypeOptions': _parseOptionLines(_waterTypes.text),
      'tankerCountOptions': counts,
      if (record == null) 'isActive': true,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(appControllerProvider).api;
      if (record == null) {
        await api.createAdminService(body);
      } else {
        await api.updateAdminService(record.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          _error = friendlyError(value);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return Form(
      key: _formKey,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit service options' : 'Add service',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.lg),
              AppTextField(
                controller: _code,
                label: 'Service code',
                enabled: !editing,
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a service code.'
                    : null,
              ),
              const SizedBox(height: AppSpace.md),
              AppTextField(
                controller: _name,
                label: 'Name',
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a service name.'
                    : null,
              ),
              const SizedBox(height: AppSpace.md),
              AppTextField(
                controller: _price,
                label: 'Base price (paise)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 0
                      ? 'Enter a valid non-negative price.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpace.md),
              _optionField(_capacities, 'Capacity options'),
              _optionField(_details, 'Service detail options'),
              _optionField(_waterTypes, 'Water type options'),
              _optionField(_tankerCounts, 'Tanker count options (1–5)'),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(_error!,
                    style: TextStyle(color: context.colors.danger.fg)),
              ],
              const SizedBox(height: AppSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: AppTextField(
          controller: controller,
          label: label,
          helper: 'One option per line',
          minLines: 2,
          maxLines: 5,
        ),
      );
}

/// Options typed one per line, trimmed, without blanks or repeats.
List<String> _parseOptionLines(String value) => value
    .split('\n')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);

/// Send a customer notification, and the admin's own inbox grouped by booking.
class _NotificationsPanel extends ConsumerWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(adminNotificationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Send customer notification',
          icon: Icons.notifications_outlined,
          onPressed: () => _send(context, ref),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('ADMIN INBOX', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpace.md),
        inbox.when(
          loading: () => const LoadingState(message: 'Loading...'),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(adminNotificationsProvider),
          ),
          data: (items) {
            final groups = groupNotificationsByDay(items);
            if (groups.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No admin notifications.',
              );
            }
            return Column(
              children: [
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: _NotificationGroupCard(group: group),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final customer = TextEditingController();
    final title = TextEditingController();
    final detail = TextEditingController();
    await adminForm(
      context,
      title: 'Send notification',
      fields: [
        ('Customer ID', customer),
        ('Title', title),
        ('Message', detail),
      ],
      submit: () => ref.read(appControllerProvider).api.sendAdminNotification({
        'customerId': customer.text.trim(),
        'title': title.text.trim(),
        'detail': detail.text.trim(),
      }),
    );
    customer.dispose();
    title.dispose();
    detail.dispose();
  }
}

class _NotificationGroupCard extends ConsumerWidget {
  const _NotificationGroupCard({required this.group});

  final NotificationGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = group.unreadItems.length;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(group.title),
        subtitle: Text(
          '${group.items.length} event(s)'
          '${unread == 0 ? '' : ' • $unread unread'}',
        ),
        trailing: unread == 0
            ? null
            : TextButton(
                onPressed: () async {
                  try {
                    final api = ref.read(appControllerProvider).api;
                    for (final item in group.unreadItems) {
                      await api.markAdminNotificationRead(item.id);
                    }
                    ref.invalidate(adminNotificationsProvider);
                  } catch (error) {
                    if (context.mounted) {
                      showAppSnack(
                        context,
                        'Could not mark notifications as read: $error',
                        variant: AppSnackVariant.error,
                      );
                    }
                  }
                },
                child: const Text('Mark as read'),
              ),
        children: [
          for (final item in group.items)
            AppListRow(
              title: item.title,
              subtitle: [
                if (item.status != null) 'Status: ${item.status}',
                item.message,
                if (item.createdAt != null)
                  item.createdAt!.toLocal().toString().substring(0, 16),
              ].where((part) => part.isNotEmpty).join('\n'),
            ),
        ],
      ),
    );
  }
}

/// Audit log with action and entity filters and paging.
class _AuditPanel extends ConsumerStatefulWidget {
  const _AuditPanel();

  @override
  ConsumerState<_AuditPanel> createState() => _AuditPanelState();
}

class _AuditPanelState extends ConsumerState<_AuditPanel> {
  int _page = 1;
  String _action = '';
  String _entity = '';

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(
      adminAuditLogsProvider((
        page: _page,
        action: _action,
        entityType: _entity,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Action',
                onChanged: (value) => setState(() => _action = value),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: AppTextField(
                label: 'Entity',
                onChanged: (value) => setState(() => _entity = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        logs.when(
          loading: () => const LoadingState(message: 'Loading audit logs...'),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(adminAuditLogsProvider),
          ),
          data: (page) {
            final rows = (page['rows'] as List?)?.whereType<Map>().toList() ??
                const <Map>[];
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.history_outlined,
                title: 'No audit entries.',
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: AppListRow(
                        title:
                            '${row['action'] ?? ''} • ${row['entity_type'] ?? ''}',
                        subtitle: (row['metadata'] ?? '').toString(),
                      ),
                    ),
                  ),
                AdminPager(
                  page: _page,
                  hasNext: rows.length >= 50,
                  onPage: (value) => setState(() => _page = value),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
