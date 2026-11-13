import 'dart:async';

import 'package:flutter/material.dart';

String formatLastUpdated(DateTime lastUpdated, {DateTime? now}) {
  final elapsedSeconds =
      (now ?? DateTime.now()).difference(lastUpdated).inSeconds;
  if (elapsedSeconds < 5) return 'Updated just now';
  if (elapsedSeconds < 60) return 'Updated ${elapsedSeconds}s ago';

  final elapsedMinutes = elapsedSeconds ~/ 60;
  if (elapsedMinutes < 60) return 'Updated ${elapsedMinutes}m ago';

  final elapsedHours = elapsedMinutes ~/ 60;
  if (elapsedHours < 24) return 'Updated ${elapsedHours}h ago';
  return 'Updated ${elapsedHours ~/ 24}d ago';
}

class LastUpdatedLabel extends StatefulWidget {
  const LastUpdatedLabel({required this.lastUpdated, super.key});

  final DateTime lastUpdated;

  @override
  State<LastUpdatedLabel> createState() => _LastUpdatedLabelState();
}

class _LastUpdatedLabelState extends State<LastUpdatedLabel> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = _now.add(const Duration(seconds: 1)));
      }
    });
  }

  @override
  void didUpdateWidget(covariant LastUpdatedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastUpdated != oldWidget.lastUpdated) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = formatLastUpdated(widget.lastUpdated, now: _now);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.update,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
