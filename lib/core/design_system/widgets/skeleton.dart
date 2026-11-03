import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Loading placeholder block. Shimmers unless reduced motion is on, in which
/// case it is a still block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.chip,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.hairline,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (AppMotion.reduced(context)) return box;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: colors.hairline,
        highlightColor: colors.surface,
        child: box,
      ),
    );
  }
}

/// Stack of skeleton cards for a list that is still loading. Fixed length, so
/// it can sit inside a Column.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.gutter,
      vertical: AppSpace.md,
    ),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, index) => SkeletonBox(
        height: itemHeight,
        radius: AppRadius.card,
      ),
    );
  }
}
