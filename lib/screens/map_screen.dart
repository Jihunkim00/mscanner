import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';  // rootBundle 사용을 위해 추가
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = LatLng(51.509364, -0.128928);
  bool _locationLoaded = false;
  Set<Marker> _markers = {};
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadMarkersFromFirestore();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('위치 서비스 비활성화');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('위치 권한 거부됨');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('위치 권한 영구 거부');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _locationLoaded = true;
      });
    } catch (e) {
      print('위치 로드 실패: $e');
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('로그인 필요');
      return;
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('user_rating')
          .doc(user.uid)
          .collection('data')
          .get();

      Set<Marker> markers = {};
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data.containsKey('gps') && data['gps'] is GeoPoint) {
          GeoPoint geoPoint = data['gps'];
          markers.add(Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            infoWindow: InfoWindow(
              title: data['restaurantName'] ?? 'No Title',
              snippet: AppLocalizations.of(context)?.shareLocation ?? 'Share location',
              onTap: () => _shareLocation(data),
            ),
          ));
        }
      }

      setState(() => _markers = markers);
    } catch (e) {
      print('Firestore 에러: $e');
    }
  }

  void _shareLocation(Map<String, dynamic> data) {
    GeoPoint geoPoint = data['gps'];
    String url = 'https://maps.google.com/?q=${geoPoint.latitude},${geoPoint.longitude}';
    String message = '${data['restaurantName']}\n\n$url';
    Share.share(message);
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    if (_isDarkMode) {
      String darkMapStyle = await rootBundle.loadString('assets/map_styles/dark_mode.json');
      controller.setMapStyle(darkMapStyle);
    } else {
      controller.setMapStyle(null); // 기본 스타일
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;
    final backgroundColor = _isDarkMode ? CupertinoColors.black : CupertinoColors.white;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: _locationLoaded
          ? GoogleMap(
        initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
        markers: _markers,
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      )
          : Center(child: CupertinoActivityIndicator()),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
