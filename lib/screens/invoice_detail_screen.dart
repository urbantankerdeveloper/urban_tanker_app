import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/providers.dart';
import '../core/design_system/design_system.dart';
import '../models/account.dart';
import '../services/secure_screen.dart';

/// Invoice fields that may leave the device through the share sheet.
const _shareableInvoiceFields = [
  'id',
  'number',
  'service',
  'amount',
  'status',
  'issued_at',
];

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(customerInvoiceProvider(invoiceId));
    return SecureScope(
      child: AppScaffold(
        title: 'Invoice',
        body: invoice.when(
          loading: () => const LoadingState(message: 'Loading invoice...'),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(customerInvoiceProvider(invoiceId)),
          ),
          data: (value) => _InvoiceBody(invoice: value),
        ),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice});

  final AccountRecord invoice;

  /// Totals and tax lines are set apart below the perforation.
  static bool _isTotalLine(String key) {
    final lower = key.toLowerCase();
    return lower.contains('total') ||
        lower.contains('gst') ||
        lower.contains('tax') ||
        lower.contains('discount');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries =
        invoice.data.entries.where((entry) => entry.value != null).toList();
    final lines = [
      for (final entry in entries)
        if (!_isTotalLine(entry.key)) entry,
    ];
    final totals = [
      for (final entry in entries)
        if (_isTotalLine(entry.key)) entry,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.xxxl,
      ),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RECEIPT', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Invoice ${invoice.data['number'] ?? invoice.id}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.lg),
              for (final entry in lines) _LineItem(entry: entry),
              if (totals.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                const _Perforation(),
                const SizedBox(height: AppSpace.lg),
                for (final entry in totals)
                  _LineItem(entry: entry, emphasis: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Share',
                icon: Icons.share_outlined,
                onPressed: () => _share(context),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: SecondaryButton(
                label: 'Save',
                icon: Icons.download_outlined,
                onPressed: () => _save(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'This invoice is currently provided as data by the server. A PDF export can be enabled when the backend exposes a file URL.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  String get _content =>
      const JsonEncoder.withIndent('  ').convert(invoice.data);

  /// Only the allow-listed fields are shared. Other fields stay on the device.
  String get _shareContent {
    final shared = <String, dynamic>{
      for (final key in _shareableInvoiceFields)
        if (invoice.data.containsKey(key)) key: invoice.data[key],
    };
    return const JsonEncoder.withIndent('  ').convert(shared);
  }

  Future<void> _share(BuildContext context) async {
    try {
      final file = XFile.fromData(
        utf8.encode(_shareContent),
        name: 'invoice-${invoice.id}.json',
        mimeType: 'application/json',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], text: 'Urban Tanker invoice'),
      );
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not share invoice: $error',
          variant: AppSnackVariant.error,
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
        showAppSnack(
          context,
          'Invoice saved to the app. It is removed when you sign out.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not save invoice: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }
}

/// One receipt row: a humanized label on the left and the value on the right.
class _LineItem extends StatelessWidget {
  const _LineItem({required this.entry, this.emphasis = false});

  final MapEntry<String, dynamic> entry;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        emphasis ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              _label(entry.key),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Flexible(
            child: Text(
              '${entry.value}',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  /// `issued_at` becomes `Issued at`.
  static String _label(String key) {
    final words = key.replaceAll('_', ' ').trim();
    if (words.isEmpty) return words;
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// Dashed tear line between the items and the totals, with notches at each
/// side like a paper receipt.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _PerforationPainter(
              color: context.colors.hairline,
              // The notches show the page behind the card.
              background: context.colors.scaffold,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final dash = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var x = 12.0; x < size.width - 12; x += 10) {
      canvas.drawLine(Offset(x, mid), Offset(x + 5, mid), dash);
    }
    // Notches cut into the card edges.
    final notch = Paint()..color = background;
    canvas.drawCircle(Offset(-AppSpace.lg, mid), 14, notch);
    canvas.drawCircle(Offset(size.width + AppSpace.lg, mid), 14, notch);
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}
