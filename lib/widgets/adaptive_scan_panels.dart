import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'adaptive_window.dart';

enum ScanPanelMode { stacked, sideBySide, horizontalFold }

/// Uses content constraints, not a device classification. Fold bounds are
/// supplied by the platform; no posture is inferred when they are absent.
class ScanPanelGeometry {
  const ScanPanelGeometry(this.mode, this.primary, this.results);
  final ScanPanelMode mode;
  final Rect primary;
  final Rect? results;

  static ScanPanelGeometry resolve({
    required Rect bounds,
    required MediaQueryData media,
    double maxWidth = 1440,
  }) {
    final regions = DisplayFeatureSubScreen.subScreensInBounds(
      bounds,
      DisplayFeatureSubScreen.avoidBounds(media),
    ).where((r) => r.width > 0 && r.height > 0).toList()
      ..sort(
        (a, b) =>
            a.top == b.top ? a.left.compareTo(b.left) : a.top.compareTo(b.top),
      );
    final scale = math.max(1.0, media.textScaler.scale(16) / 16);
    final imageMin = 32 + 280.0 * math.min(scale, 1.5);
    final resultMin = 32 + 360.0 * math.min(scale, 1.5);
    Rect capped(Rect r) {
      final width = math.min(r.width, maxWidth);
      return Rect.fromLTWH(
        r.left + (r.width - width) / 2,
        r.top,
        width,
        r.height,
      );
    }

    if (regions.length == 2) {
      final first = regions.first;
      final last = regions.last;
      if (first.top == last.top &&
          first.width >= imageMin &&
          last.width >= resultMin &&
          math.min(first.height, last.height) >= 180) {
        return ScanPanelGeometry(
          ScanPanelMode.sideBySide,
          capped(first),
          capped(last),
        );
      }
      if (first.left == last.left &&
          math.min(first.height, last.height) >=
              math.max(128.0, media.textScaler.scale(48) + 32)) {
        return ScanPanelGeometry(
          ScanPanelMode.horizontalFold,
          capped(first),
          capped(last),
        );
      }
    }
    // If either side is too small, keep the entire flow in the largest region.
    regions.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    final usable = capped(regions.isEmpty ? bounds : regions.first);
    if (usable.width >= imageMin + resultMin + 24 && usable.height >= 240) {
      final imageWidth = math.max(imageMin, usable.width * 0.42);
      return ScanPanelGeometry(
        ScanPanelMode.sideBySide,
        Rect.fromLTWH(usable.left, usable.top, imageWidth, usable.height),
        Rect.fromLTWH(
          usable.left + imageWidth + 24,
          usable.top,
          usable.width - imageWidth - 24,
          usable.height,
        ),
      );
    }
    return ScanPanelGeometry(ScanPanelMode.stacked, usable, null);
  }
}

/// State belongs above layout branches. Global keys preserve the same panel
/// subtrees (including text fields and nested controls) when reparented.
class AdaptiveScanPanels extends StatefulWidget {
  const AdaptiveScanPanels({
    super.key,
    required this.primary,
    required this.results,
    required this.capture,
    this.backgroundColor = Colors.white,
  });
  final Widget primary;
  final Widget results;
  final ScanCaptureController capture;
  final Color backgroundColor;

  @override
  State<AdaptiveScanPanels> createState() => _AdaptiveScanPanelsState();
}

class _AdaptiveScanPanelsState extends State<AdaptiveScanPanels> {
  final _primaryKey = GlobalKey();
  final _resultsKey = GlobalKey();
  final _mainViewportKey = GlobalKey();
  final _imageViewportKey = GlobalKey();
  final _mainScroll = _RetainedScrollController();
  final _imageScroll = _RetainedScrollController();

  @override
  void initState() {
    super.initState();
    widget.capture._attach(_primaryKey, _resultsKey);
  }

  @override
  void didUpdateWidget(AdaptiveScanPanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capture != widget.capture) {
      oldWidget.capture._detach(_primaryKey);
      widget.capture._attach(_primaryKey, _resultsKey);
    }
  }

  @override
  void dispose() {
    widget.capture._detach(_primaryKey);
    _mainScroll.dispose();
    _imageScroll.dispose();
    super.dispose();
  }

  Widget _panel(GlobalKey key, Widget child) => RepaintBoundary(
        key: key,
        child: ColoredBox(color: widget.backgroundColor, child: child),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: WindowLayoutBuilder(builder: (context, constraints, bounds) {
          final geometry = ScanPanelGeometry.resolve(
            bounds: bounds,
            media: MediaQuery.of(context),
          );
          final primary = _panel(_primaryKey, widget.primary);
          final results = _panel(_resultsKey, widget.results);
          Widget scroll(Widget child, ScrollController controller) =>
              SingleChildScrollView(
                key: controller == _mainScroll
                    ? _mainViewportKey
                    : _imageViewportKey,
                controller: controller,
                primary: false,
                padding: const EdgeInsets.all(16),
                child: child,
              );
          Rect local(Rect rect) => rect.shift(-bounds.topLeft);
          Widget positioned(Rect rect, Widget child) => Positioned.fromRect(
                rect: local(rect),
                child: child,
              );
          return Stack(
            children: geometry.mode == ScanPanelMode.stacked
                ? [
                    positioned(
                        geometry.primary,
                        scroll(
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                primary,
                                const SizedBox(height: 16),
                                results
                              ]),
                          _mainScroll,
                        ))
                  ]
                : [
                    positioned(geometry.primary, scroll(primary, _imageScroll)),
                    positioned(geometry.results!, scroll(results, _mainScroll)),
                  ],
          );
        }),
      );
}

/// Captures full content boundaries inside the scroll views, then composes a
/// vertical export. Viewport clips and hinge gaps never become export crops.
class ScanCaptureController {
  GlobalKey? _primary;
  GlobalKey? _results;

  void _attach(GlobalKey primary, GlobalKey results) {
    _primary = primary;
    _results = results;
  }

  void _detach(GlobalKey primary) {
    if (_primary != primary) return;
    _primary = null;
    _results = null;
  }

  Future<ui.Image?> capture({
    double pixelRatio = 2,
    Color background = Colors.white,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final first =
        _primary?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final second =
        _results?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (first == null || second == null || !first.hasSize || !second.hasSize) {
      return null;
    }
    var needsPaint = false;
    assert(() {
      needsPaint = first.debugNeedsPaint || second.debugNeedsPaint;
      return true;
    }());
    if (needsPaint) return null;
    final width = math.max(first.size.width, second.size.width);
    final height = first.size.height + second.size.height + 16;
    if (width <= 0 || height <= 0) return null;
    // Bound bitmap memory for long menus and high-DPR devices.
    final ratio = math.min(math.min(16384 / width, 16384 / height),
        math.min(pixelRatio, math.sqrt(16000000 / (width * height))));
    final images = <ui.Image>[];
    try {
      images.add(await first.toImage(pixelRatio: ratio));
      images.add(await second.toImage(pixelRatio: ratio));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(background, BlendMode.src);
      canvas.drawImage(images.first, Offset.zero, Paint());
      canvas.drawImage(
        images.last,
        Offset(0, (first.size.height + 16) * ratio),
        Paint(),
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(
          (width * ratio).ceil(),
          (height * ratio).ceil(),
        );
      } finally {
        picture.dispose();
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  }
}

/// Saves the offset when a pane viewport is removed from the tree.
/// PageStorage paths change when content is reparented into one column.
class _RetainedScrollController extends ScrollController {
  _RetainedScrollController() : super(keepScrollOffset: false);
  double _savedOffset = 0;
  @override
  double get initialScrollOffset => _savedOffset;

  @override
  void detach(ScrollPosition position) {
    if (position.hasPixels) _savedOffset = position.pixels;
    super.detach(position);
  }
}
