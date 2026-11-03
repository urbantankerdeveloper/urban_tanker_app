import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/design_system/design_system.dart';
import '../models/account.dart';

/// Support request with its conversation shown as a chat thread.
class SupportRequestDetailScreen extends ConsumerWidget {
  const SupportRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(customerSupportRequestProvider(requestId));
    return AppScaffold(
      title: 'Support request',
      body: request.when(
        loading: () => const LoadingState(message: 'Loading your request...'),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(customerSupportRequestProvider(requestId)),
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
    final theme = Theme.of(context);
    final colors = context.colors;
    final timeline = item.timeline;
    final status = item.status.isEmpty ? 'Unknown status' : item.status;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.xxxl,
      ),
      children: [
        Text(item.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            StatusChip(
              label: status,
              icon: Icons.flag_outlined,
              tone: _toneFor(status, colors),
            ),
            if (item.bookingId != null) ...[
              const SizedBox(width: AppSpace.md),
              Flexible(
                child: Text(
                  'Booking ${item.bookingId}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Text('CONVERSATION', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpace.md),
        if (timeline.isEmpty)
          _Bubble(
            fromSupport: false,
            text: item.detail,
            time: null,
          )
        else
          for (final entry in timeline)
            _Bubble(
              fromSupport: entry['type'] == 'support',
              text: '${entry['message'] ?? ''}',
              time: _date(entry['createdAt']),
            ),
      ],
    );
  }

  /// Open requests are informational, closed ones are a success, anything
  /// else is neutral. The text always carries the status, so color is extra.
  static AppTone _toneFor(String status, AppColors colors) {
    final value = status.toLowerCase();
    if (value.contains('resolved') || value.contains('closed')) {
      return colors.success;
    }
    if (value.contains('open') || value.contains('pending')) {
      return colors.info;
    }
    return colors.neutral;
  }

  String? _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return null;
    return parsed.toLocal().toString().split('.').first;
  }
}

/// One message in the thread. Support sits on the left, the customer on the right.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromSupport, required this.text, this.time});

  final bool fromSupport;
  final String text;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final fill =
        fromSupport ? colors.surface : colors.primary.withValues(alpha: 0.14);
    return Align(
      alignment: fromSupport
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpace.md),
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromSupport ? 'Support team' : 'You',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(text, style: theme.textTheme.bodyLarge),
            if (time != null && time!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(time!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
