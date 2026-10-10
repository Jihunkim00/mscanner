import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps a single flow in an unobstructed part of the current app window.
/// The result screen can use both parts through AdaptiveScanPanels.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final regions = DisplayFeatureSubScreen.subScreensInBounds(
      Offset.zero & media.size,
      DisplayFeatureSubScreen.avoidBounds(media),
    ).toList();
    regions.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return DisplayFeatureSubScreen(
      anchorPoint: regions.isEmpty ? Offset.zero : regions.first.center,
      child: child,
    );
  }
}

class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({super.key, required this.child, this.maxWidth = 1000});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      );
}

/// Bounds popup content by the selected sub-screen and keyboard.
class AdaptiveModalSurface extends StatelessWidget {
  const AdaptiveModalSurface({
    super.key,
    required this.child,
    this.scrollable = true,
  });
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => AdaptivePage(
        child: Builder(
            builder: (context) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: LayoutBuilder(
                        builder: (context, constraints) => Align(
                              alignment: Alignment.bottomCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.min(640, constraints.maxWidth),
                                  maxHeight: constraints.maxHeight,
                                ),
                                child: scrollable
                                    ? SingleChildScrollView(child: child)
                                    : child,
                              ),
                            )),
                  ),
                )),
      );
}

/// Reports content bounds in window coordinates, including AppBar, SafeArea
/// and other ancestor offsets. Only layout state changes here.
class WindowLayoutBuilder extends StatefulWidget {
  const WindowLayoutBuilder({super.key, required this.builder});
  final Widget Function(BuildContext, BoxConstraints, Rect) builder;

  @override
  State<WindowLayoutBuilder> createState() => _WindowLayoutBuilderState();
}

class _WindowLayoutBuilderState extends State<WindowLayoutBuilder> {
  final _layoutKey = GlobalKey();
  Offset _origin = Offset.zero;
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        key: _layoutKey,
        builder: (context, constraints) {
          if (!_scheduled) {
            _scheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduled = false;
              if (!mounted) return;
              final box =
                  _layoutKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              final origin = box.localToGlobal(Offset.zero);
              if (origin != _origin) setState(() => _origin = origin);
            });
          }
          return widget.builder(
              context, constraints, _origin & constraints.biggest);
        },
      );
}

/// Keeps a product/description and its action usable in narrow or scaled flows.
class AdaptiveActionRow extends StatelessWidget {
  const AdaptiveActionRow(
      {super.key, required this.content, required this.action});
  final Widget content;
  final Widget action;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale =
            math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14);
        if (constraints.maxWidth >= 360 * scale + 12) {
          return Row(children: [
            Expanded(child: content),
            const SizedBox(width: 12),
            action,
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ]);
      });
}
