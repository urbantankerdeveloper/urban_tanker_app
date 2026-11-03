import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';
import 'identity.dart';
import 'surfaces.dart';

/// Page frame with an optional title bar, a gradient header variant, safe
/// areas, and a pull-to-refresh slot. [body] should be scrollable when
/// [onRefresh] is set.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    super.key,
    this.title,
    this.actions,
    this.gradientHeader = false,
    this.onRefresh,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;

  /// Uses the hero gradient behind the title bar, with light text.
  final bool gradientHeader;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasAppBar = title != null || actions != null;
    final content = onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);
    return Scaffold(
      appBar: hasAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              actions: actions,
              foregroundColor: gradientHeader ? colors.onHero : null,
              flexibleSpace: gradientHeader
                  ? DecoratedBox(
                      decoration: BoxDecoration(gradient: colors.heroGradient),
                    )
                  : null,
            )
          : null,
      body: SafeArea(top: !hasAppBar, child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Greeting, title, avatar and notification bell for the top of a home screen.
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.greeting,
    required this.title,
    super.key,
    this.avatarName,
    this.avatarUrl,
    this.unreadCount = 0,
    this.onNotifications,
  });

  final String greeting;
  final String title;
  final String? avatarName;
  final String? avatarUrl;
  final int unreadCount;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (avatarName != null) ...[
          AppAvatar(name: avatarName!, imageUrl: avatarUrl),
          const SizedBox(width: AppSpace.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: theme.textTheme.bodyMedium),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        if (onNotifications != null)
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_none_outlined),
            ),
          ),
      ],
    );
  }
}

/// Floating glass bar with an animated active pill and an icon that swaps to
/// its filled form when selected. Built for all four roles; wired up in Phase 2.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
        child: GlassCard(
          radius: AppRadius.pillBorder,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination for [AppBottomNav]. [selectedIcon] defaults to [icon].
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.base),
            curve: AppMotion.curve,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            decoration: BoxDecoration(
              color: selected ? colors.primary.withValues(alpha: 0.16) : null,
              borderRadius: AppRadius.pillBorder,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    size: 24,
                    color: selected ? colors.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
