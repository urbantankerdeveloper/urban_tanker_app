import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/page_components.dart';

class AdminPulseScreen extends ConsumerWidget {
  const AdminPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(adminHealthProvider);
    return healthState.when(
      loading: () => const AppStateView.loading(),
      error: (error, _) => AppStateView.error(
        error: error,
        onRetry: () => ref.invalidate(adminHealthProvider),
      ),
      data: (health) {
        final migrations = health['migrations'] is List
            ? (health['migrations'] as List).whereType<Map>().toList()
            : const [];
        // Fixed widgets before and after the migration rows. Only the
        // migration rows come from the server, so only they are built lazily.
        final header = <Widget>[
          Text('Platform pulse',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _MetricTile(
            label: 'System status',
            value: health['ok'] == true ? 'Healthy' : 'Attention required',
            icon: health['ok'] == true
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
          ),
          _MetricTile(
            label: 'Realtime',
            value: (health['realtime'] as Map?)?['connected'] == true
                ? 'Connected'
                : 'Unavailable',
            icon: Icons.radar_outlined,
          ),
          _MetricTile(
            label: 'Storage',
            value: (health['storage'] as Map?)?['configured'] == true
                ? 'Configured'
                : 'Not configured',
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 12),
          const Text('Migration checks'),
        ];
        final footer = <Widget>[
          if ((health['configuration'] as Map?)
                  ?.values
                  .any((value) => value != true) ==
              true)
            const ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Configuration warnings'),
              subtitle: Text('One or more integrations are not configured.'),
            ),
          FilledButton.tonal(
            onPressed: () async {
              try {
                await ref.read(appControllerProvider).api.adminStorageCleanup();
                ref.invalidate(adminHealthProvider);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cleanup failed: $error')),
                  );
                }
              }
            },
            child: const Text('Run storage cleanup'),
          ),
        ];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminHealthProvider),
          child: ListView.builder(
            padding: AppPageInsets.standard,
            itemCount: header.length + migrations.length + footer.length,
            itemBuilder: (_, index) {
              if (index < header.length) return header[index];
              index -= header.length;
              if (index < migrations.length) {
                final item = migrations[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    item['applied'] == true ? Icons.check : Icons.error_outline,
                  ),
                  title: Text((item['table'] ?? 'Table').toString()),
                  subtitle: Text(item['applied'] == true
                      ? 'Available'
                      : (item['error'] ?? 'Unavailable').toString()),
                  trailing: item['applied'] == true
                      ? null
                      : TextButton(
                          onPressed: () => ref.invalidate(adminHealthProvider),
                          child: const Text('Retry'),
                        ),
                );
              }
              return footer[index - migrations.length];
            },
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value),
        ),
      );
}
