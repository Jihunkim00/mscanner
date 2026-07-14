// lib/screens/animated_map_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart'; // rootBundle 용
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 로드
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // 캐시 매니저
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/place_data.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart' hide Visibility;
import 'dart:async';

// 변경 (릴리즈 빌드에서는 로그 안 찍힘)
void _logMapDebug(String m) {
  assert(() {
    debugPrint('[MAP-DEBUG] $m');
    return true;
  }());
}

List<Position> interpolatePositions(Position start, Position end, int steps) {
  List<Position> points = [];
  for (int i = 1; i <= steps; i++) {
    double t = i / steps;
    double lat = start.lat + (end.lat - start.lat) * t;
    double lng = start.lng + (end.lng - start.lng) * t;
    points.add(Position(lng, lat));
  }
  return points;
}

enum BubbleFit { contain, cover }

class AnimatedMapScreen extends StatefulWidget {
  final List<PlaceData> selectedPlaces;
  const AnimatedMapScreen({super.key, required this.selectedPlaces});
  // 크기 상수 (기존 대비 1/3)
  static const double photoSize = 2.0; // 이전 1.5
  static const double pinSize = 0.15; // 이전 0.9
  static const double hiddenSize = 0.01; // 숨김용 그대로

  @override
  State<AnimatedMapScreen> createState() => _AnimatedMapScreenState();
}

class _AnimatedMapScreenState extends State<AnimatedMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _lineManager;
  final List<PointAnnotation> _pointAnnotations = [];
  PolylineAnnotation? _animatedPolyline;
  static const double _zSwitch = 14.0; // 이 줌 미만=핀, 이상=사진
  // 추가: 애니메이션 중에는 카메라 리스너 스킵
  bool _isAnimating = false;

  // 추가: 카메라 변경 디바운스
  Timer? _zoomDebounce;

  // 추가: 같은 상태면 다시 그리지 않기
  PointAnnotationManager? _zoomOutManager;
  final List<PointAnnotation> _zoomOutPins = [];

  @override
  void initState() {
    super.initState();
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception('Mapbox 액세스 토큰이 정의되지 않았습니다. .env 파일을 확인하세요.');
    }
    MapboxOptions.setAccessToken(token);
  }

  Future<Uint8List> _createBubbleMarker(
    Uint8List bytes, {
    int insetLeft = 12,
    int insetTop = 10,
    int insetRight = 18,
    int insetBottom = 24,
    BubbleFit fit = BubbleFit.cover, // 꽉 채우기
    int overscanPx = 2, // 프레임 가장자리 미세 틈 방지
  }) async {
    final original = img.decodeImage(bytes)!;

    // ⚠️ icon.png 는 반드시 투명 배경이어야 함
    final frameData = await rootBundle.load('assets/images/icon.png');
    final frame = img.decodeImage(frameData.buffer.asUint8List())!;

    final contentW = frame.width - insetLeft - insetRight + overscanPx * 2;
    final contentH = frame.height - insetTop - insetBottom + overscanPx * 2;

    final sx = contentW / original.width;
    final sy = contentH / original.height;
    final scale =
        (fit == BubbleFit.cover) ? math.max(sx, sy) : math.min(sx, sy);

    final newW = (original.width * scale).round();
    final newH = (original.height * scale).round();

    final dx = insetLeft - overscanPx + ((contentW - newW) / 2).round();
    final dy = insetTop - overscanPx + ((contentH - newH) / 2).round();

    final resized = img.copyResize(original, width: newW, height: newH);

    final canvas = img.Image(
      width: frame.width,
      height: frame.height,
      numChannels: 4, // RGBA
    );

// ✅ 완전 투명 배경으로 채우기
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

// ✅ 알파 블렌딩으로 합성
    img.compositeImage(
      canvas,
      resized,
      dstX: dx,
      dstY: dy,
      blend: img.BlendMode.alpha, // bool → BlendMode.alpha
    );

    img.compositeImage(
      canvas,
      frame,
      dstX: 0,
      dstY: 0,
      blend: img.BlendMode.alpha,
    );

    return Uint8List.fromList(img.encodePng(canvas));
  }

  Future<void> _applyMarkerMode(double zoom) async {
    if (_mapboxMap == null) {
      _logMapDebug('applyMode: map null');
      return;
    }
    final showPhoto = zoom >= _zSwitch;
    _logMapDebug('applyMode: zoom=$zoom => showPhoto=$showPhoto '
        '(photo=${_pointAnnotations.length}, pins=${_zoomOutPins.length})');

    if (_pointManager != null && _pointAnnotations.isNotEmpty) {
      for (final ann in _pointAnnotations) {
        ann
          ..iconOpacity = showPhoto ? 1.0 : 0.0
          ..iconSize = showPhoto
              ? AnimatedMapScreen.photoSize
              : AnimatedMapScreen.hiddenSize;
        await _pointManager!.update(ann);
      }
      _logMapDebug(
          'applyMode: photo markers => ${showPhoto ? "VISIBLE" : "HIDDEN"}');
    } else {
      _logMapDebug('applyMode: photo manager/list empty');
    }

    if (_zoomOutManager != null && _zoomOutPins.isNotEmpty) {
      for (final ann in _zoomOutPins) {
        ann
          ..iconOpacity = showPhoto ? 0.0 : 1.0
          ..iconSize = showPhoto
              ? AnimatedMapScreen.hiddenSize
              : AnimatedMapScreen.pinSize;
        await _zoomOutManager!.update(ann);
      }
      _logMapDebug(
          'applyMode: zoomout pins => ${showPhoto ? "HIDDEN" : "VISIBLE"}');
    } else {
      _logMapDebug('applyMode: zoomout manager/list empty');
    }
  }

// _AnimatedMapScreenState 내부에 넣기
  Future<CameraOptions> _cameraForAllSelected({MbxEdgeInsets? padding}) async {
    final places = widget.selectedPlaces;

    // 빈 리스트면 현재 카메라 상태를 CameraOptions로 변환해서 반환
    if (places.isEmpty) {
      final st = await _mapboxMap!.getCameraState(); // CameraState
      return CameraOptions(
        center: st.center,
        zoom: st.zoom,
        pitch: st.pitch,
        bearing: st.bearing,
        padding: st.padding,
      );
    }

    // 좌표 리스트 생성 (Point(coordinates: Position(lng, lat)))
    final coords = <Point>[];
    for (final p in places) {
      coords.add(Point(coordinates: Position(p.lng, p.lat)));
    }

    // MbxEdgeInsets는 이름있는 파라미터 필수(top/left/bottom/right)
    final pad = padding ??
        MbxEdgeInsets(
          top: 80,
          left: 60,
          bottom: 120,
          right: 60,
        );

    // ✅ bounds 대신 coordinates로 fit (버전차 이슈, infiniteBounds 요구 등 회피)
    return await _mapboxMap!.cameraForCoordinatesPadding(
      coords,
      CameraOptions(
        bearing: 0.0,
        pitch: 0.0,
      ),
      pad,
      null,
      null,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('[MAP] onMapCreated');
    _mapboxMap = mapboxMap;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final style = _mapboxMap!.style;

    // ✅ DEM 소스: 이미 있으면 스킵
    final hasDem = await style.styleSourceExists('mapbox-dem');
    if (!hasDem) {
      await style.addSource(RasterDemSource(
        id: 'mapbox-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 512,
        maxzoom: 14,
      ));
      await style.setStyleTerrain(jsonEncode({
        'source': 'mapbox-dem',
        'exaggeration': 1.5,
      }));
    } else {
      debugPrint('[MAP] DEM source already exists → skip addSource/setTerrain');
    }

    // ✅ 3D 빌딩 레이어: 이미 있으면 스킵
    final has3d = await style.styleLayerExists('3d-buildings');
    if (!has3d) {
      await style.addLayer(FillExtrusionLayer(
        id: '3d-buildings',
        sourceId: 'composite',
        sourceLayer: 'building',
        filter: [
          '==',
          ['get', 'extrude'],
          true
        ],
        minZoom: 15.0,
        // 필요 시 아래 라인 사용: fillExtrusionColor: const Color(0xFFAAAAAA).value,
        fillExtrusionColor: 0xffaaaaaa,
        fillExtrusionHeightExpression: ['get', 'height'],
        fillExtrusionBaseExpression: ['get', 'min_height'],
        fillExtrusionOpacity: 0.6,
      ));
    } else {
      debugPrint('[MAP] 3d-buildings already exists → skip addLayer');
    }

    // Annotation 매니저 생성 (그대로)
    _pointManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    _lineManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();

    // 사진 말풍선 마커 생성 (그대로)
    final cacheManager = DefaultCacheManager();
    for (final place in widget.selectedPlaces) {
      Uint8List raw;
      if (place.imageUrl.startsWith('http')) {
        raw = await (await cacheManager.getSingleFile(place.imageUrl))
            .readAsBytes();
      } else {
        final data = await rootBundle.load(place.imageUrl);
        raw = data.buffer.asUint8List();
      }
      final marker = await _createBubbleMarker(raw);
      final ann = await _pointManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(place.lng, place.lat)),
        image: marker,
        iconSize: 0.01,
        iconOpacity: 0.0,
      ));
      _pointAnnotations.add(ann);
    }

// 줌아웃 핀 생성 (이전의 _ensureZoomOutLayer 호출 대신)
    await _ensureZoomOutPins();

// 초기 표시 상태 적용
    final z0 = (await _mapboxMap!.getCameraState()).zoom;
    _logMapDebug('styleLoaded: apply mode @zoom=$z0');
    await _applyMarkerMode(z0);

    _logMapDebug('[MAP] 모든 마커 추가 완료');
  }

  Future<void> _ensureZoomOutPins() async {
    if (_mapboxMap == null) {
      _logMapDebug('ensurePins: map null');
      return;
    }
    if (_zoomOutManager != null && _zoomOutPins.isNotEmpty) {
      _logMapDebug('ensurePins: already created (${_zoomOutPins.length})');
      return;
    }

    _logMapDebug('ensurePins: start, places=${widget.selectedPlaces.length}');
    _zoomOutManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    _logMapDebug('ensurePins: manager created');

    Uint8List pinBytes;
    try {
      pinBytes = (await rootBundle.load('assets/images/m_zoomout_pin.png'))
          .buffer
          .asUint8List();
      _logMapDebug('ensurePins: asset loaded (bytes=${pinBytes.length})');
    } catch (e) {
      _logMapDebug('ensurePins: asset load FAIL: $e');
      rethrow; // 에셋 경로 문제면 바로 알 수 있게
    }

    for (int i = 0; i < widget.selectedPlaces.length; i++) {
      final p = widget.selectedPlaces[i];
      try {
        final ann = await _zoomOutManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          image: pinBytes,
          iconSize: AnimatedMapScreen.pinSize,
          iconOpacity: 0.0, // 초기 숨김
        ));
        _zoomOutPins.add(ann);
        if (i < 3) {
          // 너무 많이 안 찍도록 앞부분만
          _logMapDebug('ensurePins: +pin[$i] @(${p.lat}, ${p.lng})');
        }
      } catch (e) {
        _logMapDebug('ensurePins: create pin[$i] FAIL: $e');
      }
    }
    _logMapDebug('ensurePins: done, pins=${_zoomOutPins.length}');
  }

  Future<void> _startAnimation() async {
    if (_mapboxMap == null || _pointManager == null || _lineManager == null) {
      return;
    }
    if (widget.selectedPlaces.isEmpty) return;

    _isAnimating = true;
    try {
      final places = widget.selectedPlaces;
      final bool isMulti = places.length > 1;

      // ── 속도 헬퍼: 다중 선택이면 1.5배 느리게 ─────────────────────
      final double speed = isMulti ? 1.5 : 1.0;
      int ms(num v) => (v * speed).round();
      Duration dz(int baseMs) => Duration(milliseconds: ms(baseMs));
      MapAnimationOptions anim(int baseMs) =>
          MapAnimationOptions(duration: ms(baseMs));

      final int steps = 100; // 또는 120
      final int stepDelay = isMulti ? 38 : 50; // 50ms → 75ms (다중일 때)
      final double zoomIn = 19.0;

      // 폴리라인 초기화
      final polylineCoords = <Position>[
        Position(places.first.lng, places.first.lat)
      ];
      _animatedPolyline = await _lineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: polylineCoords),
          lineWidth: 6.0,
          lineOpacity: 0.8,
          lineColor: 0xFF20C1FF,
        ),
      );

      // 첫 마커 준비
      final firstAnn = _pointAnnotations[0]
        ..iconOpacity = 0.0
        ..iconSize = AnimatedMapScreen.photoSize * 0.66;
      await _pointManager!.update(firstAnn);

      // 1) 지구 → 2) 첫 장소 줌인 (초기 연출은 원래 속도 유지)
      await _mapboxMap!.flyTo(
        CameraOptions(center: Point(coordinates: Position(0, 0)), zoom: 4.0),
        MapAnimationOptions(duration: 3000),
      );
      await Future.delayed(Duration(milliseconds: 600));

      await _mapboxMap!.flyTo(
        CameraOptions(
            center: Point(coordinates: polylineCoords.first), zoom: zoomIn),
        MapAnimationOptions(duration: 2500),
      );
      await _applyMarkerMode(zoomIn);

      // 첫 사진 아이콘 키우기
      for (final size in [
        AnimatedMapScreen.photoSize * 0.66,
        AnimatedMapScreen.photoSize * 0.85,
        AnimatedMapScreen.photoSize,
      ]) {
        firstAnn
          ..iconOpacity = 1.0
          ..iconSize = size;
        await _pointManager!.update(firstAnn);
        await Future.delayed(dz(150)); // 다중이면 225ms
      }

      // ── 단일 선택: 너무 줌인 방지 후 종료 ─────────────────────────
      if (!isMulti) {
        final endZoom = math.min(zoomIn, 17.0);
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
                coordinates: Position(places.first.lng, places.first.lat)),
            zoom: endZoom,
            pitch: 45.0,
            bearing: -15.0,
          ),
          MapAnimationOptions(duration: 700),
        );
        await _applyMarkerMode(endZoom);
        return;
      }

      // ── 다중 선택: 전체 보기로 "한 번만" 줌아웃 (fit-bounds) ────────
      final camAll = await _cameraForAllSelected();
      await _mapboxMap!.flyTo(camAll, anim(1000)); // 1000 → 1500ms
      await _applyMarkerMode((camAll.zoom ?? 12.0));

      // 3) 트레일: 중간 지점에서는 카메라 이동 없이 라인만 그리기
      for (int i = 1; i < places.length; i++) {
        final prev = places[i - 1];
        final curr = places[i];
        final interpolated = interpolatePositions(
          Position(prev.lng, prev.lat),
          Position(curr.lng, curr.lat),
          steps,
        );

        for (final pos in interpolated) {
          polylineCoords.add(pos);
          _animatedPolyline!.geometry =
              LineString(coordinates: List.from(polylineCoords));
          await _lineManager!.update(_animatedPolyline!);
          await Future.delayed(Duration(milliseconds: stepDelay)); // 50 → 75ms
        }

        // 🔕 중간 지점: 카메라 줌인/줌아웃 생략 (요청사항)
        // 필요하면 중간 지점 아이콘만 천천히 나타내고 싶을 때:
        // final ann = _pointAnnotations[i]
        //   ..iconOpacity = 1.0
        //   ..iconSize = AnimatedMapScreen.photoSize * 0.7;
        // await _pointManager!.update(ann);
        // (주의: camAll 줌에서는 사진 모드가 아닐 수 있음)
      }

      // 4) 마지막 지점으로만 줌인
      final last = places.last;
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(last.lng, last.lat)),
          zoom: zoomIn,
          pitch: 50.0,
          bearing: -20.0,
        ),
        anim(900), // 900 → 1350ms
      );
      await _applyMarkerMode(zoomIn);

      // 마지막 사진 아이콘만 키우기
      final lastAnn = _pointAnnotations.last
        ..iconOpacity = 1.0
        ..iconSize = AnimatedMapScreen.photoSize * 0.66;
      await _pointManager!.update(lastAnn);

      for (final size in [
        AnimatedMapScreen.photoSize * 0.66,
        AnimatedMapScreen.photoSize * 0.85,
        AnimatedMapScreen.photoSize,
      ]) {
        lastAnn.iconSize = size;
        await _pointManager!.update(lastAnn);
        await Future.delayed(dz(150)); // 150 → 225ms
      }

      // 5) 엔딩: 전체 보기로 한 번만 줌아웃
      await _mapboxMap!.flyTo(camAll, anim(700)); // 700 → 1050ms
      await _applyMarkerMode((camAll.zoom ?? 12.0));
    } finally {
      _isAnimating = false;
    }
  }

  Future<void> _onCameraChanged(CameraChangedEventData _) async {
    if (_mapboxMap == null || _isAnimating) return;
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 120), () async {
      final z = (await _mapboxMap!.getCameraState()).zoom;
      await _applyMarkerMode(z); // 내부에서 상태변화 없으면 NO-OP 처리
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.selectedPlaces.isNotEmpty
        ? Point(
            coordinates: Position(
            widget.selectedPlaces.first.lng,
            widget.selectedPlaces.first.lat,
          ))
        : Point(coordinates: Position(0, 0));

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('mapWidget'),
              styleUri: 'mapbox://styles/thjcompany/cmdxyza3o00u601rh78vk915y',
              viewport: CameraViewportState(
                center: initialCenter,
                zoom: 4.0,
                pitch: 50.0,
                bearing: -20.0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded, // ✅ 추가
              onCameraChangeListener: _onCameraChanged,
              onMapIdleListener: (e) async {
                if (_mapboxMap == null || _isAnimating) return;
                final z = (await _mapboxMap!.getCameraState()).zoom;
                await _applyMarkerMode(z);
              },
            ),
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: _startAnimation,
              tooltip: '애니메이션 시작',
              child: const Icon(Icons.play_arrow),
            ),
          ),
        ],
      ),
    );
  }
}
