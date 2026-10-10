import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerSpec {
  const BannerSpec(this.width, this.orientation);
  final int width;
  final Orientation orientation;

  @override
  bool operator ==(Object other) =>
      other is BannerSpec &&
      width == other.width &&
      orientation == other.orientation;
  @override
  int get hashCode => Object.hash(width, orientation);
}

/// Small boundary for platform-free resize tests.
abstract class AdaptiveBannerHandle {
  AdSize get size;
  Widget get view;
  Future<void> load();
  void dispose();
}

abstract class AdaptiveBannerFactory {
  Future<AdSize?> sizeFor(BannerSpec spec);
  AdaptiveBannerHandle create(AdSize size, String adUnitId);
}

class GoogleAdaptiveBannerFactory implements AdaptiveBannerFactory {
  const GoogleAdaptiveBannerFactory();

  @override
  Future<AdSize?> sizeFor(BannerSpec spec) =>
      AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
        spec.orientation,
        spec.width,
      );

  @override
  AdaptiveBannerHandle create(AdSize size, String adUnitId) =>
      _GoogleBannerHandle(size, adUnitId);
}

class _GoogleBannerHandle implements AdaptiveBannerHandle {
  _GoogleBannerHandle(this.size, String adUnitId) {
    _ad = BannerAd(
      size: size,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!_loaded.isCompleted) _loaded.complete();
        },
        onAdFailedToLoad: (_, error) {
          if (!_loaded.isCompleted) _loaded.completeError(error);
        },
      ),
    );
  }
  @override
  final AdSize size;
  late final BannerAd _ad;
  final _loaded = Completer<void>();
  bool _disposed = false;

  @override
  Widget get view => AdWidget(ad: _ad);
  @override
  Future<void> load() async {
    // Attach the error listener before the SDK can call back.
    final result = _loaded.future;
    unawaited(
      _ad.load().catchError((Object error) {
        if (!_loaded.isCompleted) _loaded.completeError(error);
      }),
    );
    await result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_loaded.isCompleted) {
      _loaded.completeError(StateError('Banner disposed'));
    }
    unawaited(_ad.dispose());
  }
}

/// The measured width is already inside Home's SafeArea and content padding.
class AdaptiveBanner extends StatefulWidget {
  const AdaptiveBanner({
    super.key,
    required this.enabled,
    required this.adUnitId,
    this.factory = const GoogleAdaptiveBannerFactory(),
    this.debounce = const Duration(milliseconds: 400),
  });
  final bool enabled;
  final String adUnitId;
  final AdaptiveBannerFactory factory;
  final Duration debounce;

  @override
  State<AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<AdaptiveBanner> {
  Timer? _debounce;
  BannerSpec? _spec;
  AdaptiveBannerHandle? _ad;
  bool _ready = false;
  int _generation = 0;
  final _disposedAds = Expando<bool>();

  void _disposeAd(AdaptiveBannerHandle ad) {
    if (_disposedAds[ad] == true) return;
    _disposedAds[ad] = true;
    ad.dispose();
  }

  void _observe(BannerSpec? spec) {
    if (spec == _spec) return;
    _spec = spec;
    final generation = ++_generation; // Invalidates old callbacks immediately.
    _debounce?.cancel();
    final previous = _ad;
    _ad = null;
    _ready = false;
    // Remove its AdWidget before disposing the native view.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeAd(previous));
    }
    if (spec != null) {
      _debounce = Timer(widget.debounce, () => _load(spec, generation));
    }
  }

  bool _isCurrent(int generation) =>
      mounted && widget.enabled && generation == _generation;

  Future<void> _load(BannerSpec spec, int generation) async {
    AdaptiveBannerHandle? candidate;
    try {
      final size = await widget.factory.sizeFor(spec);
      if (!_isCurrent(generation) || size == null) return;
      candidate = widget.factory.create(size, widget.adUnitId);
      _ad = candidate;
      await candidate.load();
      if (!_isCurrent(generation) || _ad != candidate) {
        _disposeAd(candidate);
        return;
      }
      setState(() => _ready = true);
    } catch (error) {
      if (candidate != null) _disposeAd(candidate);
      if (!_isCurrent(generation)) return;
      debugPrint('Adaptive banner load failed: $error');
      setState(() {
        _ad = null;
        _ready = false;
      });
    }
  }

  @override
  void didUpdateWidget(AdaptiveBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.factory != widget.factory ||
        oldWidget.adUnitId != widget.adUnitId) {
      _observe(null);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _debounce?.cancel();
    final ad = _ad;
    if (ad != null) _disposeAd(ad);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.floor();
          _observe(
            widget.enabled && width > 0
                ? BannerSpec(width, MediaQuery.orientationOf(context))
                : null,
          );
          final ad = _ad;
          if (!_ready || ad == null) return const SizedBox.shrink();
          return SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: ad.view,
          );
        },
      );
}
