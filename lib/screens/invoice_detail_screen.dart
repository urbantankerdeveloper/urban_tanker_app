import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/providers.dart';
import '../app/page_components.dart';
import '../models/account.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(customerInvoiceProvider(invoiceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: invoice.when(
        loading: () => const AppStateView.loading(),
        error: (error, _) => AppStateView.error(
          error: error,
          onRetry: () => ref.invalidate(customerInvoiceProvider(invoiceId)),
        ),
        data: (value) => _InvoiceBody(invoice: value),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice});

  final AccountRecord invoice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppPageInsets.standard,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_details(invoice)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'This invoice is currently provided as data by the server. A PDF export can be enabled when the backend exposes a file URL.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String get _content =>
      const JsonEncoder.withIndent('  ').convert(invoice.data);

  Future<void> _share(BuildContext context) async {
    try {
      final file = XFile.fromData(
        utf8.encode(_content),
        name: 'invoice-${invoice.id}.json',
        mimeType: 'application/json',
      );
      await Share.shareXFiles([file], text: 'Urban Tanker invoice');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share invoice: $error')),
        );
      }
    }
  }

  Future<void> _save(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoice-${invoice.id}.json');
      await file.writeAsString(_content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice saved to ${file.path}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save invoice: $error')),
        );
      }
    }
  }

  String _details(AccountRecord value) {
    return value.data.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }
}
