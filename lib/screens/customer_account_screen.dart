import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/account.dart';
import '../services/api_client.dart';
import 'invoice_detail_screen.dart';
import 'support_request_detail_screen.dart';

class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        profile.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _AccountError(
            message: error.toString(),
            retry: () => ref.invalidate(customerProfileProvider),
          ),
          data: (user) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user.name),
              subtitle: Text(
                [user.email, user.phone]
                    .where((value) => value.isNotEmpty)
                    .join('\n'),
              ),
              trailing: IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editProfile(context, ref, user),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _UsageCard(),
        _AccountSection(
          title: 'Offers',
          icon: Icons.local_offer_outlined,
          provider: (ref) => ref.watch(customerOffersProvider),
          retry: (ref) => ref.invalidate(customerOffersProvider),
          empty: 'No active offers.',
        ),
        _MembershipSection(),
        _AccountSection(
          title: 'Yearly contracts',
          icon: Icons.description_outlined,
          provider: (ref) => ref.watch(customerContractsProvider),
          retry: (ref) => ref.invalidate(customerContractsProvider),
          empty: 'No contracts yet.',
          actionLabel: 'Request contract',
          onAction: () => _createContract(context, ref),
          onItemTap: (item) => _showRecord(context, item),
        ),
        _AccountSection(
          title: 'Saved addresses',
          icon: Icons.location_on_outlined,
          provider: (ref) => ref.watch(customerAddressesProvider),
          retry: (ref) => ref.invalidate(customerAddressesProvider),
          empty: 'No saved addresses yet.',
          actionLabel: 'Add address',
          onAction: () => _addAddress(context, ref),
          onItemTap: (item) => _manageAddress(context, ref, item),
        ),
        _AccountSection(
          title: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          provider: (ref) => ref.watch(customerWalletProvider),
          retry: (ref) => ref.invalidate(customerWalletProvider),
          empty: 'No wallet transactions yet.',
          onItemTap: (item) => _showRecord(context, item),
        ),
        _AccountSection(
          title: 'Invoices',
          icon: Icons.receipt_long_outlined,
          provider: (ref) => ref.watch(customerInvoicesProvider),
          retry: (ref) => ref.invalidate(customerInvoicesProvider),
          empty: 'No invoices available.',
          onItemTap: (item) => _showInvoice(context, ref, item),
        ),
        _AccountSection(
          title: 'Subscriptions',
          icon: Icons.autorenew_outlined,
          provider: (ref) => ref.watch(customerSubscriptionsProvider),
          retry: (ref) => ref.invalidate(customerSubscriptionsProvider),
          empty: 'No active subscriptions.',
          onItemTap: (item) => _changeSubscription(context, ref, item),
        ),
        _AccountSection(
          title: 'Support requests',
          icon: Icons.support_agent_outlined,
          provider: (ref) => ref.watch(customerSupportProvider),
          retry: (ref) => ref.invalidate(customerSupportProvider),
          empty: 'No support requests yet.',
          actionLabel: 'New request',
          onAction: () => _createSupport(context, ref),
          onItemTap: (item) {
            if (item.id.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SupportRequestDetailScreen(requestId: item.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _createContract(BuildContext context, WidgetRef ref) async {
    final propertyType = TextEditingController();
    final address = TextEditingController();
    final estimate = TextEditingController(text: '0');
    await _showForm(
      context,
      title: 'Request yearly contract',
      fields: [
        ('Property type', propertyType),
        ('Address', address),
        ('Estimated amount', estimate),
      ],
      submit: () async {
        final amount = double.tryParse(estimate.text.trim());
        if (amount == null || amount < 0) {
          throw const FormatException('Enter a valid non-negative estimate.');
        }
        await ref.read(appControllerProvider).api.createContract(
              propertyType: propertyType.text.trim(),
              address: address.text.trim(),
              estimate: amount,
            );
        ref.invalidate(customerContractsProvider);
      },
    );
    propertyType.dispose();
    address.dispose();
    estimate.dispose();
  }

  void _showRecord(BuildContext context, AccountRecord item) {
    final details = item.data.entries
        .where((entry) => entry.key != 'id' && entry.value != null)
        .map(
          (entry) => '${_label(entry.key)}: ${_displayValue(entry.value)}',
        )
        .join('\n');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Text(
            details.isEmpty
                ? (item.detail.isEmpty ? 'No additional details.' : item.detail)
                : details,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  String _label(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _displayValue(Object? value) {
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    CustomerProfile profile,
  ) async {
    final name = TextEditingController(text: profile.name);
    final email = TextEditingController(text: profile.email);
    final phone = TextEditingController(
      text: profile.phone.replaceFirst('+91', ''),
    );
    final initialName = name.text;
    final initialEmail = email.text;
    final initialPhone = phone.text;
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final dirty = name.text != initialName ||
              email.text != initialEmail ||
              phone.text != initialPhone;
          return AlertDialog(
            title: const Text('Edit profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  TextField(
                    controller: email,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onChanged: (_) => setState(() {}),
                  ),
                  TextField(
                    controller: phone,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: '10-digit mobile'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: !dirty || saving
                    ? null
                    : () async {
                        final emailValue = email.text.trim();
                        final phoneValue =
                            normalizeIndianPhone(phone.text.trim());
                        if (name.text.trim().isEmpty ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(emailValue)) {
                          setState(() =>
                              error = 'Enter a name and valid email address.');
                          return;
                        }
                        if (phoneValue.isNotEmpty &&
                            !RegExp(r'^\d{10}$').hasMatch(phoneValue)) {
                          setState(() =>
                              error = 'Enter a valid 10-digit mobile number.');
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(appControllerProvider)
                              .api
                              .updateProfile(
                                name: name.text.trim(),
                                email: emailValue,
                                phone: phoneValue.isEmpty ? null : phoneValue,
                              );
                          ref.invalidate(customerProfileProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile saved successfully.'),
                              ),
                            );
                          }
                        } catch (value) {
                          if (dialogContext.mounted) {
                            setState(() {
                              saving = false;
                              error = value.toString();
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save profile'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
  }

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    final label = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final pincode = TextEditingController();
    var isDefault = false;
    await _showForm(
      context,
      title: 'Add address',
      fields: [
        ('Label', label),
        ('Address', address),
        ('City', city),
        ('Pincode', pincode),
      ],
      extraContent: StatefulBuilder(
        builder: (context, setState) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: isDefault,
          title: const Text('Use as default address'),
          onChanged: (value) => setState(() => isDefault = value ?? false),
        ),
      ),
      submit: () async {
        await ref.read(appControllerProvider).api.createAddress(
              label: label.text.trim(),
              address: address.text.trim(),
              city: city.text.trim(),
              pincode: pincode.text.trim(),
              isDefault: isDefault,
            );
        ref.invalidate(customerAddressesProvider);
      },
    );
    label.dispose();
    address.dispose();
    city.dispose();
    pincode.dispose();
  }

  Future<void> _manageAddress(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) async {
    if (item.id.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit address'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text(item.isDefault ? 'Default address' : 'Make default'),
              onTap: item.isDefault
                  ? null
                  : () => Navigator.pop(context, 'default'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete address'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await _editAddress(context, ref, item);
    } else if (action == 'default') {
      await _setDefaultAddress(context, ref, item);
    } else if (action == 'delete') {
      await _deleteAddress(context, ref, item);
    }
  }

  Future<void> _editAddress(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) async {
    final label = TextEditingController(text: item.data['label']?.toString());
    final address =
        TextEditingController(text: item.data['address']?.toString());
    final city = TextEditingController(text: item.data['city']?.toString());
    final pincode =
        TextEditingController(text: item.data['pincode']?.toString());
    await _showForm(
      context,
      title: 'Edit address',
      fields: [
        ('Label', label),
        ('Address', address),
        ('City', city),
        ('Pincode', pincode),
      ],
      submit: () async {
        await ref.read(appControllerProvider).api.updateAddress(
              item.id,
              label: label.text.trim(),
              address: address.text.trim(),
              city: city.text.trim(),
              pincode: pincode.text.trim(),
            );
        ref.invalidate(customerAddressesProvider);
      },
    );
    label.dispose();
    address.dispose();
    city.dispose();
    pincode.dispose();
  }

  Future<void> _setDefaultAddress(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) async {
    try {
      await ref.read(appControllerProvider).api.updateAddress(
            item.id,
            isDefault: true,
          );
      ref.invalidate(customerAddressesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default address updated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) async {
    if (item.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${item.title} from saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(appControllerProvider).api.deleteAddress(item.id);
        ref.invalidate(customerAddressesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  Future<void> _createSupport(BuildContext context, WidgetRef ref) async {
    final subject = TextEditingController();
    final message = TextEditingController();
    await _showForm(
      context,
      title: 'New support request',
      fields: [('Subject', subject), ('Message', message)],
      submit: () async {
        await ref.read(appControllerProvider).api.createSupportRequest(
              subject: subject.text.trim(),
              message: message.text.trim(),
            );
        ref.invalidate(customerSupportProvider);
      },
    );
    subject.dispose();
    message.dispose();
  }

  Future<void> _changeSubscription(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) async {
    if (item.id.isEmpty) return;
    final status = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['active', 'paused', 'cancelled']
              .map(
                (value) => ListTile(
                  title: Text(value[0].toUpperCase() + value.substring(1)),
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (status != null) {
      try {
        await ref.read(appControllerProvider).api.updateSubscription(
              item.id,
              status,
            );
        ref.invalidate(customerSubscriptionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Subscription marked $status.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  void _showInvoice(
    BuildContext context,
    WidgetRef ref,
    AccountRecord item,
  ) {
    if (item.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoiceId: item.id),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context, {
    required String title,
    required List<(String, TextEditingController)> fields,
    required Future<void> Function() submit,
    Widget? extraContent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _FormDialog(
        title: title,
        fields: fields,
        submit: submit,
        extraContent: extraContent,
      ),
    ).then((saved) {
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title completed successfully.')),
        );
      }
    });
  }
}

class _UsageCard extends ConsumerWidget {
  const _UsageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(customerUsageProvider);
    return Card(
      child: usage.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(),
        ),
        error: (error, _) => _AccountError(
          message: error.toString(),
          retry: () => ref.invalidate(customerUsageProvider),
        ),
        data: (value) => Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _UsageMetric(label: 'Deliveries', value: '${value.deliveries}'),
              _UsageMetric(
                label: 'Total spend',
                value: '₹${value.totalSpend.toStringAsFixed(0)}',
              ),
              _UsageMetric(
                label: 'Average',
                value: '₹${value.averageAmount.toStringAsFixed(0)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageMetric extends StatelessWidget {
  const _UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _MembershipSection extends ConsumerWidget {
  const _MembershipSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(customerMembershipProvider);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: const Text('Membership'),
        children: [
          membership.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _AccountError(
              message: error.toString(),
              retry: () => ref.invalidate(customerMembershipProvider),
            ),
            data: (value) => value == null
                ? ListTile(
                    title: const Text('No membership yet.'),
                    trailing: TextButton(
                      onPressed: () => _showPlans(context, ref),
                      child: const Text('View plans'),
                    ),
                  )
                : ListTile(
                    title: Text(value.title),
                    subtitle: Text(value.detail),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) async {
                        final confirmed = await _confirmMembershipChange(
                          context,
                          status,
                        );
                        if (!confirmed || !context.mounted) return;
                        try {
                          await ref
                              .read(appControllerProvider)
                              .api
                              .updateMembership(status);
                          ref.invalidate(customerMembershipProvider);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Membership marked $status.'),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'active', child: Text('Active')),
                        PopupMenuItem(value: 'paused', child: Text('Paused')),
                        PopupMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelled'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlans(BuildContext context, WidgetRef ref) async {
    List<AccountRecord> plans;
    try {
      plans = await ref.read(customerMembershipPlansProvider.future);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: plans.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No membership plans are currently available.'),
              )
            : ListView(
                shrinkWrap: true,
                children: plans
                    .map(
                      (plan) => ListTile(
                        title: Text(plan.title),
                        subtitle: Text(plan.detail),
                        onTap: plan.id.isEmpty
                            ? null
                            : () async {
                                try {
                                  await ref
                                      .read(appControllerProvider)
                                      .api
                                      .requestMembership(plan.id);
                                  ref.invalidate(customerMembershipProvider);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Membership request submitted.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                }
                              },
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Future<bool> _confirmMembershipChange(
    BuildContext context,
    String status,
  ) async {
    if (status == 'active') return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
                '${status[0].toUpperCase()}${status.substring(1)} membership?'),
            content: Text(
              status == 'cancelled'
                  ? 'This will cancel your current membership.'
                  : 'Your membership benefits may be paused until it is active again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep membership'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(status[0].toUpperCase() + status.substring(1)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection({
    required this.title,
    required this.icon,
    required this.provider,
    required this.retry,
    required this.empty,
    this.actionLabel,
    this.onAction,
    this.onItemTap,
  });

  final String title;
  final IconData icon;
  final AsyncValue<List<AccountRecord>> Function(WidgetRef ref) provider;
  final void Function(WidgetRef ref) retry;
  final String empty;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ValueChanged<AccountRecord>? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = provider(ref);
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        children: [
          records.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _AccountError(
              message: error.toString(),
              retry: () => retry(ref),
            ),
            data: (items) => items.isEmpty
                ? ListTile(
                    title: Text(empty),
                    trailing: actionLabel == null
                        ? null
                        : TextButton(
                            onPressed: onAction,
                            child: Text(actionLabel!),
                          ),
                  )
                : Column(
                    children: items
                        .take(10)
                        .map(
                          (item) => ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                              title == 'Offers' && item.offerDetail.isNotEmpty
                                  ? item.offerDetail
                                  : item.detail,
                            ),
                            trailing:
                                item.status.isEmpty ? null : Text(item.status),
                            onTap: onItemTap == null
                                ? null
                                : () => onItemTap!(item),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.fields,
    required this.submit,
    this.extraContent,
  });

  final String title;
  final List<(String, TextEditingController)> fields;
  final Future<void> Function() submit;
  final Widget? extraContent;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  bool busy = false;
  String? error;

  Future<void> _submit() async {
    if (widget.fields.any((field) => field.$2.text.trim().isEmpty)) {
      setState(() => error = 'Complete all fields.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit();
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          busy = false;
          error = value.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: field.$2,
                  maxLines: field.$1 == 'Message' ? 4 : 1,
                  decoration: InputDecoration(labelText: field.$1),
                ),
              ),
            ),
            if (widget.extraContent != null) widget.extraContent!,
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('Could not load this section'),
      subtitle: Text(message),
      trailing: IconButton(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}
