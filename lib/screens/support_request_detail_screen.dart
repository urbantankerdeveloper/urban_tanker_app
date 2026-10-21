import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/account.dart';

class SupportRequestDetailScreen extends ConsumerWidget {
  const SupportRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(customerSupportRequestProvider(requestId));
    return Scaffold(
      appBar: AppBar(title: const Text('Support request')),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 44),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(customerSupportRequestProvider(requestId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (item) => _SupportRequestBody(item: item),
      ),
    );
  }
}

class _SupportRequestBody extends StatelessWidget {
  const _SupportRequestBody({required this.item});

  final AccountRecord item;

  @override
  Widget build(BuildContext context) {
    final timeline = item.timeline;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Chip(
          avatar: const Icon(Icons.flag_outlined, size: 18),
          label: Text(item.status.isEmpty ? 'Unknown status' : item.status),
        ),
        if (item.bookingId != null) ...[
          const SizedBox(height: 8),
          Text('Linked booking: ${item.bookingId}'),
        ],
        const SizedBox(height: 20),
        Text('Conversation', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (timeline.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.message_outlined),
              title: Text(item.detail),
              subtitle: const Text('Customer message'),
            ),
          )
        else
          ...timeline.map(
            (entry) => Card(
              child: ListTile(
                leading: Icon(
                  entry['type'] == 'support'
                      ? Icons.support_agent_outlined
                      : Icons.person_outline,
                ),
                title: Text(
                  entry['type'] == 'support' ? 'Support team' : 'You',
                ),
                subtitle: Text(
                  '${entry['message'] ?? ''}\n${_date(entry['createdAt'])}',
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? '' : parsed.toLocal().toString().split('.').first;
  }
}
