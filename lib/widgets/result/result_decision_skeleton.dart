import 'package:flutter/material.dart';

class ResultDecisionSkeletonCard extends StatefulWidget {
  const ResultDecisionSkeletonCard({
    super.key,
    required this.isDarkMode,
    this.showResultListSkeleton = false,
  });

  final bool isDarkMode;
  final bool showResultListSkeleton;

  @override
  State<ResultDecisionSkeletonCard> createState() =>
      _ResultDecisionSkeletonCardState();
}

class _ResultDecisionSkeletonCardState
    extends State<ResultDecisionSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final borderColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE5E7EB);

    final cardColor =
    widget.isDarkMode ? const Color(0xFF1F1F22) : Colors.white;

    final baseColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE8EBF0);

    final highlightColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.16)
        : const Color(0xFFF5F7FA);

    Widget line(double width, {double height = 12}) {
      return _ShimmerBox(
        width: width,
        height: height,
        radius: 8,
        animation: _controller,
        baseColor: baseColor,
        highlightColor: highlightColor,
        enabled: !reduceMotion,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(96, height: 17),
              const SizedBox(height: 10),
              line(double.infinity, height: 22),
              const SizedBox(height: 6),
              line(160, height: 13),
              const SizedBox(height: 8),
              line(118, height: 15),
              const SizedBox(height: 10),
              line(double.infinity, height: 11),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _SkeletonChip(
                    width: 54,
                    animation: _controller,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    enabled: !reduceMotion,
                  ),
                  _SkeletonChip(
                    width: 68,
                    animation: _controller,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    enabled: !reduceMotion,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.showResultListSkeleton) ...[
          const SizedBox(height: 16),
          ...List.generate(
            2,
                (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 1 ? 0 : 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF252529)
                      : const Color(0xFFFBFCFE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(140, height: 15),
                    const SizedBox(height: 6),
                    line(105, height: 12),
                    const SizedBox(height: 7),
                    line(90, height: 12),
                    const SizedBox(height: 7),
                    line(240, height: 11),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({
    required this.width,
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required this.enabled,
  });

  final double width;
  final Animation<double> animation;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: width,
      height: 22,
      radius: 999,
      animation: animation,
      baseColor: baseColor,
      highlightColor: highlightColor,
      enabled: enabled,
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required this.enabled,
  });

  final double width;
  final double height;
  final double radius;
  final Animation<double> animation;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (!enabled) return child;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final shimmerPosition = animation.value * 2 - 1;

        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - shimmerPosition, 0),
              end: Alignment(1.0 - shimmerPosition, 0),
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}