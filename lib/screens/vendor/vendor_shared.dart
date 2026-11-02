import 'package:flutter/material.dart';

import '../../app/page_components.dart';

class VendorEmpty extends StatelessWidget {
  const VendorEmpty({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(message)),
      );
}

class VendorError extends StatelessWidget {
  const VendorError({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => AppStateView.error(
        error: message,
        onRetry: retry,
      );
}

String formatDate(DateTime? value) => value == null
    ? 'Date not set'
    : value.toLocal().toString().split(' ').first;
