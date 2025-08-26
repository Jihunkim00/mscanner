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
import 'dart:typed_data'; // ✅ 추가
import 'dart:async';


// 변경 (릴리즈 빌드에서는 로그 안 찍힘)
void _L(String m) {
  assert(() { debugPrint('[MAP-DEBUG] $m'); return true; }());
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
  const AnimatedMapScreen({Key? key, required this.selectedPlaces})
      : super(key: key);
  // 크기 상수 (기존 대비 1/3)
  static const double PHOTO_SIZE  = 0.7;   // 이전 1.5
  static const double PIN_SIZE    = 0.15;   // 이전 0.9
  static const double HIDDEN_SIZE = 0.01;  // 숨김용 그대로


  @override
  State<AnimatedMapScreen> createState() => _AnimatedMapScreenState();
}

class _AnimatedMapScreenState extends State<AnimatedMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _lineManager;
  final List<PointAnnotation> _pointAnnotations = [];
  PolylineAnnotation? _animatedPolyline;
  static const double _Z_SWITCH = 14.0; // 이 줌 미만=핀, 이상=사진
  // 추가: 애니메이션 중에는 카메라 리스너 스킵
  bool _isAnimating = false;

  // 추가: 카메라 변경 디바운스
  Timer? _zoomDebounce;

  // 추가: 같은 상태면 다시 그리지 않기
  bool? _lastShowPhoto;
  int _lastZoomBucket = -999; // 0.5 단위 버킷


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
        BubbleFit fit = BubbleFit.cover,  // 꽉 채우기
        int overscanPx = 2,               // 프레임 가장자리 미세 틈 방지
      }) async {
    final original = img.decodeImage(bytes)!;

    // ⚠️ icon.png 는 반드시 투명 배경이어야 함
    final frameData = await rootBundle.load('assets/images/icon.png');
    final frame = img.decodeImage(frameData.buffer.asUint8List())!;

    final contentW = frame.width  - insetLeft - insetRight  + overscanPx * 2;
    final contentH = frame.height - insetTop  - insetBottom + overscanPx * 2;

    final sx = contentW / original.width;
    final sy = contentH / original.height;
    final scale = (fit == BubbleFit.cover) ? math.max(sx, sy) : math.min(sx, sy);

    final newW = (original.width * scale).round();
    final newH = (original.height * scale).round();

    final dx = insetLeft - overscanPx + ((contentW - newW) / 2).round();
    final dy = insetTop  - overscanPx + ((contentH - newH) / 2).round();

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
    if (_mapboxMap == null) { _L('applyMode: map null'); return; }
    final showPhoto = zoom >= _Z_SWITCH;
    _L('applyMode: zoom=$zoom => showPhoto=$showPhoto '
        '(photo=${_pointAnnotations.length}, pins=${_zoomOutPins.length})');

    if (_pointManager != null && _pointAnnotations.isNotEmpty) {
      for (final ann in _pointAnnotations) {
        ann
     ..iconOpacity = showPhoto ? 1.0 : 0.0
     ..iconSize    = showPhoto ? AnimatedMapScreen.PHOTO_SIZE
                                : AnimatedMapScreen.HIDDEN_SIZE;
        await _pointManager!.update(ann);
      }
      _L('applyMode: photo markers => ${showPhoto ? "VISIBLE" : "HIDDEN"}');
    } else {
      _L('applyMode: photo manager/list empty');
    }

    if (_zoomOutManager != null && _zoomOutPins.isNotEmpty) {
      for (final ann in _zoomOutPins) {
        ann
      ..iconOpacity = showPhoto ? 0.0 : 1.0
      ..iconSize    = showPhoto ? AnimatedMapScreen.HIDDEN_SIZE
                                : AnimatedMapScreen.PIN_SIZE;
        await _zoomOutManager!.update(ann);
      }
      _L('applyMode: zoomout pins => ${showPhoto ? "HIDDEN" : "VISIBLE"}');
    } else {
      _L('applyMode: zoomout manager/list empty');
    }
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
        filter: ['==', ['get', 'extrude'], true],
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
    _pointManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    _lineManager  = await _mapboxMap!.annotations.createPolylineAnnotationManager();

    // 사진 말풍선 마커 생성 (그대로)
    final cacheManager = DefaultCacheManager();
    for (final place in widget.selectedPlaces) {
      Uint8List raw;
      if (place.imageUrl.startsWith('http')) {
        raw = await (await cacheManager.getSingleFile(place.imageUrl)).readAsBytes();
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
    _L('styleLoaded: apply mode @zoom=$z0');
    await _applyMarkerMode(z0);

    _L('[MAP] 모든 마커 추가 완료');

  }

  Future<void> _ensureZoomOutPins() async {
    if (_mapboxMap == null) { _L('ensurePins: map null'); return; }
    if (_zoomOutManager != null && _zoomOutPins.isNotEmpty) {
      _L('ensurePins: already created (${_zoomOutPins.length})');
      return;
    }

    _L('ensurePins: start, places=${widget.selectedPlaces.length}');
    _zoomOutManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    _L('ensurePins: manager created');

    Uint8List pinBytes;
    try {
      pinBytes = (await rootBundle.load('assets/images/m_zoomout_pin.png')).buffer.asUint8List();
      _L('ensurePins: asset loaded (bytes=${pinBytes.length})');
    } catch (e) {
      _L('ensurePins: asset load FAIL: $e');
      rethrow; // 에셋 경로 문제면 바로 알 수 있게
    }

    for (int i = 0; i < widget.selectedPlaces.length; i++) {
      final p = widget.selectedPlaces[i];
      try {
        final ann = await _zoomOutManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          image: pinBytes,
          iconSize: AnimatedMapScreen.PIN_SIZE,
          iconOpacity: 0.0, // 초기 숨김
        ));
        _zoomOutPins.add(ann);
        if (i < 3) { // 너무 많이 안 찍도록 앞부분만
          _L('ensurePins: +pin[$i] @(${p.lat}, ${p.lng})');
        }
      } catch (e) {
        _L('ensurePins: create pin[$i] FAIL: $e');
      }
    }
    _L('ensurePins: done, pins=${_zoomOutPins.length}');
  }









  Future<void> _startAnimation() async {
        if (_mapboxMap == null || _pointManager == null || _lineManager == null)
          return;

        // ▶ 애니메이션 시작 직전에 첫 마커를 보이도록 세팅
        final firstAnn = _pointAnnotations[0];
        firstAnn
          ..iconOpacity = 0.0 // 보이게
          ..iconSize = AnimatedMapScreen.PHOTO_SIZE * 0.66;
        await _pointManager!.update(firstAnn);


        const int steps = 80; // 더 부드럽게
        const int stepDuration = 50;
        const double zoomIn = 19.0;


        final places = widget.selectedPlaces;
        List<Position> polylineCoords = [];

        // 폴리라인 최초 생성(첫 포인트)
        polylineCoords.add(Position(places.first.lng, places.first.lat));

        _animatedPolyline = await _lineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: polylineCoords),
            lineWidth: 6.0,
            lineOpacity: 0.8,
            lineColor: 0xFF20C1FF,
          ),
        );

        // 지구 전체 → 첫 장소 이동
        await _mapboxMap!.flyTo(
          CameraOptions(center: Point(coordinates: Position(0, 0)), zoom: 4.0),
          MapAnimationOptions(duration: 3000),
        );
        await Future.delayed(const Duration(milliseconds: 600));

        // 첫 장소로 zoomIn
        await _mapboxMap!.flyTo(
          CameraOptions(
              center: Point(coordinates: polylineCoords.first), zoom: zoomIn),
          MapAnimationOptions(duration: 2500),
        );


        // 첫 마커 커지기

        for (final size in [
          AnimatedMapScreen.PHOTO_SIZE * 0.66,
          AnimatedMapScreen.PHOTO_SIZE * 0.85,
          AnimatedMapScreen.PHOTO_SIZE,]) {
          firstAnn
            ..iconOpacity = 1.0
            ..iconSize = size;
          await _pointManager!.update(firstAnn);
          await Future.delayed(const Duration(milliseconds: 150));
        }
        // 최종 고정 크기
        firstAnn.iconSize = AnimatedMapScreen.PHOTO_SIZE;
        await _pointManager!.update(firstAnn);

        // 다음 장소들 이동 및 폴리라인 확장 (부드럽게!)
        for (int i = 1; i < places.length; i++) {
          final prev = places[i - 1];
          final curr = places[i];
          final interpolated = interpolatePositions(
            Position(prev.lng, prev.lat),
            Position(curr.lng, curr.lat),
            steps,
          );

          // ▶ 폴리라인 그리기 전, 전체 경로가 보이도록 줌아웃
          await _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: polylineCoords.first),
              zoom: 8.0, // 미리 정의된 zoomOut 값 사용
              pitch: 0.0, // 2D 뷰로 전환하면 전체가 더 잘 보여요
            ),
            MapAnimationOptions(duration: 1000),
          );
          await _applyMarkerMode(8.0);   // ← 추가


          for (int idx = 0; idx < interpolated.length; idx++) {
            final pos = interpolated[idx];




            polylineCoords.add(pos);

            // 폴리라인 좌표만 업데이트하여 깜빡임 방지
            _animatedPolyline!.geometry =
                LineString(coordinates: List.from(polylineCoords));
            await _lineManager!.update(_animatedPolyline!);

            await Future.delayed(const Duration(milliseconds: stepDuration));
          }

          // ▶ 폴리라인이 모두 그려진 뒤, 다시 현재 지점으로 줌인
          await _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: polylineCoords.last),
              zoom: zoomIn, // 미리 정의된 zoomIn 값 사용
              pitch: 50.0,
              bearing: -20.0,
            ),
            MapAnimationOptions(duration: 1000),
          );
          await _applyMarkerMode(zoomIn); // ← 추가


          final ann = _pointAnnotations[i];

          // ▶ ① 마커를 보이게 세팅
          ann
            ..iconOpacity = 1.0 // 투명 → 불투명
            ..iconSize = AnimatedMapScreen.PHOTO_SIZE * 0.66;
          await _pointManager!.update(ann);

          // ▶ ② (옵션) 크기 애니메이션
          for (final size in [
            AnimatedMapScreen.PHOTO_SIZE * 0.66,
            AnimatedMapScreen.PHOTO_SIZE * 0.85,
            AnimatedMapScreen.PHOTO_SIZE,]) {
            ann.iconSize = size;
            await _pointManager!.update(ann);
            await Future.delayed(const Duration(milliseconds: 150));
          }

          // ▶ ③ 최종 고정 크기
          ann.iconSize = AnimatedMapScreen.PHOTO_SIZE;
          await _pointManager!.update(ann);
          await Future.delayed(const Duration(seconds: 1));
        }
         firstAnn.iconSize = AnimatedMapScreen.PHOTO_SIZE;
         await _pointManager!.update(firstAnn);

         // ▶ 애니메이션 종료 후 살짝 줌아웃 + 핀으로 전환
         await _mapboxMap!.flyTo(
               CameraOptions(zoom: 12.0, pitch: 50.0), // center는 현 위치 유지
               MapAnimationOptions(duration: 800),
             );
         await _applyMarkerMode(8.0);
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
            ? Point(coordinates: Position(
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
                  cameraOptions: CameraOptions(
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
                child: FloatingActionButton.extended(
                  onPressed: _startAnimation,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('애니메이션 시작'),
                ),
              ),
            ],
          ),
        );
   }
  }

