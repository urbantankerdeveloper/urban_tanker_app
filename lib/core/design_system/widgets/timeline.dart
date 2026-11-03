import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

enum TimelineState { done, current, upcoming }

/// One step of an order's progress. [state] drives both color and icon.
class TimelineStep {
  const TimelineStep({
    required this.title,
    required this.state,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final TimelineState state;
}

/// Vertical order-progress stepper. Done steps show a check, the current step
/// a dot in a ring, and upcoming steps an empty ring.
class Timeline extends StatelessWidget {
  const Timeline({required this.steps, super.key});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final done = step.state == TimelineState.done;
    final upcoming = step.state == TimelineState.upcoming;
    final stateLabel = switch (step.state) {
      TimelineState.done => 'Done',
      TimelineState.current => 'Current',
      TimelineState.upcoming => 'Upcoming',
    };
    return Semantics(
      label: '$stateLabel: ${step.title}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  _Dot(state: step.state),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: done ? colors.primary : colors.hairline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLast ? 0 : AppSpace.xl,
                  top: 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: upcoming
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (step.subtitle != null)
                      Text(step.subtitle!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = 24.0;
    return switch (state) {
      TimelineState.done => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: colors.brandGradient,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 14, color: colors.onHero),
        ),
      TimelineState.current => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      TimelineState.upcoming => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.hairline, width: 2),
          ),
        ),
    };
  }
}
