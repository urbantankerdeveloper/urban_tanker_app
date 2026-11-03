import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import 'password_rules.dart';

/// Live strength bar and checklist under a new password. Each rule has an icon
/// and text, so it does not depend on colour alone.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final checks = passwordChecks(password);
    final score = checks.where((check) => check.met).length;
    final barColor = score <= 1
        ? colors.danger.fg
        : score == checks.length
            ? colors.success.fg
            : colors.warning.fg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < checks.length; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < score ? barColor : colors.hairline,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              if (i < checks.length - 1) const SizedBox(width: AppSpace.xs),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        for (final check in checks)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Row(
              children: [
                Icon(
                  check.met
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: check.met ? colors.success.fg : colors.neutral.fg,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(check.label, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
