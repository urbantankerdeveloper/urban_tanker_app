import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Animated pill selector. The active pill slides between segments.
/// Each segment is a button with a selected state for screen readers.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;

  /// Null disables the control (taps are ignored).
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final count = labels.length;
    return Container(
      height: AppSize.minTouchTarget + AppSpace.sm,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.hairline,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(_pillX(selectedIndex, count), 0),
              duration: AppMotion.duration(context, AppMotion.base),
              curve: AppMotion.curve,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.pillBorder,
                    boxShadow: colors.shadowSoft,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: labels[i],
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: AppRadius.pillBorder,
                        onTap: onChanged == null ? null : () => onChanged!(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.fast,
                            ),
                            style: (theme.textTheme.labelLarge ??
                                    const TextStyle())
                                .copyWith(
                              color: i == selectedIndex
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            child: Text(labels[i], maxLines: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Maps a segment index to an Align x-coordinate in [-1, 1].
  static double _pillX(int index, int count) =>
      count <= 1 ? 0 : -1 + 2 * index / (count - 1);
}
