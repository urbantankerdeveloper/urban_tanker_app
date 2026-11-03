import 'package:flutter/material.dart';

import '../../../app/page_components.dart';
import '../../../app/theme.dart';
import '../../../models/service.dart';
import '../../../models/session.dart';

/// Customer Home tab: greeting, a "start a booking" card, and the service list.
/// Loading, error and empty states replace the service cards.
class CustomerOverview extends StatelessWidget {
  const CustomerOverview({
    required this.user,
    required this.services,
    required this.loading,
    required this.onRetry,
    required this.onBook,
    super.key,
    this.error,
  });

  final SessionUser user;
  final List<TankerService> services;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    // The loading, error, or empty state is shown in place of the service cards.
    final Widget? statusCard = loading
        ? const AppStateInline.loading()
        : error != null
            ? _ErrorCard(message: error!, onRetry: onRetry)
            : services.isEmpty
                ? const _EmptyCard(
                    message: 'No services are available right now.',
                  )
                : null;
    // Fixed intro above the service cards. Only the service cards are lazy.
    final header = <Widget>[
      Text(
        'Good to see you, ${user.name.split(' ').first}.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      const Text('Reliable water delivery, without the runaround.'),
      const SizedBox(height: 22),
      Card(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF17454D)
            : ink,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEXT DELIVERY',
                style: TextStyle(color: mint, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Book a tanker when you need it.',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Start a booking'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text('Available services', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
    ];
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.builder(
        padding: AppPageInsets.standard,
        itemCount: header.length + (statusCard == null ? services.length : 1),
        itemBuilder: (_, index) {
          if (index < header.length) return header[index];
          if (statusCard != null) return statusCard;
          return _ServiceCard(service: services[index - header.length]);
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final TankerService service;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: mint,
            child: Icon(Icons.water_drop_outlined, color: ink),
          ),
          title: Text(service.name),
          subtitle: Text(service.description.isEmpty
              ? service.category
              : service.description),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppStateInline.error(
        error: message,
        onRetry: () => onRetry(),
      );
}
